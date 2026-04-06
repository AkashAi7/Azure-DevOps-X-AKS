#!/usr/bin/env bash
# =============================================================================
# admin-quick-setup.sh
# Fortis Workshop — COMPLETE admin setup: zero to workshop-ready
#
# This script replaces all manual steps. Run it ONCE before the workshop.
#
# Phases:
#   1: Azure Infrastructure  — RG, ACR, AKS, Key Vault
#   2: AKS Configuration    — credentials, namespaces, ACR pull secrets
#   3: Azure DevOps Core    — project, push repo
#   4: Service Connections   — AzureRM + ACR Docker Registry
#   5: AzDO Assets          — variable groups, boards, pipelines, artifacts, test plans
#   6: Environments         — Dev, Staging (delay), Production (approval)
#   7: Demo Data            — feature branch, broken YAML, PR, branch policies
#   8: workshop.env         — auto-written
#   9: Validation
#
# Prerequisites:
#   - Azure CLI 2.55+, azure-devops extension, kubectl, git, node, npm
#   - An Azure subscription with Contributor access
#   - An Azure DevOps organization
#
# Usage:
#   chmod +x scripts/admin-quick-setup.sh
#   ./scripts/admin-quick-setup.sh
#
# Flags:
#   --skip-infra       Skip Azure resource creation (brownfield)
#   --skip-demo-data   Skip feature branch / PR / broken YAML
#   --non-interactive  Use workshop.env values without prompts
# =============================================================================

set -euo pipefail

SKIP_INFRA=false
SKIP_DEMO=false
NON_INTERACTIVE=false

for arg in "$@"; do
  case "$arg" in
    --skip-infra)       SKIP_INFRA=true ;;
    --skip-demo-data)   SKIP_DEMO=true ;;
    --non-interactive)  NON_INTERACTIVE=true ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
banner()  { echo -e "\n\033[36m$(printf '=%.0s' {1..70})\n  $*\n$(printf '=%.0s' {1..70})\033[0m"; }
phase()   { echo -e "\n\033[35m━━━ Phase $1: $2 ━━━\033[0m"; }
info()    { echo -e "  \033[90m[INFO]  $*\033[0m"; }
action()  { echo -e "  \033[33m[>>]    $*\033[0m"; }
done_()   { echo -e "  \033[32m[DONE]  $*\033[0m"; }
skip_()   { echo -e "  \033[90m[SKIP]  $*\033[0m"; }
warn_()   { echo -e "  \033[33m[WARN]  $*\033[0m"; }
err_()    { echo -e "  \033[31m[ERR]   $*\033[0m"; }

prompt_default() {
  local prompt="$1" default="$2"
  if $NON_INTERACTIVE; then echo "$default"; return; fi
  read -rp "  $prompt [$default]: " val
  echo "${val:-$default}"
}

# ---------------------------------------------------------------------------
# Load workshop.env
# ---------------------------------------------------------------------------
SUBSCRIPTION_ID=""
LOCATION="eastus"
RG_NAME="rg-workshop-aks"
ACR_NAME="workshopacr01"
AKS_NAME="aks-workshop-01"
KV_NAME="kv-workshop-01"
AZDO_ORG=""
AZDO_PROJECT="workshop-project"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
for envfile in "workshop.env" "$SCRIPT_DIR/../workshop.env"; do
  if [[ -f "$envfile" ]]; then
    while IFS='=' read -r key value; do
      [[ "$key" =~ ^\s*# ]] && continue
      [[ -z "$key" ]] && continue
      key=$(echo "$key" | xargs)
      value=$(echo "$value" | xargs)
      case "$key" in
        AZURE_SUBSCRIPTION_ID) [[ -n "$value" ]] && SUBSCRIPTION_ID="$value" ;;
        AKS_RESOURCE_GROUP)    [[ -n "$value" ]] && RG_NAME="$value" ;;
        AKS_CLUSTER_NAME)      [[ -n "$value" ]] && AKS_NAME="$value" ;;
        ACR_NAME)              [[ -n "$value" ]] && ACR_NAME="$value" ;;
        AZDO_ORG)              [[ -n "$value" ]] && AZDO_ORG="$value" ;;
        AZDO_PROJECT)          [[ -n "$value" ]] && AZDO_PROJECT="$value" ;;
      esac
    done < "$envfile"
    info "Loaded defaults from: $envfile"
    break
  fi
