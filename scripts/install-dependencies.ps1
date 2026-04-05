# =============================================================================
# install-dependencies.ps1
# Fortis Workshop - Install all required tools on Windows
#
# What this script does:
#   1. Checks for winget (App Installer) availability
#   2. Installs or updates: Azure CLI, kubectl, Docker Desktop, Node.js LTS, Git
#   3. Installs the Azure DevOps CLI extension
#   4. Validates all tool versions after installation
#
# Usage (run from an Administrator PowerShell):
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\scripts\install-dependencies.ps1
#
# Notes:
#   - Docker Desktop requires a restart after first install
#   - Some installs may require you to close and reopen your terminal
# =============================================================================

$ErrorActionPreference = "Stop"

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
# Minimum versions (for validation display only)
# ---------------------------------------------------------------------------
$MinVersions = @{
    "Azure CLI"   = "2.55"
    "kubectl"     = "1.28"
    "Node.js"     = "20"
    "Git"         = "2.40"
    "Docker"      = "24"
}

# ---------------------------------------------------------------------------
# Step 0 - Check for winget
# ---------------------------------------------------------------------------
Info "Checking for winget (Windows Package Manager)..."
if (Test-CommandExists "winget") {
    Success "winget is available."
} else {
    Fail "winget is not available. Please install App Installer from the Microsoft Store."
    Fail "https://aka.ms/getwinget"
    exit 1
}

# ---------------------------------------------------------------------------
# Step 1 - Azure CLI
# ---------------------------------------------------------------------------
Info "Checking Azure CLI..."
if (Test-CommandExists "az") {
    $azVer = (az version --output json | ConvertFrom-Json)."azure-cli"
    Success "Azure CLI already installed (v$azVer)."
} else {
    Info "Installing Azure CLI via winget..."
    winget install --id Microsoft.AzureCLI --accept-source-agreements --accept-package-agreements --silent
    Success "Azure CLI installed. You may need to restart your terminal."
}

# ---------------------------------------------------------------------------
# Step 2 - kubectl
# ---------------------------------------------------------------------------
Info "Checking kubectl..."
if (Test-CommandExists "kubectl") {
    $kubectlVer = (kubectl version --client -o json | ConvertFrom-Json).clientVersion.gitVersion
    Success "kubectl already installed ($kubectlVer)."
} else {
    Info "Installing kubectl via Azure CLI..."
    if (Test-CommandExists "az") {
        az aks install-cli
        Success "kubectl installed via az aks install-cli."
    } else {
        Info "Installing kubectl via winget..."
        winget install --id Kubernetes.kubectl --accept-source-agreements --accept-package-agreements --silent
        Success "kubectl installed via winget."
    }
}

# ---------------------------------------------------------------------------
# Step 3 - Docker Desktop
# ---------------------------------------------------------------------------
Info "Checking Docker..."
if (Test-CommandExists "docker") {
    $dockerVer = docker --version
    Success "Docker already installed ($dockerVer)."
} else {
    Info "Installing Docker Desktop via winget..."
    winget install --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements --silent
    Warn "Docker Desktop installed. A RESTART may be required before Docker is available."
    Warn "After restart, open Docker Desktop and complete the initial setup."
}

# ---------------------------------------------------------------------------
# Step 4 - Node.js LTS
# ---------------------------------------------------------------------------
Info "Checking Node.js..."
if (Test-CommandExists "node") {
    $nodeVer = node --version
    $npmVer  = npm --version
    Success "Node.js already installed ($nodeVer, npm $npmVer)."
} else {
    Info "Installing Node.js LTS via winget..."
    winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements --silent
    Success "Node.js LTS installed. You may need to restart your terminal."
}

# ---------------------------------------------------------------------------
# Step 5 - Git
# ---------------------------------------------------------------------------
Info "Checking Git..."
if (Test-CommandExists "git") {
    $gitVer = git --version
    Success "Git already installed ($gitVer)."
} else {
    Info "Installing Git via winget..."
    winget install --id Git.Git --accept-source-agreements --accept-package-agreements --silent
    Success "Git installed. You may need to restart your terminal."
}

# ---------------------------------------------------------------------------
# Step 6 - Azure DevOps CLI extension
# ---------------------------------------------------------------------------
Info "Checking Azure DevOps CLI extension..."
if (Test-CommandExists "az") {
    $extCheck = az extension show --name azure-devops --output none 2>&1
    if ($LASTEXITCODE -eq 0) {
        Success "Azure DevOps CLI extension already installed."
    } else {
        Info "Installing Azure DevOps CLI extension..."
        az extension add --name azure-devops --output none
        Success "Azure DevOps CLI extension installed."
    }
} else {
    Warn "Azure CLI not yet available in this session. Restart your terminal, then run:"
    Warn "  az extension add --name azure-devops"
}

# ---------------------------------------------------------------------------
# Final validation
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor White
Write-Host "  INSTALLATION SUMMARY" -ForegroundColor White
Write-Host "============================================" -ForegroundColor White

$tools = @(
    @{ Name = "Azure CLI";  Cmd = "az";      Check = { (az version --output json | ConvertFrom-Json)."azure-cli" } },
    @{ Name = "kubectl";    Cmd = "kubectl";  Check = { (kubectl version --client -o json | ConvertFrom-Json).clientVersion.gitVersion } },
    @{ Name = "Docker";     Cmd = "docker";   Check = { (docker --version) -replace "Docker version ", "" -replace ",.*", "" } },
    @{ Name = "Node.js";    Cmd = "node";     Check = { node --version } },
    @{ Name = "npm";        Cmd = "npm";      Check = { npm --version } },
    @{ Name = "Git";        Cmd = "git";      Check = { (git --version) -replace "git version ", "" } }
)

foreach ($tool in $tools) {
    if (Test-CommandExists $tool.Cmd) {
        try {
            $ver = & $tool.Check
            Write-Host "  [OK]   $($tool.Name): $ver" -ForegroundColor Green
        } catch {
            Write-Host "  [OK]   $($tool.Name): installed (version check failed)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [MISS] $($tool.Name): not found - restart terminal or install manually" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Minimum recommended versions:" -ForegroundColor Gray
foreach ($kv in $MinVersions.GetEnumerator()) {
    Write-Host "  $($kv.Key) >= $($kv.Value)" -ForegroundColor Gray
}
Write-Host ""

if (-not (Test-CommandExists "docker")) {
    Warn "Docker Desktop requires a system restart after first install."
    Warn "After restart, open Docker Desktop and run: docker run hello-world"
}

Success "Dependency installation complete. Restart your terminal if any tools are missing."
