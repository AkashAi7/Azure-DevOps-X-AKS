# =============================================================================
# participant-quick-setup.ps1
# Fortis Workshop — Single-command participant onboarding
#
# Prerequisite: Get workshop.env from your facilitator and place it in the
#               repo root (next to README.md) BEFORE running this script.
#
# What it does:
#   1. Checks all tools (offers install commands for anything missing)
#   2. Reads workshop.env for all config values
#   3. Logs in to Azure & connects to AKS
#   4. Verifies cluster health & namespaces
#   5. Verifies Azure DevOps project access
#   6. Clones the repo (or pulls latest if already cloned)
#   7. Installs sample-app dependencies & runs tests
#   8. Prints a ready-to-go summary
#
# Usage:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\scripts\participant-quick-setup.ps1
# =============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Banner ($msg) { Write-Host "`n$("=" * 60)" -ForegroundColor DarkCyan; Write-Host "  $msg" -ForegroundColor Cyan; Write-Host "$("=" * 60)" -ForegroundColor DarkCyan }
function Step ($n,$m)  { Write-Host "`n  [$n/7] $m" -ForegroundColor White }
function Ok   ($msg)   { Write-Host "       [OK]   $msg" -ForegroundColor Green }
function Miss ($msg)   { Write-Host "       [MISS] $msg" -ForegroundColor Red }
function Info ($msg)   { Write-Host "       $msg" -ForegroundColor Gray }
function Warn ($msg)   { Write-Host "       [WARN] $msg" -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# Load workshop.env
# ---------------------------------------------------------------------------
Banner "Fortis Workshop — Participant Setup"

$envFile = $null
foreach ($candidate in @("workshop.env", "$PSScriptRoot\..\workshop.env")) {
    if (Test-Path $candidate) { $envFile = $candidate; break }
}

if (-not $envFile) {
    Write-Host ""
    Miss "workshop.env not found!"
    Write-Host ""
    Write-Host "  Get workshop.env from your facilitator and place it" -ForegroundColor Yellow
    Write-Host "  in the repo root folder (next to README.md)." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

$cfg = @{}
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.+)\s*$' -and $_ -notmatch '^\s*#') {
        $cfg[$Matches[1].Trim()] = $Matches[2].Trim()
    }
}

$SubscriptionId = $cfg["AZURE_SUBSCRIPTION_ID"]
$RgName         = $cfg["AKS_RESOURCE_GROUP"]
$AksName        = $cfg["AKS_CLUSTER_NAME"]
$AzDoOrg        = $cfg["AZDO_ORG"]
$AzDoProject    = $cfg["AZDO_PROJECT"]
$CloneUrl       = $cfg["AZDO_CLONE_URL"]

Ok "Loaded config from: $envFile"
Info "Project: $AzDoOrg / $AzDoProject"

# ---------------------------------------------------------------------------
# Step 1: Tool check
# ---------------------------------------------------------------------------
Step 1 "Checking required tools"

$allOk = $true
$tools = @(
    @{ Name = "Azure CLI"; Cmd = "az";      Install = "winget install Microsoft.AzureCLI" },
    @{ Name = "kubectl";   Cmd = "kubectl";  Install = "winget install Kubernetes.kubectl" },
    @{ Name = "Git";       Cmd = "git";      Install = "winget install Git.Git" },
    @{ Name = "Node.js";   Cmd = "node";     Install = "winget install OpenJS.NodeJS.LTS" },
    @{ Name = "npm";       Cmd = "npm";      Install = "(included with Node.js)" },
    @{ Name = "Docker";    Cmd = "docker";   Install = "winget install Docker.DockerDesktop" }
)

