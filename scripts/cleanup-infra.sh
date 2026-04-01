#!/usr/bin/env bash
# =============================================================================
# cleanup-infra.sh
# Fortis Workshop - Teardown for workshop-created resources
#
# What this script does:
#   1. Logs in to Azure and sets the correct subscription
#   2. Pulls kubeconfig for your existing AKS cluster
#   3. Deletes Kubernetes namespaces: dev, staging, production
#   4. Deletes the workshop Azure DevOps project when enabled
#
# What this script does NOT delete:
#   - The AKS cluster itself
#   - The ACR instance
#   - Key Vaults, service connections, or other manually created resources
#
# Usage (run from the root of the workshop repo):
#   chmod +x scripts/cleanup-infra.sh
#   ./scripts/cleanup-infra.sh
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------------------------

# --- Azure ---
SUBSCRIPTION_ID=""                          # <<< your Azure Subscription ID
AKS_RESOURCE_GROUP="rg-workshop-aks"        # <<< resource group that contains your AKS cluster
AKS_NAME="aks-workshop-01"                  # <<< your AKS cluster name

# --- Azure DevOps ---
AZDO_ORG="https://dev.azure.com/<your-org>" # <<< your Azure DevOps org URL
AZDO_PROJECT="workshop-project"             # <<< project name to delete
DELETE_AZDO_PROJECT="true"                  # Set to false to keep the Azure DevOps project.

WORKSHOP_NAMESPACES=(dev staging production)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { echo -e "\n\033[1;34m[INFO]\033[0m  $*"; }
success() { echo -e "\033[1;32m[DONE]\033[0m  $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Step 0 - Verify tooling
# ---------------------------------------------------------------------------
info "Checking required tools..."
command -v az >/dev/null 2>&1 || error "Azure CLI not found. Install from https://aka.ms/installazurecliwindows"
command -v kubectl >/dev/null 2>&1 || error "kubectl not found. Install from https://kubernetes.io/docs/tasks/tools/"

if ! az extension show --name azure-devops --output none &>/dev/null; then
  info "Installing Azure DevOps CLI extension..."
  az extension add --name azure-devops --output none
else
  success "Azure DevOps CLI extension already installed."
fi

# ---------------------------------------------------------------------------
# Step 1 - Azure login & subscription
# ---------------------------------------------------------------------------
info "Logging in to Azure..."
az login --output none

if [[ -n "$SUBSCRIPTION_ID" ]]; then
  az account set --subscription "$SUBSCRIPTION_ID"
fi

ACTIVE_SUB=$(az account show --query "{Name:name, ID:id}" -o tsv)
success "Using subscription: $ACTIVE_SUB"

# ---------------------------------------------------------------------------
# Step 2 - Connect kubectl to the existing AKS cluster
# ---------------------------------------------------------------------------
info "Fetching credentials for AKS cluster: $AKS_NAME..."
az aks get-credentials \
  --resource-group "$AKS_RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --overwrite-existing \
  --output none
success "kubectl context set."

# ---------------------------------------------------------------------------
# Step 3 - Remove workshop namespaces
# ---------------------------------------------------------------------------
info "Deleting workshop namespaces..."
for namespace in "${WORKSHOP_NAMESPACES[@]}"; do
  if kubectl delete namespace "$namespace" --ignore-not-found --wait=false >/dev/null 2>&1; then
    success "Namespace delete requested: $namespace"
  else
    warn "Could not delete namespace '$namespace'."
  fi
done

echo ""
kubectl get namespaces | grep -E "NAME|dev|staging|production" || true

# ---------------------------------------------------------------------------
# Step 4 - Remove Azure DevOps project
# ---------------------------------------------------------------------------
info "Configuring Azure DevOps CLI defaults..."
az devops configure --defaults organization="$AZDO_ORG"

PROJECT_ID=$(az devops project show --project "$AZDO_PROJECT" --query id -o tsv 2>/dev/null || true)
if [[ -z "$PROJECT_ID" ]]; then
  warn "Azure DevOps project '$AZDO_PROJECT' was not found - skipping project cleanup."
elif [[ "$DELETE_AZDO_PROJECT" == "true" ]]; then
  info "Deleting Azure DevOps project: $AZDO_PROJECT..."
  if az devops project delete --id "$PROJECT_ID" --yes --output none; then
    success "Azure DevOps project deletion queued: $AZDO_PROJECT"
  else
    warn "Could not delete Azure DevOps project '$AZDO_PROJECT'. Delete it manually in Azure DevOps if needed."
  fi
else
  warn "DELETE_AZDO_PROJECT is set to false - keeping Azure DevOps project '$AZDO_PROJECT'."
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  CLEANUP COMPLETE"
echo "============================================================"
echo "  AKS Cluster      : $AKS_NAME"
echo "  Namespaces       : dev | staging | production (delete requested)"
echo "  Azure DevOps Org : $AZDO_ORG"
echo "  ADO Project      : $AZDO_PROJECT"
echo "  Project Deleted  : $DELETE_AZDO_PROJECT"
echo "============================================================"
echo ""
echo "  NOTES:"
echo "  1. Namespace deletion is asynchronous and can take a few minutes."
echo "  2. This script does not delete the AKS cluster, ACR, Key Vault, or service connections."
echo "  3. If you created manual workshop resources outside the project, delete those separately."
echo "============================================================"