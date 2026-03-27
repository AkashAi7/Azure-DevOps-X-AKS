#!/usr/bin/env bash
# =============================================================================
# provision-infra.sh
# Fortis Workshop – Workshop-day setup for teams with an existing AKS cluster
#
# What this script does:
#   1. Logs in to Azure and sets the correct subscription
#   2. Pulls kubeconfig for your existing AKS cluster
#   3. Creates Kubernetes namespaces: dev, staging, production
#   4. Creates the Azure DevOps project (if it doesn't exist)
#   5. Creates variable groups: InventoryAPI-Common and InventoryAPI-Environments
#   6. Seeds Azure Boards  – Epic → Features → User Stories → Tasks + Bugs
#   7. Initialises the default Git repo and pushes workshop source code
#   8. Imports CI and CD pipelines from the pipelines/ folder
#   9. Creates an Artifacts feed: inventory-api-packages
#  10. Creates a Test Plan with two suites and sample test cases
#
# Usage (run from the root of the workshop repo):
#   chmod +x scripts/provision-infra.sh
#   ./scripts/provision-infra.sh
#
# Prerequisites:
#   - Azure CLI 2.55+              (az --version)
#   - Azure DevOps CLI extension   (az extension add --name azure-devops)
#   - kubectl 1.28+                (kubectl version --client)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# CONFIGURATION – fill in every value marked  <<<  before running
# ---------------------------------------------------------------------------

# --- Azure ---
SUBSCRIPTION_ID=""                          # <<< your Azure Subscription ID
AKS_RESOURCE_GROUP="rg-workshop-aks"        # <<< resource group that contains your AKS cluster
AKS_NAME="aks-workshop-01"                  # <<< your AKS cluster name
ACR_NAME="workshopacr01"                    # <<< your ACR name (without .azurecr.io)

