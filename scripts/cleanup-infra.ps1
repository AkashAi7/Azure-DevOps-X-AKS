# =============================================================================
# cleanup-infra.ps1
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
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\scripts\cleanup-infra.ps1
# =============================================================================

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------------------------

# --- Azure ---
$SubscriptionId   = "4459723a-46af-46c3-af53-dfb3a134618b"
$AksResourceGroup = "AKS_training"
$AksName          = "testcluster"

# --- Azure DevOps ---
$AzDoOrg          = "https://dev.azure.com/akashdwivedi/AkashDSolutions"
$AzDoProject      = "workshop-project"
$DeleteAzDoProject = $true   # Set to $false to keep the Azure DevOps project.

$WorkshopNamespaces = @("dev", "staging", "production")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Info    ($msg) { Write-Host "`n[INFO]  $msg" -ForegroundColor Cyan }
function Success ($msg) { Write-Host "[DONE]  $msg" -ForegroundColor Green }
function Warn    ($msg) { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }

function Test-CommandExists ($name) {
    return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------------------
# Step 0 - Verify tooling
# ---------------------------------------------------------------------------
Info "Checking required tools..."
if (-not (Test-CommandExists "az")) { throw "Azure CLI not found. Install from https://aka.ms/installazurecliwindows" }
if (-not (Test-CommandExists "kubectl")) { throw "kubectl not found. Install from https://kubernetes.io/docs/tasks/tools/" }

$extCheck = az extension show --name azure-devops --output none 2>&1
if ($LASTEXITCODE -ne 0) {
    Info "Installing Azure DevOps CLI extension..."
    az extension add --name azure-devops --output none
} else {
    Success "Azure DevOps CLI extension already installed."
}

# ---------------------------------------------------------------------------
# Step 1 - Azure login & subscription
# ---------------------------------------------------------------------------
Info "Logging in to Azure..."
az login --output none

if ($SubscriptionId -ne "") {
    az account set --subscription $SubscriptionId
}

$activeSub = az account show --query "{Name:name, ID:id}" -o tsv
Success "Using subscription: $activeSub"

# ---------------------------------------------------------------------------
# Step 2 - Connect kubectl to the existing AKS cluster
# ---------------------------------------------------------------------------
Info "Fetching credentials for AKS cluster: $AksName..."
az aks get-credentials `
    --resource-group $AksResourceGroup `
    --name $AksName `
    --overwrite-existing `
    --output none
Success "kubectl context set."

# ---------------------------------------------------------------------------
# Step 3 - Remove workshop namespaces
# ---------------------------------------------------------------------------
Info "Deleting workshop namespaces..."
foreach ($namespace in $WorkshopNamespaces) {
    kubectl delete namespace $namespace --ignore-not-found --wait=false | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Success "Namespace delete requested: $namespace"
    } else {
        Warn "Could not delete namespace '$namespace'."
    }
}

Write-Host ""
kubectl get namespaces | Select-String -Pattern "NAME|dev|staging|production"

# ---------------------------------------------------------------------------
# Step 4 - Remove Azure DevOps project
# ---------------------------------------------------------------------------
Info "Configuring Azure DevOps CLI defaults..."
az devops configure --defaults organization=$AzDoOrg

$projectId = az devops project show --project $AzDoProject --query id -o tsv 2>$null
if (-not $projectId) {
    Warn "Azure DevOps project '$AzDoProject' was not found - skipping project cleanup."
} elseif ($DeleteAzDoProject) {
    Info "Deleting Azure DevOps project: $AzDoProject..."
    az devops project delete --id $projectId --yes --output none
    if ($LASTEXITCODE -eq 0) {
        Success "Azure DevOps project deletion queued: $AzDoProject"
    } else {
        Warn "Could not delete Azure DevOps project '$AzDoProject'. Delete it manually in Azure DevOps if needed."
    }
} else {
    Warn "DeleteAzDoProject is set to `$false - keeping Azure DevOps project '$AzDoProject'."
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  CLEANUP COMPLETE"                                           -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  AKS Cluster      : $AksName"
Write-Host "  Namespaces       : dev | staging | production (delete requested)"
Write-Host "  Azure DevOps Org : $AzDoOrg"
Write-Host "  ADO Project      : $AzDoProject"
Write-Host "  Project Deleted  : $DeleteAzDoProject"
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  NOTES:"
Write-Host "  1. Namespace deletion is asynchronous and can take a few minutes."
Write-Host "  2. This script does not delete the AKS cluster, ACR, Key Vault, or service connections."
Write-Host "  3. If you created manual workshop resources outside the project, delete those separately."
Write-Host "============================================================" -ForegroundColor Green