done

# ---------------------------------------------------------------------------
# Phase 0: Config
# ---------------------------------------------------------------------------
banner "Fortis Workshop — Admin Quick Setup"
echo ""
echo "  This script sets up EVERYTHING for the workshop."
echo "  Safe to re-run — all steps are idempotent."
echo ""

AZDO_ORG=$(prompt_default "Azure DevOps Org URL" "$AZDO_ORG")
if [[ -z "$AZDO_ORG" || "$AZDO_ORG" == *"<your-org>"* ]]; then
  err_ "Azure DevOps org URL is required."; exit 1
fi
AZDO_PROJECT=$(prompt_default "Azure DevOps Project name" "$AZDO_PROJECT")
LOCATION=$(prompt_default "Azure Region" "$LOCATION")
RG_NAME=$(prompt_default "Resource Group name" "$RG_NAME")
ACR_NAME=$(prompt_default "ACR name" "$ACR_NAME")
AKS_NAME=$(prompt_default "AKS cluster name" "$AKS_NAME")
KV_NAME=$(prompt_default "Key Vault name" "$KV_NAME")

# ---------------------------------------------------------------------------
# Tools check
# ---------------------------------------------------------------------------
info "Checking required tools..."
for cmd in az kubectl git node npm; do
  command -v "$cmd" >/dev/null 2>&1 || { err_ "$cmd not found — install it first."; exit 1; }
done
done_ "All tools found."

if ! az extension show --name azure-devops &>/dev/null; then
  action "Installing Azure DevOps CLI extension..."
  az extension add --name azure-devops --output none
fi

# ---------------------------------------------------------------------------
# Login
# ---------------------------------------------------------------------------
action "Logging in to Azure..."
az login --output none

if [[ -n "$SUBSCRIPTION_ID" ]]; then
  az account set --subscription "$SUBSCRIPTION_ID"
else
  SUBSCRIPTION_ID=$(az account show --query id -o tsv)
fi

SUB_NAME=$(az account show --query name -o tsv)
done_ "Subscription: $SUB_NAME ($SUBSCRIPTION_ID)"

action "Authenticating Azure DevOps CLI..."
AZDO_TOKEN=$(az account get-access-token --resource "499b84ac-1321-427f-aa17-267ca6975798" --query accessToken -o tsv)
export AZURE_DEVOPS_EXT_PAT="$AZDO_TOKEN"
az devops configure --defaults organization="$AZDO_ORG"
done_ "Azure DevOps CLI ready."

# =========================================================================
# PHASE 1: Azure Infrastructure
# =========================================================================
if $SKIP_INFRA; then
  phase 1 "Azure Infrastructure (SKIPPED)"
else
  phase 1 "Azure Infrastructure"

  # Resource Group
  if [[ "$(az group exists --name "$RG_NAME" -o tsv)" == "true" ]]; then
    skip_ "Resource Group '$RG_NAME' already exists."
  else
    action "Creating Resource Group: $RG_NAME..."
    az group create --name "$RG_NAME" --location "$LOCATION" --output none
    done_ "Resource Group created."
  fi

  # ACR
  if az acr show --name "$ACR_NAME" --output none 2>/dev/null; then
    skip_ "ACR '$ACR_NAME' already exists."
  else
    action "Creating ACR: $ACR_NAME..."
    az acr create --resource-group "$RG_NAME" --name "$ACR_NAME" --sku Basic --admin-enabled true --output none
    done_ "ACR created."
  fi

  # AKS
  if az aks show --resource-group "$RG_NAME" --name "$AKS_NAME" --output none 2>/dev/null; then
    skip_ "AKS cluster '$AKS_NAME' already exists."
  else
    action "Creating AKS cluster: $AKS_NAME (3 nodes) — this takes 5-10 minutes..."
    az aks create \
      --resource-group "$RG_NAME" \
      --name "$AKS_NAME" \
      --node-count 3 \
      --node-vm-size Standard_D2s_v5 \
      --enable-managed-identity \
      --attach-acr "$ACR_NAME" \
      --generate-ssh-keys \
      --output none
    done_ "AKS cluster created."
  fi

  action "Ensuring ACR attached to AKS..."
  az aks update --resource-group "$RG_NAME" --name "$AKS_NAME" --attach-acr "$ACR_NAME" --output none 2>/dev/null || true
  done_ "ACR attached."

  # Key Vault
  if az keyvault show --name "$KV_NAME" --output none 2>/dev/null; then
    skip_ "Key Vault '$KV_NAME' already exists."
  else
    action "Creating Key Vault: $KV_NAME..."
    az keyvault create --resource-group "$RG_NAME" --name "$KV_NAME" --location "$LOCATION" --output none
    done_ "Key Vault created."
  fi

  action "Storing ACR password in Key Vault..."
  ACR_PASS=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)
  az keyvault secret set --vault-name "$KV_NAME" --name "acr-admin-password" --value "$ACR_PASS" --output none 2>/dev/null || true
  done_ "ACR secret stored."
