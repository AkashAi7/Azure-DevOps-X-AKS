#!/usr/bin/env bash
# =============================================================================
# participant-setup.sh
# Fortis Workshop - Participant environment setup (macOS / Linux)
#
# What this script does:
#   1. Validates all required tools are installed
#   2. Logs in to Azure and sets the workshop subscription
#   3. Connects kubectl to the workshop AKS cluster
#   4. Validates namespaces and cluster health
#   5. Clones the workshop repo from Azure Repos
#   6. Installs sample app dependencies and runs tests
#   7. Verifies Azure DevOps project access
#
# Usage:
#   chmod +x scripts/participant-setup.sh
#   ./scripts/participant-setup.sh
#
# Before running, get these values from your workshop facilitator:
#   - Azure subscription ID
#   - Azure DevOps org URL and project name
#   - AKS resource group and cluster name
#   - Azure Repos clone URL
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# CONFIGURATION - Get these values from your workshop facilitator
# Auto-loaded from workshop.env if present (just drop the file in the repo root)
# ---------------------------------------------------------------------------

SUBSCRIPTION_ID=""                                    # <<< Azure subscription ID
AKS_RESOURCE_GROUP="rg-workshop-aks"                  # <<< AKS resource group
AKS_CLUSTER_NAME="aks-workshop-01"                    # <<< AKS cluster name
AZDO_ORG="https://dev.azure.com/<your-org>"           # <<< Azure DevOps org URL
AZDO_PROJECT="workshop-project"                       # <<< Azure DevOps project name
CLONE_URL=""                                          # <<< Azure Repos clone URL (optional)

