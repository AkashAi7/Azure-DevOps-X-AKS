#!/usr/bin/env bash
# =============================================================================
# participant-quick-setup.sh
# Fortis Workshop — Single-command participant onboarding
#
# Prerequisite: Get workshop.env from your facilitator and place it in the
#               repo root (next to README.md) BEFORE running this script.
#
# Usage:
#   chmod +x scripts/participant-quick-setup.sh
#   ./scripts/participant-quick-setup.sh
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
banner() { echo -e "\n\033[36m$(printf '=%.0s' {1..60})\n  $*\n$(printf '=%.0s' {1..60})\033[0m"; }
step()   { echo -e "\n  \033[1;37m[$1/7] $2\033[0m"; }
ok()     { echo -e "       \033[32m[OK]   $*\033[0m"; }
miss()   { echo -e "       \033[31m[MISS] $*\033[0m"; }
info()   { echo -e "       \033[90m$*\033[0m"; }
warn_()  { echo -e "       \033[33m[WARN] $*\033[0m"; }

# ---------------------------------------------------------------------------
# Load workshop.env
# ---------------------------------------------------------------------------
banner "Fortis Workshop — Participant Setup"

ENV_FILE=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
for candidate in "workshop.env" "$SCRIPT_DIR/../workshop.env"; do
  [[ -f "$candidate" ]] && { ENV_FILE="$candidate"; break; }
done

if [[ -z "$ENV_FILE" ]]; then
  echo ""
  miss "workshop.env not found!"
  echo ""
  echo "  Get workshop.env from your facilitator and place it"
  echo "  in the repo root folder (next to README.md)."
  echo ""
  exit 1
fi

SUBSCRIPTION_ID="" RG_NAME="" AKS_NAME="" AZDO_ORG="" AZDO_PROJECT="" CLONE_URL=""
while IFS='=' read -r key value; do
  [[ "$key" =~ ^\s*# ]] && continue
  [[ -z "$key" ]] && continue
  key=$(echo "$key" | xargs); value=$(echo "$value" | xargs)
  case "$key" in
    AZURE_SUBSCRIPTION_ID) SUBSCRIPTION_ID="$value" ;;
    AKS_RESOURCE_GROUP)    RG_NAME="$value" ;;
    AKS_CLUSTER_NAME)      AKS_NAME="$value" ;;
    AZDO_ORG)              AZDO_ORG="$value" ;;
    AZDO_PROJECT)          AZDO_PROJECT="$value" ;;
    AZDO_CLONE_URL)        CLONE_URL="$value" ;;
  esac
done < "$ENV_FILE"

ok "Loaded config from: $ENV_FILE"
info "Project: $AZDO_ORG / $AZDO_PROJECT"

# ---------------------------------------------------------------------------
# Step 1: Tool check
# ---------------------------------------------------------------------------
step 1 "Checking required tools"

ALL_OK=true
for tool in az:AzureCLI kubectl:kubectl git:git node:NodeJS npm:npm docker:Docker; do
  CMD="${tool%%:*}"
  NAME="${tool##*:}"
  if command -v "$CMD" >/dev/null 2>&1; then
    VER=$($CMD --version 2>&1 | head -1)
    ok "$NAME: $VER"
  else
    miss "$NAME not found"
    ALL_OK=false
  fi
done

if ! $ALL_OK; then
  echo ""
  warn_ "Install missing tools and re-run."
  echo "  Or run: ./scripts/install-dependencies.sh"
  exit 1
fi

if ! az extension show --name azure-devops &>/dev/null; then
  info "Installing Azure DevOps CLI extension..."
  az extension add --name azure-devops --output none
fi

# ---------------------------------------------------------------------------
# Step 2: Azure login
# ---------------------------------------------------------------------------
step 2 "Logging in to Azure"

az login --output none
[[ -n "$SUBSCRIPTION_ID" ]] && az account set --subscription "$SUBSCRIPTION_ID"

SUB_NAME=$(az account show --query name -o tsv)
SUB_ID=$(az account show --query id -o tsv)
ok "Subscription: $SUB_NAME ($SUB_ID)"