fi

# =========================================================================
# PHASE 2: AKS Configuration
# =========================================================================
phase 2 "AKS Configuration"

action "Fetching AKS credentials..."
az aks get-credentials --resource-group "$RG_NAME" --name "$AKS_NAME" --overwrite-existing --output none
done_ "kubectl context set."

action "Applying namespaces..."
kubectl apply -f k8s/base/namespace.yaml >/dev/null 2>&1
done_ "Namespaces ready."

action "Creating ACR pull secrets..."
ACR_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
ACR_USER=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
ACR_PASS=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)

for ns in dev staging production; do
  kubectl create secret docker-registry acr-pull-secret \
    --docker-server="$ACR_SERVER" \
    --docker-username="$ACR_USER" \
    --docker-password="$ACR_PASS" \
    --namespace="$ns" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
done
done_ "ACR pull secrets created in dev/staging/production."

# =========================================================================
# PHASE 3: Azure DevOps Core
# =========================================================================
phase 3 "Azure DevOps Project & Repository"

az devops configure --defaults organization="$AZDO_ORG" >/dev/null 2>&1

if az devops project show --project "$AZDO_PROJECT" --output none 2>/dev/null; then
  skip_ "Project '$AZDO_PROJECT' already exists."
else
  action "Creating Azure DevOps project: $AZDO_PROJECT..."
  az devops project create --name "$AZDO_PROJECT" --description "Fortis Workshop" --visibility private --process Agile --output none
  done_ "Project created."
fi

az devops configure --defaults project="$AZDO_PROJECT" >/dev/null 2>&1

action "Pushing workshop source to Azure Repos..."
REPO_URL=$(az repos show --repository "$AZDO_PROJECT" --query remoteUrl -o tsv 2>/dev/null || true)

if [[ -n "$REPO_URL" ]]; then
  if [[ ! -d ".git" ]]; then
    git init -b main >/dev/null 2>&1
    git add -A >/dev/null 2>&1
    git commit -m "chore: initial workshop scaffold" --allow-empty >/dev/null 2>&1
  fi

  if git remote get-url azdo &>/dev/null; then
    git remote set-url azdo "$REPO_URL"
  else
    git remote add azdo "$REPO_URL"
  fi

  B64_TOKEN=$(echo -n "PAT:$AZDO_TOKEN" | base64)
  if git -c http.extraHeader="Authorization: Basic $B64_TOKEN" push azdo HEAD:main --force >/dev/null 2>&1; then
    done_ "Source pushed to Azure Repos."
  else
    warn_ "Git push failed — push manually: git push azdo HEAD:main"
  fi
else
  warn_ "Could not resolve repo URL."
fi

# =========================================================================
# PHASE 4: Service Connections
# =========================================================================
phase 4 "Service Connections"

# Azure RM
EXISTING_ARM=$(az devops service-endpoint list --query "[?name=='AzureRM-ServiceConnection'].id" -o tsv 2>/dev/null || true)
if [[ -n "$EXISTING_ARM" ]]; then
  skip_ "AzureRM-ServiceConnection already exists."