# --- Azure DevOps ---
AZDO_ORG="https://dev.azure.com/<your-org>" # <<< your Azure DevOps org URL
AZDO_PROJECT="workshop-project"             # <<< project name to create (or existing)
AZDO_PROJECT_DESC="Fortis Workshop – AKS DevOps project"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { echo -e "\n\033[1;34m[INFO]\033[0m  $*"; }
success() { echo -e "\033[1;32m[DONE]\033[0m  $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Step 0 – Verify tooling
# ---------------------------------------------------------------------------
info "Checking required tools..."
command -v az      >/dev/null 2>&1 || error "Azure CLI not found. Install from https://aka.ms/installazurecliwindows"
command -v kubectl >/dev/null 2>&1 || error "kubectl not found. Install from https://kubernetes.io/docs/tasks/tools/"

# Ensure the Azure DevOps CLI extension is present
if ! az extension show --name azure-devops &>/dev/null; then
  info "Installing Azure DevOps CLI extension..."
  az extension add --name azure-devops --output none
fi

# ---------------------------------------------------------------------------
# Step 1 – Azure login & subscription
# ---------------------------------------------------------------------------
info "Logging in to Azure..."
az login --output none

if [[ -n "$SUBSCRIPTION_ID" ]]; then
  az account set --subscription "$SUBSCRIPTION_ID"
fi

ACTIVE_SUB=$(az account show --query "{Name:name, ID:id}" -o tsv)
success "Using subscription: $ACTIVE_SUB"

# ---------------------------------------------------------------------------
# Step 2 – Connect kubectl to the existing AKS cluster
# ---------------------------------------------------------------------------
info "Fetching credentials for AKS cluster: $AKS_NAME..."
az aks get-credentials \
  --resource-group "$AKS_RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --overwrite-existing
success "kubectl context set."

info "Verifying cluster nodes..."
kubectl get nodes
# Expect: all nodes in Ready state before continuing

# ---------------------------------------------------------------------------
# Step 3 – Kubernetes namespaces
# ---------------------------------------------------------------------------
info "Applying namespace manifests (dev, staging, production)..."
kubectl apply -f k8s/base/namespace.yaml
success "Namespaces applied."

echo ""
kubectl get namespaces | grep -E "NAME|dev|staging|production"

# ---------------------------------------------------------------------------
# Step 4 – Azure DevOps project
# ---------------------------------------------------------------------------
info "Configuring Azure DevOps CLI defaults..."
az devops configure --defaults organization="$AZDO_ORG"

# Check if the project already exists
if az devops project show --project "$AZDO_PROJECT" --output none 2>/dev/null; then
  warn "Azure DevOps project '$AZDO_PROJECT' already exists – skipping creation."
else
  info "Creating Azure DevOps project: $AZDO_PROJECT..."
  az devops project create \
    --name "$AZDO_PROJECT" \
    --description "$AZDO_PROJECT_DESC" \
    --visibility private \
    --process Agile \
    --output none
  success "Azure DevOps project created: $AZDO_PROJECT"
fi

# Set project as default for subsequent az devops commands
az devops configure --defaults project="$AZDO_PROJECT"

# ---------------------------------------------------------------------------
# Step 5 – Variable Groups
# ---------------------------------------------------------------------------
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
SUB_ID=$(az account show --query id -o tsv)

# --- Group 1: InventoryAPI-Common ---
info "Creating variable group: InventoryAPI-Common..."
if az pipelines variable-group create \
    --name "InventoryAPI-Common" \
    --variables \
      ACR_NAME="$ACR_NAME" \
      AKS_RESOURCE_GROUP="$AKS_RESOURCE_GROUP" \
      AKS_CLUSTER_NAME="$AKS_NAME" \
      AZURE_SUBSCRIPTION_ID="$SUB_ID" \
      ACR_LOGIN_SERVER="$ACR_LOGIN_SERVER" \
    --output none 2>/dev/null; then
  success "Variable group 'InventoryAPI-Common' created."
else
  warn "Could not create 'InventoryAPI-Common' (may already exist). Check Azure DevOps Library manually."
fi

# --- Group 2: InventoryAPI-Environments ---
info "Creating variable group: InventoryAPI-Environments..."
if az pipelines variable-group create \
    --name "InventoryAPI-Environments" \
    --variables \
      K8S_REPLICAS_DEV=1 \
      K8S_REPLICAS_STAGING=2 \
      K8S_REPLICAS_PROD=3 \
      LOG_LEVEL_DEV=debug \
      LOG_LEVEL_STAGING=info \
      LOG_LEVEL_PROD=warn \
    --output none 2>/dev/null; then
  success "Variable group 'InventoryAPI-Environments' created."
else
  warn "Could not create 'InventoryAPI-Environments' (may already exist). Check Azure DevOps Library manually."
fi

# ---------------------------------------------------------------------------
# Step 6 – Seed Azure Boards
# ---------------------------------------------------------------------------
info "Seeding Azure Boards (Epic → Features → Stories → Tasks + Bugs)..."

# Helper: create a work item, link to parent, return its ID
new_work_item() {
  local type="$1" title="$2" parent_id="${3:-}" description="${4:-}"
  local extra_args=()
  [[ -n "$description" ]] && extra_args+=(--description "$description")
  local id
  id=$(az boards work-item create \
    --type "$type" --title "$title" \
    "${extra_args[@]}" \
    --output json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
  if [[ -n "$parent_id" && -n "$id" ]]; then
    az boards work-item relation add \
      --id "$id" \
      --relation-type "System.LinkTypes.Hierarchy-Reverse" \
      --target-id "$parent_id" \
      --output none 2>/dev/null || true
  fi
  echo "$id"
}

# Epic
EPIC_ID=$(new_work_item "Epic" "Containerize & Deploy InventoryAPI to AKS" "" \
  "End-to-end DevOps pipeline for the InventoryAPI microservice covering CI, CD, and multi-environment promotion on AKS.")
success "Created Epic #$EPIC_ID"

# Feature 1 – CI Pipeline
F1=$(new_work_item "Feature" "CI Pipeline – Build, Test & Publish" "$EPIC_ID")
S1=$(new_work_item "User Story" "As a developer, I can trigger an automated build on every commit" "$F1")
new_work_item "Task" "Create ci-pipeline.yml in Azure DevOps"               "$S1" >/dev/null
new_work_item "Task" "Add ESLint lint stage"                                 "$S1" >/dev/null
new_work_item "Task" "Add Jest unit-test stage with coverage threshold"      "$S1" >/dev/null
new_work_item "Task" "Build Docker image and push to ACR"                    "$S1" >/dev/null
success "Created Feature 1 (CI Pipeline) and child items."

# Feature 2 – CD Pipeline
F2=$(new_work_item "Feature" "CD Pipeline – Multi-Environment Deployment" "$EPIC_ID")
S2=$(new_work_item "User Story" "As an ops engineer, I can promote a release through dev → staging → production" "$F2")
new_work_item "Task" "Deploy to dev namespace on every successful CI run"    "$S2" >/dev/null
new_work_item "Task" "Add manual approval gate before staging deployment"    "$S2" >/dev/null
new_work_item "Task" "Add production gate with rollback strategy"            "$S2" >/dev/null
new_work_item "Task" "Configure HPA and resource limits per environment"     "$S2" >/dev/null
success "Created Feature 2 (CD Pipeline) and child items."

# Feature 3 – Observability
F3=$(new_work_item "Feature" "Observability – Health, Metrics & Alerts" "$EPIC_ID")
S3=$(new_work_item "User Story" "As an SRE, I can monitor the API via Prometheus metrics and liveness probes" "$F3")
new_work_item "Task" "Verify /health and /ready endpoints respond correctly" "$S3" >/dev/null
new_work_item "Task" "Scrape /metrics with Prometheus"                       "$S3" >/dev/null
new_work_item "Task" "Set up Azure Monitor alert for pod restarts"           "$S3" >/dev/null
success "Created Feature 3 (Observability) and child items."

# Feature 4 – GitHub Copilot Integration
F4=$(new_work_item "Feature" "GitHub Copilot Agentic DevOps" "$EPIC_ID")
S4=$(new_work_item "User Story" "As a developer, I can use GitHub Copilot to generate and explain pipeline YAML" "$F4")
new_work_item "Task" "Use Copilot to generate a Kubernetes deployment manifest" "$S4" >/dev/null
new_work_item "Task" "Use Copilot to explain the HPA configuration"             "$S4" >/dev/null
new_work_item "Task" "Use Copilot to write unit tests for the products route"   "$S4" >/dev/null
success "Created Feature 4 (Copilot) and child items."

# Bugs
B1=$(new_work_item "Bug" "Health endpoint returns hardcoded version string" "$EPIC_ID" \
  "APP_VERSION env var is not injected at deploy time so /health always returns 1.0.0 regardless of the image tag.")
B2=$(new_work_item "Bug" "POST /api/products accepts empty product name" "$EPIC_ID" \
  "Validation is missing on the name field – an empty string is accepted and stored in the in-memory array.")
success "Created 2 sample Bugs (#$B1, #$B2)."

# ---------------------------------------------------------------------------
# Step 7 – Initialise Git repo and push workshop source
# ---------------------------------------------------------------------------
info "Initialising the default Azure DevOps Git repository..."

REPO_URL=$(az repos show --repository "$AZDO_PROJECT" --query remoteUrl -o tsv 2>/dev/null || true)

if [[ -n "$REPO_URL" ]]; then
  # Initialise a local git repo if one doesn't exist yet
  if [[ ! -d ".git" ]]; then
    info "Initialising local git repository..."
    git init -b main
    git add -A
    git commit -m "chore: initial workshop scaffold" --allow-empty
  else
    COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    if [[ "$COMMIT_COUNT" -eq 0 ]]; then
      git add -A
      git commit -m "chore: initial workshop scaffold" --allow-empty
    fi
  fi

  git config credential.helper manager-core 2>/dev/null || true

  if git remote get-url azdo &>/dev/null; then
    git remote set-url azdo "$REPO_URL"
  else
    git remote add azdo "$REPO_URL"
  fi

  if git push azdo HEAD:main --force 2>&1; then
    success "Workshop source pushed to Azure DevOps repo: $REPO_URL"
  else
    warn "Git push failed. Authenticate with 'git credential-manager' or push manually: git push azdo HEAD:main"
  fi
else
  warn "Could not resolve repo URL for '$AZDO_PROJECT' – push to Azure Repos manually."
fi

# ---------------------------------------------------------------------------
# Step 8 – Import pipelines
# ---------------------------------------------------------------------------
info "Importing CI pipeline..."
if az pipelines create \
    --name "InventoryAPI-CI" \
    --yml-path "pipelines/ci-pipeline.yml" \
    --repository "$AZDO_PROJECT" \
    --repository-type tfsgit \
    --branch main \
    --skip-first-run true \
    --output none 2>/dev/null; then
  success "CI pipeline imported."
else
  warn "CI pipeline import failed or already exists."
fi

info "Importing CD pipeline..."
if az pipelines create \
    --name "InventoryAPI-CD" \
    --yml-path "pipelines/cd-pipeline.yml" \
    --repository "$AZDO_PROJECT" \
    --repository-type tfsgit \
    --branch main \
    --skip-first-run true \
    --output none 2>/dev/null; then
  success "CD pipeline imported."
else
  warn "CD pipeline import failed or already exists."
fi

info "Importing multi-env pipeline..."
if az pipelines create \
    --name "InventoryAPI-MultiEnv" \
    --yml-path "pipelines/multi-env-pipeline.yml" \
    --repository "$AZDO_PROJECT" \
    --repository-type tfsgit \
    --branch main \
    --skip-first-run true \
    --output none 2>/dev/null; then
  success "Multi-env pipeline imported."
else
  warn "Multi-env pipeline import failed or already exists."
fi

# ---------------------------------------------------------------------------
# Step 9 – Artifacts feed
# ---------------------------------------------------------------------------
info "Creating Artifacts feed: inventory-api-packages..."
if az artifacts feed show --feed "inventory-api-packages" --output none 2>/dev/null; then
  warn "Artifacts feed 'inventory-api-packages' already exists – skipping."
else
  if az artifacts feed create --name "inventory-api-packages" --output none 2>/dev/null; then
    success "Artifacts feed 'inventory-api-packages' created."
  else
    warn "Could not create Artifacts feed – create 'inventory-api-packages' manually in Azure Artifacts."
  fi
fi

# ---------------------------------------------------------------------------
# Step 10 – Test Plans
# ---------------------------------------------------------------------------
info "Creating Test Plan with sample test cases..."

PLAN_ID=$(az testplan create \
  --name "InventoryAPI – Workshop Test Plan" \
  --output json 2>/dev/null \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || true)

if [[ -n "$PLAN_ID" ]]; then
  success "Test Plan created (ID: $PLAN_ID)"

  ROOT_SUITE_ID=$(az testplan suite list \
    --plan-id "$PLAN_ID" \
    --query "[0].id" -o tsv 2>/dev/null)

  # Suite 1 – API Smoke Tests
  S1_ID=$(az testplan suite create \
    --plan-id "$PLAN_ID" \
    --parent-suite-id "$ROOT_SUITE_ID" \
    --name "API Smoke Tests" \
    --suite-type StaticTestSuite \
    --output json 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

  for tc in \
    "GET /health returns 200 with status=healthy" \
    "GET /ready returns 200 with status=ready" \
    "GET /api/products returns an array" \
    "POST /api/products creates a new product" \
    "GET /api/products/:id returns 404 for unknown id"; do
    TC_ID=$(az boards work-item create --type "Test Case" --title "$tc" \
      --output json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
    az testplan case add --plan-id "$PLAN_ID" --suite-id "$S1_ID" \
      --test-case-id "$TC_ID" --output none 2>/dev/null || true
  done
  success "Suite 'API Smoke Tests' created with 5 test cases."

  # Suite 2 – Pipeline Validation
  S2_ID=$(az testplan suite create \
    --plan-id "$PLAN_ID" \
    --parent-suite-id "$ROOT_SUITE_ID" \
    --name "Pipeline Validation" \
    --suite-type StaticTestSuite \
    --output json 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

  for tc in \
    "CI pipeline completes in under 5 minutes" \
    "Docker image is tagged with the build number" \
    "Image is visible in ACR after successful CI run" \
    "CD deploys to dev namespace after CI succeeds" \
    "Manual approval gate blocks staging deployment"; do
    TC_ID=$(az boards work-item create --type "Test Case" --title "$tc" \
      --output json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
    az testplan case add --plan-id "$PLAN_ID" --suite-id "$S2_ID" \
      --test-case-id "$TC_ID" --output none 2>/dev/null || true
  done
  success "Suite 'Pipeline Validation' created with 5 test cases."

else
  warn "Could not create Test Plan – create 'InventoryAPI Workshop Test Plan' manually in Azure Test Plans."
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  SETUP COMPLETE"
echo "============================================================"
echo "  AKS Cluster      : $AKS_NAME"
echo "  ACR              : $ACR_NAME  ($ACR_LOGIN_SERVER)"
echo "  Namespaces       : dev | staging | production"
echo "  Azure DevOps Org : $AZDO_ORG"
echo "  ADO Project      : $AZDO_PROJECT"
echo "  Variable Groups  : InventoryAPI-Common, InventoryAPI-Environments"
echo "  Boards           : 1 Epic | 4 Features | 4 Stories | 14 Tasks | 2 Bugs"
echo "  Pipelines        : InventoryAPI-CI | InventoryAPI-CD | InventoryAPI-MultiEnv"
echo "  Artifacts Feed   : inventory-api-packages"
echo "  Test Plan        : InventoryAPI Workshop Test Plan (2 suites, 10 cases)"
echo "============================================================"
echo ""
echo "  NEXT STEPS:"
echo "  1. Go to $AZDO_ORG/$AZDO_PROJECT/_library"
echo "     and manually add 'InventoryAPI-Secrets' linked to Key Vault"
echo "     (see pipelines/variable-groups/README-variable-groups.md)"
echo "  2. Create an Azure DevOps service connection to your AKS cluster"
echo "     (Project Settings → Service connections → New → Kubernetes)"
echo "  3. Continue with labs/lab-02-ci-pipeline.md"
echo "============================================================"