# --- Auto-load from workshop.env if the file exists ---
for envfile in "workshop.env" "$(dirname "$0")/../workshop.env"; do
    if [[ -f "$envfile" ]]; then
        while IFS='=' read -r key value; do
            # Skip comments and blanks
            [[ "$key" =~ ^\s*# ]] && continue
            [[ -z "$key" ]] && continue
            key=$(echo "$key" | xargs)   # trim
            value=$(echo "$value" | xargs)
            case "$key" in
                AZURE_SUBSCRIPTION_ID) [[ -n "$value" ]] && SUBSCRIPTION_ID="$value" ;;
                AKS_RESOURCE_GROUP)    [[ -n "$value" ]] && AKS_RESOURCE_GROUP="$value" ;;
                AKS_CLUSTER_NAME)      [[ -n "$value" ]] && AKS_CLUSTER_NAME="$value" ;;
                AZDO_ORG)              [[ -n "$value" ]] && AZDO_ORG="$value" ;;
                AZDO_PROJECT)          [[ -n "$value" ]] && AZDO_PROJECT="$value" ;;
                AZDO_CLONE_URL)        [[ -n "$value" ]] && CLONE_URL="$value" ;;
            esac
        done < "$envfile"
        echo -e "\033[1;34m[INFO]\033[0m  Loaded configuration from: $envfile"
        break
    fi
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { echo -e "\n\033[1;34m[INFO]\033[0m  $*"; }
success() { echo -e "\033[1;32m[DONE]\033[0m  $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
fail()    { echo -e "\033[1;31m[FAIL]\033[0m  $*"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# Step 1 - Validate prerequisites
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
echo "  Fortis Workshop - Participant Setup"
echo "============================================"

info "Checking required tools..."

ALL_PRESENT=true

check_tool() {
    local name="$1" cmd="$2"
    if command_exists "$cmd"; then
        local ver
        ver=$("$cmd" --version 2>/dev/null | head -1 || echo "installed")
        echo -e "  \033[1;32m[OK]\033[0m   ${name}: ${ver}"
    else
        echo -e "  \033[1;31m[MISS]\033[0m ${name}: NOT FOUND"
        ALL_PRESENT=false
    fi
}

check_tool "Azure CLI" "az"
check_tool "kubectl"   "kubectl"
check_tool "Docker"    "docker"
check_tool "Node.js"   "node"
check_tool "npm"       "npm"
check_tool "Git"       "git"

if [[ "$ALL_PRESENT" != "true" ]]; then
    echo ""
    fail "Some required tools are missing. Run install-dependencies.sh first:"
    fail "  ./scripts/install-dependencies.sh"
    exit 1
fi

success "All required tools are available."

# ---------------------------------------------------------------------------
# Step 2 - Azure login
# ---------------------------------------------------------------------------
info "Logging in to Azure..."
az login --output none

if [[ -n "$SUBSCRIPTION_ID" ]]; then
    az account set --subscription "$SUBSCRIPTION_ID"
fi

az account show --query "{Name:name, ID:id}" -o table
success "Azure login complete."

# ---------------------------------------------------------------------------
# Step 3 - Connect to AKS cluster
# ---------------------------------------------------------------------------
info "Connecting kubectl to AKS cluster: $AKS_CLUSTER_NAME..."
az aks get-credentials \
    --resource-group "$AKS_RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

success "kubectl connected to AKS."

# ---------------------------------------------------------------------------
# Step 4 - Validate cluster health
# ---------------------------------------------------------------------------
info "Checking cluster nodes..."
kubectl get nodes

info "Checking workshop namespaces..."
NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')
MISSING=()

for ns in dev staging production; do
    if echo "$NAMESPACES" | grep -qw "$ns"; then
        echo -e "  \033[1;32m[OK]\033[0m   Namespace: $ns"
    else
        echo -e "  \033[1;31m[MISS]\033[0m Namespace: $ns"
        MISSING+=("$ns")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    warn "Missing namespaces: ${MISSING[*]}. Contact your workshop admin."
else
    success "All workshop namespaces are present."
fi

# ---------------------------------------------------------------------------
# Step 5 - Azure DevOps CLI authentication
# ---------------------------------------------------------------------------
info "Setting up Azure DevOps CLI..."
if ! az extension show --name azure-devops &>/dev/null; then
    az extension add --name azure-devops --output none
fi

az devops configure --defaults organization="$AZDO_ORG" project="$AZDO_PROJECT"

info "Verifying Azure DevOps project access..."
if az devops project show --project "$AZDO_PROJECT" --query "{name:name,state:state}" -o table 2>/dev/null; then
    success "Azure DevOps project accessible."
else
    warn "Could not access project '$AZDO_PROJECT'. Check your permissions with the facilitator."
fi

# ---------------------------------------------------------------------------
# Step 6 - Clone the workshop repository
# ---------------------------------------------------------------------------
if [[ -z "$CLONE_URL" ]]; then
    CLONE_URL=$(az repos show --repository "Fortis-Workshop" --query remoteUrl -o tsv 2>/dev/null || true)
    if [[ -z "$CLONE_URL" ]]; then
        CLONE_URL=$(az repos show --repository "$AZDO_PROJECT" --query remoteUrl -o tsv 2>/dev/null || true)
    fi
fi

if [[ -n "$CLONE_URL" ]]; then
    info "Cloning workshop repository..."
    TARGET_DIR="Fortis-Workshop"

    if [[ -d "$TARGET_DIR" ]]; then
        warn "Directory '$TARGET_DIR' already exists. Pulling latest changes..."
        pushd "$TARGET_DIR" >/dev/null
        git pull --rebase 2>/dev/null || true
        popd >/dev/null
    else
        git clone "$CLONE_URL" "$TARGET_DIR"
    fi
    success "Repository ready at: $TARGET_DIR"
else
    warn "Could not determine clone URL. Clone manually using the URL from Azure Repos."
fi

# ---------------------------------------------------------------------------
# Step 7 - Install sample app dependencies and run tests
# ---------------------------------------------------------------------------
APP_DIR=""
if [[ -d "Fortis-Workshop/sample-app" ]]; then
    APP_DIR="Fortis-Workshop/sample-app"
elif [[ -d "sample-app" ]]; then
    APP_DIR="sample-app"
fi

if [[ -n "$APP_DIR" ]]; then
    info "Installing sample app dependencies..."
    pushd "$APP_DIR" >/dev/null
    npm install 2>/dev/null

    info "Running sample app tests..."
    if npm test 2>&1; then
        success "All tests passed."
    else
        warn "Some tests failed. Review the output above."
    fi
    popd >/dev/null
else
    warn "sample-app directory not found. Skipping npm install/test."
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
echo "  SETUP COMPLETE"
echo "============================================"
echo ""
echo "  Subscription : $(az account show --query name -o tsv)"
echo "  AKS Cluster  : $AKS_CLUSTER_NAME"
echo "  AzDo Project : $AZDO_PROJECT"
echo ""
echo "  Next steps:"
echo "    1. Open Azure DevOps: $AZDO_ORG/$AZDO_PROJECT"
echo "    2. Assign yourself a work item in Boards"
echo "    3. Proceed to Lab 02: CI Pipeline"
echo ""

success "You are ready for the workshop!"
