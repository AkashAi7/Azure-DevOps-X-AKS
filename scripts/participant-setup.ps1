# =============================================================================
# participant-setup.ps1
# Fortis Workshop - Participant environment setup (Windows)
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
# Usage (run from any directory):
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\scripts\participant-setup.ps1
#
# Before running, get these values from your workshop facilitator:
#   - Azure subscription ID
#   - Azure DevOps org URL and project name
#   - AKS resource group and cluster name
#   - Azure Repos clone URL
# =============================================================================

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# CONFIGURATION - Get these values from your workshop facilitator
# Auto-loaded from workshop.env if present (just drop the file in the repo root)
# ---------------------------------------------------------------------------

$SubscriptionId   = ""                                    # <<< Azure subscription ID
$AksResourceGroup = "rg-workshop-aks"                     # <<< AKS resource group
$AksClusterName   = "aks-workshop-01"                     # <<< AKS cluster name
$AzDoOrg          = "https://dev.azure.com/<your-org>"    # <<< Azure DevOps org URL
$AzDoProject      = "workshop-project"                    # <<< Azure DevOps project name
$CloneUrl         = ""                                    # <<< Azure Repos clone URL (optional - will be derived if empty)

# --- Auto-load from workshop.env if the file exists ---
$envFiles = @("workshop.env", "$PSScriptRoot/../workshop.env")
foreach ($envFile in $envFiles) {
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.+)\s*$' -and $_ -notmatch '^\s*#') {
                $key = $Matches[1]; $val = $Matches[2]
                switch ($key) {
                    'AZURE_SUBSCRIPTION_ID' { if ($val) { $SubscriptionId   = $val } }
                    'AKS_RESOURCE_GROUP'    { if ($val) { $AksResourceGroup = $val } }
                    'AKS_CLUSTER_NAME'      { if ($val) { $AksClusterName   = $val } }
                    'AZDO_ORG'              { if ($val) { $AzDoOrg          = $val } }
                    'AZDO_PROJECT'          { if ($val) { $AzDoProject      = $val } }
                    'AZDO_CLONE_URL'        { if ($val) { $CloneUrl         = $val } }
                }
            }
        }
        Write-Host "[INFO]  Loaded configuration from: $envFile" -ForegroundColor Cyan
        break
    }
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Info    ($msg) { Write-Host "`n[INFO]  $msg" -ForegroundColor Cyan }
function Success ($msg) { Write-Host "[DONE]  $msg" -ForegroundColor Green }
function Warn    ($msg) { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Fail    ($msg) { Write-Host "[FAIL]  $msg" -ForegroundColor Red }

function Test-CommandExists ($name) {
    return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------------------
# Step 1 - Validate prerequisites
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor White
Write-Host "  Fortis Workshop - Participant Setup" -ForegroundColor White
Write-Host "============================================" -ForegroundColor White

Info "Checking required tools..."

$allPresent = $true
$tools = @(
    @{ Name = "Azure CLI"; Cmd = "az" },
    @{ Name = "kubectl";   Cmd = "kubectl" },
    @{ Name = "Docker";    Cmd = "docker" },
    @{ Name = "Node.js";   Cmd = "node" },
    @{ Name = "npm";       Cmd = "npm" },
    @{ Name = "Git";       Cmd = "git" }
)

foreach ($tool in $tools) {
    if (Test-CommandExists $tool.Cmd) {
        try {
            $ver = & $tool.Cmd --version 2>&1 | Select-Object -First 1
            Write-Host "  [OK]   $($tool.Name): $ver" -ForegroundColor Green
        } catch {
            Write-Host "  [OK]   $($tool.Name): installed" -ForegroundColor Green
        }
    } else {
        Write-Host "  [MISS] $($tool.Name): NOT FOUND" -ForegroundColor Red
        $allPresent = $false
    }
}

if (-not $allPresent) {
    Write-Host ""
    Fail "Some required tools are missing. Run install-dependencies.ps1 first:"
    Fail "  .\scripts\install-dependencies.ps1"
    exit 1
}

Success "All required tools are available."

# ---------------------------------------------------------------------------
# Step 2 - Azure login
# ---------------------------------------------------------------------------
Info "Logging in to Azure..."
az login --output none

if ($SubscriptionId -ne "") {
    az account set --subscription $SubscriptionId
}

$activeSub = az account show --query "{Name:name, ID:id}" -o table
Write-Host $activeSub
Success "Azure login complete."

# ---------------------------------------------------------------------------
# Step 3 - Connect to AKS cluster
# ---------------------------------------------------------------------------
Info "Connecting kubectl to AKS cluster: $AksClusterName..."
az aks get-credentials `
    --resource-group $AksResourceGroup `
    --name $AksClusterName `
    --overwrite-existing

Success "kubectl connected to AKS."

# ---------------------------------------------------------------------------
# Step 4 - Validate cluster health
# ---------------------------------------------------------------------------
Info "Checking cluster nodes..."
kubectl get nodes

Info "Checking workshop namespaces..."
$namespaces = kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'
$required = @("dev", "staging", "production")
$missing = @()

foreach ($ns in $required) {
    if ($namespaces -match $ns) {
        Write-Host "  [OK]   Namespace: $ns" -ForegroundColor Green
    } else {
        Write-Host "  [MISS] Namespace: $ns" -ForegroundColor Red
        $missing += $ns
    }
}

if ($missing.Count -gt 0) {
    Warn "Missing namespaces: $($missing -join ', '). Contact your workshop admin."
} else {
    Success "All workshop namespaces are present."
}

# ---------------------------------------------------------------------------
# Step 5 - Azure DevOps CLI authentication
# ---------------------------------------------------------------------------
Info "Setting up Azure DevOps CLI..."
$extCheck = az extension show --name azure-devops --output none 2>&1
if ($LASTEXITCODE -ne 0) {
    az extension add --name azure-devops --output none
}

az devops configure --defaults organization=$AzDoOrg project=$AzDoProject

Info "Verifying Azure DevOps project access..."
$projectCheck = az devops project show --project $AzDoProject --query "{name:name,state:state}" -o table 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host $projectCheck
    Success "Azure DevOps project accessible."
} else {
    Warn "Could not access project '$AzDoProject'. Check your permissions with the facilitator."
}

# ---------------------------------------------------------------------------
# Step 6 - Clone the workshop repository
# ---------------------------------------------------------------------------
if ($CloneUrl -eq "") {
    $CloneUrl = az repos show --repository "Fortis-Workshop" --query remoteUrl -o tsv 2>$null
    if (-not $CloneUrl) {
        $CloneUrl = az repos show --repository $AzDoProject --query remoteUrl -o tsv 2>$null
    }
}

if ($CloneUrl) {
    Info "Cloning workshop repository..."
    $targetDir = "Fortis-Workshop"

    if (Test-Path $targetDir) {
        Warn "Directory '$targetDir' already exists. Pulling latest changes..."
        Push-Location $targetDir
        git pull --rebase 2>&1 | Out-Null
        Pop-Location
    } else {
        git clone $CloneUrl $targetDir
    }
    Success "Repository ready at: $targetDir"
} else {
    Warn "Could not determine clone URL. Clone manually using the URL from Azure Repos."
}

# ---------------------------------------------------------------------------
# Step 7 - Install sample app dependencies and run tests
# ---------------------------------------------------------------------------
$appDir = if (Test-Path "Fortis-Workshop/sample-app") { "Fortis-Workshop/sample-app" }
          elseif (Test-Path "sample-app") { "sample-app" }
          else { $null }

if ($appDir) {
    Info "Installing sample app dependencies..."
    Push-Location $appDir
    npm install 2>&1 | Out-Null

    Info "Running sample app tests..."
    $testResult = npm test 2>&1
    if ($LASTEXITCODE -eq 0) {
        Success "All tests passed."
    } else {
        Warn "Some tests failed. Review the output:"
        Write-Host $testResult
    }
    Pop-Location
} else {
    Warn "sample-app directory not found. Skip npm install/test."
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor White
Write-Host "  SETUP COMPLETE" -ForegroundColor White
Write-Host "============================================" -ForegroundColor White
Write-Host ""
Write-Host "  Subscription : $(az account show --query name -o tsv)" -ForegroundColor Gray
Write-Host "  AKS Cluster  : $AksClusterName" -ForegroundColor Gray
Write-Host "  AzDo Project : $AzDoProject" -ForegroundColor Gray
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "    1. Open Azure DevOps: $AzDoOrg/$AzDoProject" -ForegroundColor Gray
Write-Host "    2. Assign yourself a work item in Boards" -ForegroundColor Gray
Write-Host "    3. Proceed to Lab 02: CI Pipeline" -ForegroundColor Gray
Write-Host ""

Success "You are ready for the workshop!"