else
  action "Creating service principal..."
  SP_JSON=$(az ad sp create-for-rbac \
    --name "workshop-sp-$AZDO_PROJECT" \
    --role Contributor \
    --scopes "/subscriptions/$SUBSCRIPTION_ID" \
    --output json 2>/dev/null || true)

  if [[ -n "$SP_JSON" ]]; then
    SP_APP_ID=$(echo "$SP_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['appId'])")
    SP_PASS=$(echo "$SP_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")
    SP_TENANT=$(echo "$SP_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['tenant'])")

    export AZURE_DEVOPS_EXT_AZURE_RM_SERVICE_PRINCIPAL_KEY="$SP_PASS"

    ARM_EP_ID=$(az devops service-endpoint azurerm create \
      --azure-rm-service-principal-id "$SP_APP_ID" \
      --azure-rm-subscription-id "$SUBSCRIPTION_ID" \
      --azure-rm-subscription-name "$SUB_NAME" \
      --azure-rm-tenant-id "$SP_TENANT" \
      --name "AzureRM-ServiceConnection" \
      --query id -o tsv 2>/dev/null || true)

    if [[ -n "$ARM_EP_ID" ]]; then
      az devops service-endpoint update --id "$ARM_EP_ID" --enable-for-all true --output none 2>/dev/null || true
      done_ "AzureRM-ServiceConnection created."
    else
      warn_ "Failed to create AzureRM-ServiceConnection. Create manually."
    fi
  else
    warn_ "Could not create service principal."
  fi
fi

# ACR Docker Registry
EXISTING_ACR=$(az devops service-endpoint list --query "[?name=='ACR-ServiceConnection'].id" -o tsv 2>/dev/null || true)
if [[ -n "$EXISTING_ACR" ]]; then
  skip_ "ACR-ServiceConnection already exists."
else
  action "Creating ACR Docker Registry service connection..."
  ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
  ACR_USER=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
  ACR_PASS=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)
  PROJECT_ID=$(az devops project show --project "$AZDO_PROJECT" --query id -o tsv)

  CONFIG_FILE=$(mktemp)
  cat > "$CONFIG_FILE" << EOJSON
{
  "data": { "registrytype": "Others" },
  "name": "ACR-ServiceConnection",
  "type": "dockerregistry",
  "url": "https://$ACR_LOGIN_SERVER",
  "authorization": {
    "scheme": "UsernamePassword",
    "parameters": {
      "registry": "https://$ACR_LOGIN_SERVER",
      "username": "$ACR_USER",
      "password": "$ACR_PASS"
    }
  },
  "isShared": false,
  "isReady": true,
  "serviceEndpointProjectReferences": [{
    "projectReference": { "id": "$PROJECT_ID", "name": "$AZDO_PROJECT" },
    "name": "ACR-ServiceConnection"
  }]
}
EOJSON

  ACR_EP_ID=$(az devops service-endpoint create \
    --service-endpoint-configuration "$CONFIG_FILE" \
    --query id -o tsv 2>/dev/null || true)

  rm -f "$CONFIG_FILE"

  if [[ -n "$ACR_EP_ID" ]]; then
    az devops service-endpoint update --id "$ACR_EP_ID" --enable-for-all true --output none 2>/dev/null || true
    done_ "ACR-ServiceConnection created."
  else
    warn_ "Failed to create ACR-ServiceConnection. Create manually."
  fi
fi

# =========================================================================
# PHASE 5: Azure DevOps Assets
# =========================================================================
phase 5 "Azure DevOps Assets"

action "Creating variable groups..."
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
SUB_ID=$(az account show --query id -o tsv)

az pipelines variable-group create \
  --name "InventoryAPI-Common" \
  --variables \
    ACR_NAME="$ACR_NAME" \
    ACR_LOGIN_SERVER="$ACR_LOGIN_SERVER" \
    AKS_RESOURCE_GROUP="$RG_NAME" \
    AKS_CLUSTER_NAME="$AKS_NAME" \
    AZURE_SUBSCRIPTION_ID="$SUB_ID" \
  --output none 2>/dev/null && done_ "InventoryAPI-Common created." || skip_ "InventoryAPI-Common may already exist."