# ---------------------------------------------------------------------------
# Step 3: Connect to AKS
# ---------------------------------------------------------------------------
step 3 "Connecting to AKS cluster"

az aks get-credentials --resource-group "$RG_NAME" --name "$AKS_NAME" --overwrite-existing --output none
ok "kubectl connected to: $AKS_NAME"

# ---------------------------------------------------------------------------
# Step 4: Verify cluster
# ---------------------------------------------------------------------------
step 4 "Verifying cluster & namespaces"

NODE_CT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
[[ "$NODE_CT" -gt 0 ]] && ok "Cluster has $NODE_CT node(s)." || miss "Cannot reach cluster."

for ns in dev staging production; do
  kubectl get ns "$ns" --no-headers >/dev/null 2>&1 \
    && ok "Namespace: $ns" || miss "Namespace '$ns' missing"
done

# ---------------------------------------------------------------------------
# Step 5: Verify Azure DevOps access
# ---------------------------------------------------------------------------
step 5 "Verifying Azure DevOps project"

az devops configure --defaults organization="$AZDO_ORG" project="$AZDO_PROJECT" >/dev/null 2>&1

PROJ_STATE=$(az devops project show --project "$AZDO_PROJECT" --query state -o tsv 2>/dev/null || true)
[[ "$PROJ_STATE" == "wellFormed" ]] \
  && ok "Project '$AZDO_PROJECT' accessible." \
  || warn_ "Cannot access project. Check permissions."

# ---------------------------------------------------------------------------
# Step 6: Clone / update repo
# ---------------------------------------------------------------------------
step 6 "Setting up repository"

if [[ -z "$CLONE_URL" ]]; then
  CLONE_URL=$(az repos show --repository "Fortis-Workshop" --query remoteUrl -o tsv 2>/dev/null || true)
  [[ -z "$CLONE_URL" ]] && CLONE_URL=$(az repos show --repository "$AZDO_PROJECT" --query remoteUrl -o tsv 2>/dev/null || true)
fi

if [[ -f "sample-app/package.json" ]]; then
  ok "Already inside workshop repo — pulling latest..."
  git pull --rebase >/dev/null 2>&1 || true
elif [[ -n "$CLONE_URL" ]]; then
  if [[ -d "Fortis-Workshop" ]]; then
    ok "Repo folder exists — pulling latest..."
    pushd Fortis-Workshop >/dev/null; git pull --rebase >/dev/null 2>&1 || true; popd >/dev/null
  else
    info "Cloning from Azure Repos..."
    git clone "$CLONE_URL" Fortis-Workshop >/dev/null 2>&1 \
      && ok "Cloned to ./Fortis-Workshop" \
      || warn_ "Clone failed — try: git clone $CLONE_URL"
  fi
else
  warn_ "Could not determine clone URL."
fi

# ---------------------------------------------------------------------------
# Step 7: Install deps & run tests
# ---------------------------------------------------------------------------
step 7 "Installing dependencies & running tests"

APP_DIR=""
[[ -f "sample-app/package.json" ]] && APP_DIR="sample-app"
[[ -f "Fortis-Workshop/sample-app/package.json" ]] && APP_DIR="Fortis-Workshop/sample-app"

if [[ -n "$APP_DIR" ]]; then
  pushd "$APP_DIR" >/dev/null
  info "Running npm install..."
  npm install --silent >/dev/null 2>&1
  info "Running npm test..."
  npm test >/dev/null 2>&1 && ok "All tests passed." || warn_ "Some tests failed."
  popd >/dev/null
else
  warn_ "sample-app not found."
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
banner "YOU'RE ALL SET!"
echo ""
echo "  Subscription : $SUB_NAME"
echo "  AKS Cluster  : $AKS_NAME"
echo "  AzDO Project : $AZDO_ORG/$AZDO_PROJECT"
echo ""
echo "  Open in browser:"
echo -e "    \033[36m$AZDO_ORG/$AZDO_PROJECT\033[0m"
echo ""
echo "  Quick commands to verify:"
echo "    kubectl get namespaces"
echo "    kubectl get nodes"
echo "    cd sample-app && npm test"
echo ""
echo -e "  \033[32mReady for Lab 01! Open: labs/lab-01-setup.md\033[0m"
echo ""