foreach ($t in $tools) {
    $exists = Get-Command $t.Cmd -ErrorAction SilentlyContinue
    if ($exists) {
        try { $ver = & $t.Cmd --version 2>&1 | Select-Object -First 1 } catch { $ver = "installed" }
        Ok "$($t.Name): $ver"
    } else {
        Miss "$($t.Name) not found — install with: $($t.Install)"
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Warn "Install missing tools and re-run this script."
    Write-Host "  Or run: .\scripts\install-dependencies.ps1" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Ensure Azure DevOps CLI extension
$extCheck = az extension show --name azure-devops --output none 2>&1
if ($LASTEXITCODE -ne 0) {
    Info "Installing Azure DevOps CLI extension..."
    az extension add --name azure-devops --output none
}

# ---------------------------------------------------------------------------
# Step 2: Azure login
# ---------------------------------------------------------------------------
Step 2 "Logging in to Azure"

az login --output none 2>&1

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
}

$subName = az account show --query name -o tsv
$subId   = az account show --query id -o tsv
Ok "Subscription: $subName ($subId)"

# ---------------------------------------------------------------------------
# Step 3: Connect to AKS
# ---------------------------------------------------------------------------
Step 3 "Connecting to AKS cluster"

az aks get-credentials `
    --resource-group $RgName `
    --name $AksName `
    --overwrite-existing `
    --output none

Ok "kubectl connected to: $AksName"

# ---------------------------------------------------------------------------
# Step 4: Verify cluster
# ---------------------------------------------------------------------------
Step 4 "Verifying cluster & namespaces"

$nodeCount = (kubectl get nodes --no-headers 2>$null | Measure-Object).Count
if ($nodeCount -gt 0) {
    Ok "Cluster has $nodeCount node(s) ready."
} else {
    Miss "Cannot reach cluster nodes. Ask your facilitator for help."
}

$allNsOk = $true
foreach ($ns in @("dev","staging","production")) {
    $nsCheck = kubectl get namespace $ns --no-headers 2>$null
    if ($nsCheck) { Ok "Namespace: $ns" } else { Miss "Namespace '$ns' missing"; $allNsOk = $false }
}

# ---------------------------------------------------------------------------
# Step 5: Verify Azure DevOps access
# ---------------------------------------------------------------------------
Step 5 "Verifying Azure DevOps project access"

az devops configure --defaults organization=$AzDoOrg project=$AzDoProject --output none 2>&1

$projState = az devops project show --project $AzDoProject --query state -o tsv 2>$null
if ($projState -eq "wellFormed") {
    Ok "Project '$AzDoProject' is accessible."
} else {
    Warn "Cannot access project '$AzDoProject'. Check permissions with your facilitator."
}

# ---------------------------------------------------------------------------
# Step 6: Clone / update repo
# ---------------------------------------------------------------------------
Step 6 "Setting up workshop repository"

# Auto-derive clone URL if not provided
if (-not $CloneUrl) {
    $CloneUrl = az repos show --repository "Fortis-Workshop" --query remoteUrl -o tsv 2>$null
    if (-not $CloneUrl) {
        $CloneUrl = az repos show --repository $AzDoProject --query remoteUrl -o tsv 2>$null
    }
}

# Only clone if we're not already inside the repo
$inRepo = Test-Path "sample-app/package.json"
if ($inRepo) {
    Ok "Already inside workshop repo — pulling latest..."
    git pull --rebase 2>&1 | Out-Null
} elseif ($CloneUrl) {
    if (Test-Path "Fortis-Workshop") {
        Ok "Repo folder exists — pulling latest..."
        Push-Location "Fortis-Workshop"
        git pull --rebase 2>&1 | Out-Null
        Pop-Location
    } else {
        Info "Cloning from Azure Repos..."
        git clone $CloneUrl Fortis-Workshop 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Ok "Cloned to ./Fortis-Workshop" } else { Warn "Clone failed — try manually: git clone $CloneUrl" }
    }
} else {
    Warn "Could not determine clone URL. Clone the repo manually from Azure Repos."
}

# ---------------------------------------------------------------------------
# Step 7: Install deps & run tests
# ---------------------------------------------------------------------------
Step 7 "Installing dependencies & running tests"

$appDir = if (Test-Path "sample-app/package.json") { "sample-app" }
          elseif (Test-Path "Fortis-Workshop/sample-app/package.json") { "Fortis-Workshop/sample-app" }
          else { $null }

if ($appDir) {
    Push-Location $appDir
    Info "Running npm install..."
    npm install --silent 2>&1 | Out-Null

    Info "Running npm test..."
    $testResult = npm test 2>&1
    if ($LASTEXITCODE -eq 0) {
        Ok "All tests passed."
    } else {
        Warn "Some tests failed — review output above."
    }
    Pop-Location
} else {
    Warn "sample-app not found. Run 'npm install && npm test' manually after cloning."
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Banner "YOU'RE ALL SET!"
Write-Host ""
Write-Host "  Subscription : $subName" -ForegroundColor White
Write-Host "  AKS Cluster  : $AksName" -ForegroundColor White
Write-Host "  AzDO Project : $AzDoOrg/$AzDoProject" -ForegroundColor White
Write-Host ""
Write-Host "  Open in browser:" -ForegroundColor Gray
Write-Host "    $AzDoOrg/$AzDoProject" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Quick commands to verify:" -ForegroundColor Gray
Write-Host "    kubectl get namespaces" -ForegroundColor DarkGray
Write-Host "    kubectl get nodes" -ForegroundColor DarkGray
Write-Host "    cd sample-app && npm test" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Ready for Lab 01! Open: labs/lab-01-setup.md" -ForegroundColor Green
Write-Host ""