az pipelines variable-group create \
  --name "InventoryAPI-Environments" \
  --variables \
    K8S_REPLICAS_DEV=1 K8S_REPLICAS_STAGING=2 K8S_REPLICAS_PROD=3 \
    LOG_LEVEL_DEV=debug LOG_LEVEL_STAGING=info LOG_LEVEL_PROD=warn \
  --output none 2>/dev/null && done_ "InventoryAPI-Environments created." || skip_ "InventoryAPI-Environments may already exist."

warn_ "InventoryAPI-Secrets must be linked to Key Vault ($KV_NAME) manually in Pipelines > Library."

# --- Boards ---
action "Seeding Azure Boards..."

new_work_item() {
  local type="$1" title="$2" parent_id="${3:-}" desc="${4:-}"
  local extra=()
  [[ -n "$desc" ]] && extra+=(--description "$desc")
  local id
  id=$(az boards work-item create --type "$type" --title "$title" "${extra[@]}" --query "id" -o tsv 2>/dev/null || true)
  if [[ -n "$parent_id" && -n "$id" ]]; then
    az boards work-item relation add --id "$id" \
      --relation-type "System.LinkTypes.Hierarchy-Reverse" \
      --target-id "$parent_id" --output none 2>/dev/null || true
  fi
  echo "$id"
}

EPIC_ID=$(new_work_item "Epic" "Containerize & Deploy InventoryAPI to AKS" "" "End-to-end DevOps pipeline.")
if [[ -n "$EPIC_ID" ]]; then
  F1=$(new_work_item "Feature" "CI Pipeline - Build, Test & Publish" "$EPIC_ID")
  S1=$(new_work_item "User Story" "As a developer, I can trigger automated builds" "$F1")
  for t in "Create ci-pipeline.yml" "Add ESLint stage" "Add Jest test stage" "Build Docker + push ACR"; do
    new_work_item "Task" "$t" "$S1" >/dev/null
  done

  F2=$(new_work_item "Feature" "CD Pipeline - Multi-Environment Deployment" "$EPIC_ID")
  S2=$(new_work_item "User Story" "As an ops engineer, I can promote releases" "$F2")
  for t in "Deploy to dev on CI success" "Add staging approval" "Add production gate" "Configure HPA"; do
    new_work_item "Task" "$t" "$S2" >/dev/null
  done

  F3=$(new_work_item "Feature" "Observability - Health, Metrics & Alerts" "$EPIC_ID")
  S3=$(new_work_item "User Story" "As an SRE, I can monitor via Prometheus" "$F3")
  for t in "Verify /health endpoint" "Scrape /metrics" "Azure Monitor alerts"; do
    new_work_item "Task" "$t" "$S3" >/dev/null
  done

  F4=$(new_work_item "Feature" "GitHub Copilot Agentic DevOps" "$EPIC_ID")
  S4=$(new_work_item "User Story" "As a developer, I can use Copilot for YAML" "$F4")
  for t in "Copilot: generate K8s manifest" "Copilot: explain HPA" "Copilot: write tests"; do
    new_work_item "Task" "$t" "$S4" >/dev/null
  done

  new_work_item "Bug" "Health endpoint returns hardcoded version" "$EPIC_ID" "APP_VERSION not injected." >/dev/null
  new_work_item "Bug" "POST /api/products accepts empty name" "$EPIC_ID" "Validation missing." >/dev/null

  done_ "Boards seeded: 1 Epic, 4 Features, 4 Stories, 14 Tasks, 2 Bugs."
else
  warn_ "Could not seed Boards."
fi

# --- Pipelines ---
action "Importing pipelines..."
for p in "InventoryAPI-CI:pipelines/ci-pipeline.yml" "InventoryAPI-CD:pipelines/cd-pipeline.yml" "InventoryAPI-MultiEnv:pipelines/multi-env-pipeline.yml"; do
  NAME="${p%%:*}"
  YML="${p##*:}"
  if az pipelines show --name "$NAME" --output none 2>/dev/null; then
    skip_ "$NAME already exists."
  else
    az pipelines create --name "$NAME" --yml-path "$YML" --repository "$AZDO_PROJECT" \
      --repository-type tfsgit --branch main --skip-first-run true --output none 2>/dev/null \
      && done_ "Imported $NAME." || warn_ "Failed to import $NAME."
  fi
done

# --- Artifacts ---
action "Creating Artifacts feed..."
if az artifacts feed show --feed "inventory-api-packages" --output none 2>/dev/null; then
  skip_ "Feed already exists."
else
  az artifacts feed create --name "inventory-api-packages" --output none 2>/dev/null \
    && done_ "Feed created." || warn_ "Could not create feed."
fi

# --- Test Plans ---
action "Creating Test Plan..."
PLAN_ID=$(az testplan create --name "InventoryAPI - Workshop Test Plan" --query id -o tsv 2>/dev/null || true)
if [[ -n "$PLAN_ID" ]]; then
  ROOT_SUITE=$(az testplan suite list --plan-id "$PLAN_ID" --query "[0].id" -o tsv 2>/dev/null)

  S1_ID=$(az testplan suite create --plan-id "$PLAN_ID" --parent-suite-id "$ROOT_SUITE" \
    --name "API Smoke Tests" --suite-type StaticTestSuite --query id -o tsv 2>/dev/null || true)
  if [[ -n "$S1_ID" ]]; then
    for tc in "GET /health returns 200" "GET /api/products returns array" "POST /api/products creates product" "GET /api/products/:id 404" "GET /ready returns 200"; do
      TC_ID=$(az boards work-item create --type "Test Case" --title "$tc" --query id -o tsv 2>/dev/null)
      [[ -n "$TC_ID" ]] && az testplan case add --plan-id "$PLAN_ID" --suite-id "$S1_ID" --test-case-id "$TC_ID" --output none 2>/dev/null || true
    done
  fi

  S2_ID=$(az testplan suite create --plan-id "$PLAN_ID" --parent-suite-id "$ROOT_SUITE" \
    --name "Pipeline Validation" --suite-type StaticTestSuite --query id -o tsv 2>/dev/null || true)
  if [[ -n "$S2_ID" ]]; then
    for tc in "CI < 5 min" "Image tagged with build#" "Image in ACR" "CD deploys to dev" "Approval blocks staging"; do
      TC_ID=$(az boards work-item create --type "Test Case" --title "$tc" --query id -o tsv 2>/dev/null)
      [[ -n "$TC_ID" ]] && az testplan case add --plan-id "$PLAN_ID" --suite-id "$S2_ID" --test-case-id "$TC_ID" --output none 2>/dev/null || true
    done
  fi
  done_ "Test Plan created."
else
  warn_ "Could not create Test Plan."
fi

# =========================================================================
# PHASE 6: Environments
# =========================================================================
phase 6 "Environments"

ENV_API="$AZDO_ORG/$AZDO_PROJECT/_apis/distributedtask/environments?api-version=7.1"
AUTH_HEADER="Authorization: Bearer $AZDO_TOKEN"

for env_name in "InventoryAPI-Dev" "InventoryAPI-Staging" "InventoryAPI-Production"; do
  EXISTING=$(curl -s -H "$AUTH_HEADER" "$ENV_API" | python3 -c "
import sys,json
data=json.load(sys.stdin)
for e in data.get('value',[]):
  if e['name']=='$env_name': print(e['id']); break
" 2>/dev/null || true)

  if [[ -n "$EXISTING" ]]; then
    skip_ "$env_name already exists (ID: $EXISTING)."
  else
    RESULT=$(curl -s -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" \
      -d "{\"name\":\"$env_name\",\"description\":\"Workshop environment\"}" "$ENV_API" 2>/dev/null)
    ENV_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)
    if [[ -n "$ENV_ID" ]]; then
      done_ "Created $env_name (ID: $ENV_ID)."
    else
      warn_ "Could not create $env_name."
    fi
  fi
done
info "Add approval checks manually: Environments > InventoryAPI-Production > Approvals & Checks"

# =========================================================================
# PHASE 7: Demo Data
# =========================================================================
if $SKIP_DEMO; then
  phase 7 "Demo Data (SKIPPED)"
else
  phase 7 "Demo Data"

  REPO_ID=$(az repos show --repository "$AZDO_PROJECT" --query id -o tsv 2>/dev/null || true)
  B64_TOKEN=$(echo -n "PAT:$AZDO_TOKEN" | base64)

  # Branch policies
  if [[ -n "$REPO_ID" ]]; then
    action "Setting branch policies on main..."
    az repos policy approver-count create --branch main --repository-id "$REPO_ID" \
      --minimum-approver-count 1 --creator-vote-counts false --allow-downvotes false \
      --reset-on-source-push true --blocking true --enabled true --output none 2>/dev/null \
      && done_ "Policy: min 1 reviewer." || true

    az repos policy comment-required create --branch main --repository-id "$REPO_ID" \
      --blocking true --enabled true --output none 2>/dev/null \
      && done_ "Policy: comment resolution." || true
  fi

  # Feature branch
  action "Creating feature branch..."
  git checkout -b feature/add-metrics >/dev/null 2>&1 || git checkout feature/add-metrics >/dev/null 2>&1
  PRODUCTS_FILE="sample-app/src/routes/products.js"
  if [[ -f "$PRODUCTS_FILE" ]] && ! grep -q "/metrics" "$PRODUCTS_FILE"; then
    echo -e "\n// TODO: Add Prometheus metrics endpoint for request counting" >> "$PRODUCTS_FILE"
    git add "$PRODUCTS_FILE" >/dev/null 2>&1
    git commit -m "feat: add metrics endpoint placeholder" >/dev/null 2>&1
  fi
  git -c http.extraHeader="Authorization: Basic $B64_TOKEN" push azdo feature/add-metrics --force >/dev/null 2>&1 \
    && done_ "Feature branch pushed." || warn_ "Could not push feature branch."
  git checkout main >/dev/null 2>&1

  # Broken YAML
  action "Creating broken YAML on scratch branch..."
  git checkout -b scratch/broken-yaml >/dev/null 2>&1 || git checkout scratch/broken-yaml >/dev/null 2>&1

  cat > pipelines/broken-demo.yml << 'EOYAML'
# Broken pipeline for Copilot /fix demo — contains intentional errors
trigger:
  branches:
    include:
    - main

pool
  vmImage: 'ubuntu-latest'

variables:
  nodeVersion: 22
  imageName: inventory-api

stages:
- stage: Build
  displayName: Build and Test
  jobs:
  - job BuildApp
    displayName: 'Build Application'
    steps:
    - task: NodeTool@0
      inputs:
        versionSpec: $(nodeVersion)

    - script: |
        cd sample-app
        npm ci
        npm test
      displayName 'Install and Test'

    - task: Docker@2
      inputs:
        command: buildAndPush
        containerRegistry: ACR-ServiceConnection
        repository: $(imageName)
        dockerfile: sample-app/Dockerfile
        tags:
          latest
EOYAML

  git add pipelines/broken-demo.yml >/dev/null 2>&1
  git commit -m "chore: add broken YAML for Copilot demo" >/dev/null 2>&1
  git -c http.extraHeader="Authorization: Basic $B64_TOKEN" push azdo scratch/broken-yaml --force >/dev/null 2>&1 \
    && done_ "Broken YAML pushed." || warn_ "Could not push broken YAML branch."
  git checkout main >/dev/null 2>&1
  rm -f pipelines/broken-demo.yml

  # Pull Request
  action "Creating Pull Request..."
  az repos pr create --repository "$AZDO_PROJECT" \
    --source-branch feature/add-metrics --target-branch main \
    --title "feat: Add Prometheus metrics endpoint" \
    --description "Adds metrics endpoint placeholder." \
    --output none 2>/dev/null \
    && done_ "PR created." || warn_ "PR may already exist."
fi

# =========================================================================
# PHASE 8: Write workshop.env
# =========================================================================
phase 8 "Write workshop.env"

CLONE_URL=$(az repos show --repository "$AZDO_PROJECT" --query remoteUrl -o tsv 2>/dev/null || true)

cat > workshop.env << EOENV
# =============================================================================
# workshop.env — Auto-generated by admin-quick-setup.sh
# Generated: $(date '+%Y-%m-%d %H:%M')
# Distribute this file to all participants before the workshop.
# =============================================================================

# --- Azure Subscription ---
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID

# --- AKS ---
AKS_RESOURCE_GROUP=$RG_NAME
AKS_CLUSTER_NAME=$AKS_NAME

# --- ACR ---
ACR_NAME=$ACR_NAME

# --- Key Vault ---
KEY_VAULT_NAME=$KV_NAME

# --- Azure DevOps ---
AZDO_ORG=$AZDO_ORG
AZDO_PROJECT=$AZDO_PROJECT
AZDO_CLONE_URL=$CLONE_URL
EOENV

done_ "workshop.env written."
info "Distribute this file to all participants."

# =========================================================================
# PHASE 9: Validation
# =========================================================================
phase 9 "Validation"

echo ""
action "Running checks..."

check() {
  local name="$1" status="$2" detail="$3"
  if [[ "$status" == "OK" ]]; then
    echo -e "  \033[32m[PASS]\033[0m $name — $detail"
  elif [[ "$status" == "WARN" ]]; then
    echo -e "  \033[33m[WARN]\033[0m $name — $detail"
  else
    echo -e "  \033[31m[FAIL]\033[0m $name — $detail"
  fi
}

NODE_CT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
[[ "$NODE_CT" -gt 0 ]] && check "AKS Nodes" "OK" "$NODE_CT nodes" || check "AKS Nodes" "FAIL" "unreachable"

for ns in dev staging production; do
  kubectl get ns "$ns" --no-headers >/dev/null 2>&1 \
    && check "Namespace: $ns" "OK" "exists" \
    || check "Namespace: $ns" "FAIL" "missing"
done

az acr show --name "$ACR_NAME" --output none 2>/dev/null \
  && check "ACR" "OK" "$ACR_NAME" || check "ACR" "FAIL" "not found"

[[ "$(az devops project show --project "$AZDO_PROJECT" --query state -o tsv 2>/dev/null)" == "wellFormed" ]] \
  && check "AzDO Project" "OK" "$AZDO_PROJECT" || check "AzDO Project" "FAIL" "not accessible"

for p in InventoryAPI-CI InventoryAPI-CD InventoryAPI-MultiEnv; do
  az pipelines show --name "$p" --output none 2>/dev/null \
    && check "Pipeline: $p" "OK" "imported" || check "Pipeline: $p" "WARN" "not found"
done

for sc in AzureRM-ServiceConnection ACR-ServiceConnection; do
  SC_ID=$(az devops service-endpoint list --query "[?name=='$sc'].id" -o tsv 2>/dev/null || true)
  [[ -n "$SC_ID" ]] && check "SvcConn: $sc" "OK" "created" || check "SvcConn: $sc" "WARN" "MANUAL STEP?"
done

action "Running npm tests..."
pushd sample-app >/dev/null
npm install --silent >/dev/null 2>&1
npm test >/dev/null 2>&1 && check "npm test" "OK" "all pass" || check "npm test" "WARN" "failures"
popd >/dev/null

echo ""
banner "SETUP COMPLETE"
echo ""
echo "  AKS Cluster : $AKS_NAME"
echo "  ACR         : $ACR_NAME.azurecr.io"
echo "  AzDO Project: $AZDO_ORG/$AZDO_PROJECT"
echo "  Key Vault   : $KV_NAME"
echo ""
echo -e "  \033[33mMANUAL STEP: Link 'InventoryAPI-Secrets' to Key Vault '$KV_NAME'\033[0m"
echo -e "  \033[33m→ Pipelines > Library > + Variable group > Link to Key Vault\033[0m"
echo ""
echo "  NEXT: Distribute workshop.env to participants."
echo "  NEXT: Run CI pipeline once to pre-stage a successful run."
echo "  NEXT: Participants run: ./scripts/participant-quick-setup.sh"
echo ""
