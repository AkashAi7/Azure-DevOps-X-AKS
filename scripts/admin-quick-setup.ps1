# =============================================================================
# admin-quick-setup.ps1
# Fortis Workshop — COMPLETE admin setup: zero to workshop-ready
#
# This script replaces all manual steps. Run it ONCE before the workshop.
#
# What it does (end to end):
#   Phase 1: Azure Infrastructure  — RG, ACR, AKS, Key Vault
#   Phase 2: AKS Configuration    — credentials, namespaces, ACR pull secrets
#   Phase 3: Azure DevOps Core    — project, push repo
#   Phase 4: Service Connections   — AzureRM + ACR Docker Registry (automated)
#   Phase 5: AzDO Assets          — variable groups, boards, pipelines, artifacts, test plans
#   Phase 6: Environments         — Dev, Staging (delay), Production (approval)
#   Phase 7: Demo Data            — feature branch, broken YAML, PR, branch policies
#   Phase 8: workshop.env         — auto-written with all values
#   Phase 9: Validation           — full end-to-end check
#
# Prerequisites (the ONLY things you need before running):
#   - Azure CLI 2.55+         (az --version)
#   - Azure DevOps extension  (auto-installed if missing)
#   - kubectl                 (kubectl version --client)
#   - git + Node.js + npm
#   - An Azure subscription with Contributor access
#   - An Azure DevOps organization (create at https://dev.azure.com)
#
# Usage:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\scripts\admin-quick-setup.ps1
# =============================================================================

param(
    [switch]$SkipInfra,          # Skip Azure infra creation (brownfield)
    [switch]$SkipDemoData,       # Skip feature branch / PR / broken YAML
    [switch]$NonInteractive      # Use workshop.env values without prompts
)

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Banner ($msg)  { Write-Host "`n$("=" * 70)" -ForegroundColor DarkCyan; Write-Host "  $msg" -ForegroundColor Cyan; Write-Host "$("=" * 70)" -ForegroundColor DarkCyan }
function Phase  ($n,$m) { Write-Host "`n━━━ Phase $n: $m ━━━" -ForegroundColor Magenta }
function Info   ($msg)  { Write-Host "  [INFO]  $msg" -ForegroundColor Gray }
function Action ($msg)  { Write-Host "  [>>]    $msg" -ForegroundColor Yellow }
function Done   ($msg)  { Write-Host "  [DONE]  $msg" -ForegroundColor Green }
function Skip   ($msg)  { Write-Host "  [SKIP]  $msg" -ForegroundColor DarkGray }
function Warn   ($msg)  { Write-Host "  [WARN]  $msg" -ForegroundColor Yellow }
function Err    ($msg)  { Write-Host "  [ERR]   $msg" -ForegroundColor Red }

function PromptWithDefault ($prompt, $default) {
    if ($NonInteractive) { return $default }
    $val = Read-Host "  $prompt [$default]"
    if ([string]::IsNullOrWhiteSpace($val)) { return $default }
    return $val.Trim()
}

function Test-CmdExists ($name) {
    return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

function Invoke-AzDoRest {
    param([string]$Method, [string]$Uri, [object]$Body)
    $token   = $script:AzDoToken
    $headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
    $params  = @{ Method = $Method; Uri = $Uri; Headers = $headers; ContentType = "application/json" }
    if ($Body) { $params.Body = ($Body | ConvertTo-Json -Depth 10) }
    try { return Invoke-RestMethod @params } catch { return $null }
}

# ---------------------------------------------------------------------------
# PHASE 0: Collect Configuration
# ---------------------------------------------------------------------------
Banner "Fortis Workshop — Admin Quick Setup"
Write-Host ""
Write-Host "  This script will set up EVERYTHING for the workshop." -ForegroundColor White
Write-Host "  It is safe to re-run — all steps are idempotent.`n" -ForegroundColor Gray

# Load from workshop.env if it exists
$config = @{
    SubscriptionId = ""
    Location       = "eastus"
    RgName         = "rg-workshop-aks"
    AcrName        = "workshopacr01"
    AksName        = "aks-workshop-01"
    KvName         = "kv-workshop-01"
    AzDoOrg        = ""
    AzDoProject    = "workshop-project"
}

$envFiles = @("workshop.env", "$PSScriptRoot\..\workshop.env")
foreach ($envFile in $envFiles) {
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.+)\s*$' -and $_ -notmatch '^\s*#') {
                $key = $Matches[1]; $val = $Matches[2].Trim()
                switch ($key) {
                    'AZURE_SUBSCRIPTION_ID' { if ($val) { $config.SubscriptionId = $val } }
                    'AKS_RESOURCE_GROUP'    { if ($val) { $config.RgName         = $val } }
                    'AKS_CLUSTER_NAME'      { if ($val) { $config.AksName        = $val } }
                    'ACR_NAME'              { if ($val) { $config.AcrName        = $val } }
                    'AZDO_ORG'              { if ($val) { $config.AzDoOrg        = $val } }
                    'AZDO_PROJECT'          { if ($val) { $config.AzDoProject    = $val } }
                }
            }
        }
        Info "Loaded defaults from: $envFile"
        break
    }
}

# Interactive prompts (skip if -NonInteractive)
if (-not $NonInteractive) {
    Write-Host "  Configure your workshop (press Enter to accept defaults):`n" -ForegroundColor White
}

$config.AzDoOrg        = PromptWithDefault "Azure DevOps Org URL (e.g. https://dev.azure.com/myorg)" $config.AzDoOrg
if ([string]::IsNullOrWhiteSpace($config.AzDoOrg) -or $config.AzDoOrg -match "<your-org>") {
    Err "Azure DevOps org URL is required. Get it from https://dev.azure.com"
    exit 1
}
$config.AzDoProject    = PromptWithDefault "Azure DevOps Project name" $config.AzDoProject
$config.Location       = PromptWithDefault "Azure Region" $config.Location
$config.RgName         = PromptWithDefault "Resource Group name" $config.RgName
$config.AcrName        = PromptWithDefault "ACR name (globally unique, no dots)" $config.AcrName
$config.AksName        = PromptWithDefault "AKS cluster name" $config.AksName
$config.KvName         = PromptWithDefault "Key Vault name (globally unique)" $config.KvName

# ---------------------------------------------------------------------------
# Step 0: Tool checks
# ---------------------------------------------------------------------------
Info "Checking required tools..."
$toolsOk = $true
foreach ($t in @("az","kubectl","git","node","npm")) {
    if (-not (Test-CmdExists $t)) { Err "$t not found — install it first."; $toolsOk = $false }
}
if (-not $toolsOk) { exit 1 }
Done "All required tools found."

# Azure DevOps CLI extension
$extCheck = az extension show --name azure-devops --output none 2>&1
if ($LASTEXITCODE -ne 0) {
    Action "Installing Azure DevOps CLI extension..."
    az extension add --name azure-devops --output none
}

# ---------------------------------------------------------------------------
# Login & subscription
# ---------------------------------------------------------------------------
Action "Logging in to Azure..."
az login --output none

if ($config.SubscriptionId) {
    az account set --subscription $config.SubscriptionId
} else {
    $config.SubscriptionId = az account show --query id -o tsv
}

$subName = az account show --query name -o tsv
Done "Subscription: $subName ($($config.SubscriptionId))"

# Get Azure DevOps access token
Action "Authenticating Azure DevOps CLI..."
$script:AzDoToken = az account get-access-token --resource "499b84ac-1321-427f-aa17-267ca6975798" --query accessToken -o tsv
$env:AZURE_DEVOPS_EXT_PAT = $script:AzDoToken
az devops configure --defaults organization=$($config.AzDoOrg)
Done "Azure DevOps CLI ready."

# =========================================================================
# PHASE 1: Azure Infrastructure
# =========================================================================
if ($SkipInfra) {
    Phase 1 "Azure Infrastructure (SKIPPED — brownfield mode)"
} else {
    Phase 1 "Azure Infrastructure"

    # --- Resource Group ---
    $rgExists = az group exists --name $config.RgName -o tsv
    if ($rgExists -eq "true") {
        Skip "Resource Group '$($config.RgName)' already exists."
    } else {
        Action "Creating Resource Group: $($config.RgName)..."
        az group create --name $config.RgName --location $config.Location --output none
        Done "Resource Group created."
    }

    # --- ACR ---
    $acrCheck = az acr show --name $config.AcrName --output none 2>&1
    if ($LASTEXITCODE -eq 0) {
        Skip "ACR '$($config.AcrName)' already exists."
    } else {
        Action "Creating ACR: $($config.AcrName) (Basic SKU)..."
        az acr create --resource-group $config.RgName --name $config.AcrName --sku Basic --admin-enabled true --output none
        Done "ACR created."
    }

    # --- AKS ---
    $aksCheck = az aks show --resource-group $config.RgName --name $config.AksName --output none 2>&1
    if ($LASTEXITCODE -eq 0) {
        Skip "AKS cluster '$($config.AksName)' already exists."
    } else {
        Action "Creating AKS cluster: $($config.AksName) (3 nodes) — this takes 5-10 minutes..."
        az aks create `
            --resource-group $config.RgName `
            --name $config.AksName `
            --node-count 3 `
            --node-vm-size Standard_D2s_v5 `
            --enable-managed-identity `
            --attach-acr $config.AcrName `
            --generate-ssh-keys `
            --output none
        Done "AKS cluster created."
    }

    # Ensure ACR is attached to AKS (idempotent)
    Action "Ensuring ACR is attached to AKS..."
    az aks update --resource-group $config.RgName --name $config.AksName --attach-acr $config.AcrName --output none 2>&1
    Done "ACR attached to AKS."

    # --- Key Vault ---
    $kvCheck = az keyvault show --name $config.KvName --output none 2>&1
    if ($LASTEXITCODE -eq 0) {
        Skip "Key Vault '$($config.KvName)' already exists."
    } else {
        Action "Creating Key Vault: $($config.KvName)..."
        az keyvault create --resource-group $config.RgName --name $config.KvName --location $config.Location --output none
        Done "Key Vault created."
    }

    # Store ACR password in Key Vault
    Action "Storing ACR admin password in Key Vault..."
    $acrPassword = az acr credential show --name $config.AcrName --query "passwords[0].value" -o tsv
    az keyvault secret set --vault-name $config.KvName --name "acr-admin-password" --value $acrPassword --output none 2>&1
    Done "ACR secret stored in Key Vault."
}

# =========================================================================
# PHASE 2: AKS Configuration
# =========================================================================
Phase 2 "AKS Configuration"

Action "Fetching AKS credentials..."
az aks get-credentials --resource-group $config.RgName --name $config.AksName --overwrite-existing --output none
Done "kubectl context set."

Action "Applying namespaces (dev, staging, production)..."
kubectl apply -f k8s/base/namespace.yaml 2>&1 | Out-Null
Done "Namespaces ready."

Action "Creating ACR pull secrets in all namespaces..."
$acrServer   = az acr show --name $config.AcrName --query loginServer -o tsv
$acrUsername  = az acr credential show --name $config.AcrName --query username -o tsv
$acrPassword  = az acr credential show --name $config.AcrName --query "passwords[0].value" -o tsv

foreach ($ns in @("dev","staging","production")) {
    $yaml = kubectl create secret docker-registry acr-pull-secret `
        --docker-server=$acrServer `
        --docker-username=$acrUsername `
        --docker-password=$acrPassword `
        --namespace=$ns `
        --dry-run=client -o yaml 2>&1
    $yaml | kubectl apply -f - 2>&1 | Out-Null
}
Done "ACR pull secrets created in dev/staging/production."

# =========================================================================
# PHASE 3: Azure DevOps Core
# =========================================================================
Phase 3 "Azure DevOps Project & Repository"

az devops configure --defaults organization=$($config.AzDoOrg) --output none

# --- Create project ---
$projCheck = az devops project show --project $config.AzDoProject --output none 2>&1
if ($LASTEXITCODE -eq 0) {
    Skip "Project '$($config.AzDoProject)' already exists."
} else {
    Action "Creating Azure DevOps project: $($config.AzDoProject)..."
    az devops project create `
        --name $config.AzDoProject `
        --description "Fortis Workshop - AKS DevOps project" `
        --visibility private `
        --process Agile `
        --output none
    Done "Project created."
}

az devops configure --defaults project=$($config.AzDoProject) --output none

# --- Push repo ---
Action "Pushing workshop source to Azure Repos..."
$repoUrl = az repos show --repository $config.AzDoProject --query remoteUrl -o tsv 2>$null

if ($repoUrl) {
    if (-not (Test-Path ".git")) {
        git init -b main 2>&1 | Out-Null
        git add -A 2>&1 | Out-Null
        git commit -m "chore: initial workshop scaffold" --allow-empty 2>&1 | Out-Null
    } else {
        $commitCount = git rev-list --count HEAD 2>$null
        if (-not $commitCount -or $commitCount -eq "0") {
            git add -A 2>&1 | Out-Null
            git commit -m "chore: initial workshop scaffold" --allow-empty 2>&1 | Out-Null
        }
    }

    $existingRemote = git remote get-url azdo 2>$null
    if (-not $existingRemote) {
        git remote add azdo $repoUrl 2>&1 | Out-Null
    } else {
        git remote set-url azdo $repoUrl 2>&1 | Out-Null
    }

    # Use the access token for git push
    $b64Token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("PAT:$($script:AzDoToken)"))
    git -c http.extraHeader="Authorization: Basic $b64Token" push azdo HEAD:main --force 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Done "Source pushed to Azure Repos."
    } else {
        Warn "Git push failed — you may need to push manually: git push azdo HEAD:main"
    }
} else {
    Warn "Could not resolve repo URL. Push to Azure Repos manually."
}

# =========================================================================
# PHASE 4: Service Connections
# =========================================================================
Phase 4 "Service Connections"

# --- Azure RM ---
$existingArm = az devops service-endpoint list --query "[?name=='AzureRM-ServiceConnection'].id" -o tsv 2>$null
if ($existingArm) {
    Skip "AzureRM-ServiceConnection already exists."
} else {
    Action "Creating service principal for Azure RM connection..."
    $spJson = az ad sp create-for-rbac `
        --name "workshop-sp-$($config.AzDoProject)" `
        --role Contributor `
        --scopes "/subscriptions/$($config.SubscriptionId)" `
        --output json 2>$null
    $sp = $spJson | ConvertFrom-Json

    if ($sp) {
        $env:AZURE_DEVOPS_EXT_AZURE_RM_SERVICE_PRINCIPAL_KEY = $sp.password

        $armEp = az devops service-endpoint azurerm create `
            --azure-rm-service-principal-id $sp.appId `
            --azure-rm-subscription-id $config.SubscriptionId `
            --azure-rm-subscription-name $subName `
            --azure-rm-tenant-id $sp.tenant `
            --name "AzureRM-ServiceConnection" `
            --output json 2>$null | ConvertFrom-Json

        if ($armEp) {
            az devops service-endpoint update --id $armEp.id --enable-for-all true --output none 2>$null
            Done "AzureRM-ServiceConnection created and authorized."
        } else {
            Warn "Failed to create AzureRM-ServiceConnection. Create it manually in Project Settings > Service Connections."
        }
    } else {
        Warn "Could not create service principal. Ensure you have AAD permissions."
    }
}

# --- ACR Docker Registry ---
$existingAcr = az devops service-endpoint list --query "[?name=='ACR-ServiceConnection'].id" -o tsv 2>$null
if ($existingAcr) {
    Skip "ACR-ServiceConnection already exists."
} else {
    Action "Creating ACR Docker Registry service connection..."
    $acrLoginServer = az acr show --name $config.AcrName --query loginServer -o tsv
    $acrUser = az acr credential show --name $config.AcrName --query username -o tsv
    $acrPass = az acr credential show --name $config.AcrName --query "passwords[0].value" -o tsv

    # Get project ID for the endpoint config
    $projectId = az devops project show --project $config.AzDoProject --query id -o tsv

    $acrConfig = @{
        data = @{ registrytype = "Others" }
        name = "ACR-ServiceConnection"
        type = "dockerregistry"
        url  = "https://$acrLoginServer"
        authorization = @{
            scheme     = "UsernamePassword"
            parameters = @{
                registry = "https://$acrLoginServer"
                username = $acrUser
                password = $acrPass
            }
        }
        isShared = $false
        isReady  = $true
        serviceEndpointProjectReferences = @(
            @{
                projectReference = @{ id = $projectId; name = $config.AzDoProject }
                name = "ACR-ServiceConnection"
            }
        )
    }

    $configPath = Join-Path $env:TEMP "acr-service-endpoint.json"
    $acrConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8

    $acrEp = az devops service-endpoint create `
        --service-endpoint-configuration $configPath `
        --output json 2>$null | ConvertFrom-Json

    Remove-Item $configPath -ErrorAction SilentlyContinue

    if ($acrEp) {
        az devops service-endpoint update --id $acrEp.id --enable-for-all true --output none 2>$null
        Done "ACR-ServiceConnection created and authorized."
    } else {
        Warn "Failed to create ACR-ServiceConnection. Create manually: Project Settings > Service Connections > Docker Registry."
    }
}

# =========================================================================
# PHASE 5: Azure DevOps Assets
# =========================================================================
Phase 5 "Azure DevOps Assets (Variable Groups, Boards, Pipelines, Artifacts, Test Plans)"

# --- Variable Groups ---
Action "Creating variable groups..."

$acrLoginServer = az acr show --name $config.AcrName --query loginServer -o tsv
$subId = az account show --query id -o tsv

$vg1 = az pipelines variable-group create `
    --name "InventoryAPI-Common" `
    --variables `
        ACR_NAME=$($config.AcrName) `
        ACR_LOGIN_SERVER=$acrLoginServer `
        AKS_RESOURCE_GROUP=$($config.RgName) `
        AKS_CLUSTER_NAME=$($config.AksName) `
        AZURE_SUBSCRIPTION_ID=$subId `
    --output json 2>&1
if ($LASTEXITCODE -eq 0) { Done "InventoryAPI-Common created." } else { Skip "InventoryAPI-Common may already exist." }

$vg2 = az pipelines variable-group create `
    --name "InventoryAPI-Environments" `
    --variables `
        K8S_REPLICAS_DEV=1 `
        K8S_REPLICAS_STAGING=2 `
        K8S_REPLICAS_PROD=3 `
        LOG_LEVEL_DEV=debug `
        LOG_LEVEL_STAGING=info `
        LOG_LEVEL_PROD=warn `
    --output json 2>&1
if ($LASTEXITCODE -eq 0) { Done "InventoryAPI-Environments created." } else { Skip "InventoryAPI-Environments may already exist." }

# InventoryAPI-Secrets — can only be linked to Key Vault via the UI
Warn "InventoryAPI-Secrets must be linked to Key Vault ($($config.KvName)) manually in Pipelines > Library."
Info "Map the secret 'acr-admin-password' to variable 'ACR_PASSWORD'."

# --- Seed Azure Boards ---
Action "Seeding Azure Boards..."

function New-WorkItem ($type, $title, $parentId = $null, $description = "") {
    $argsList = @("boards", "work-item", "create", "--type", $type, "--title", $title, "--output", "json")
    if ($description -ne "") { $argsList += @("--description", $description) }
    $json = az @argsList 2>$null | ConvertFrom-Json
    if (-not $json) { return $null }
    $id = $json.id
    if ($parentId) {
        az boards work-item relation add --id $id --relation-type "System.LinkTypes.Hierarchy-Reverse" --target-id $parentId --output none 2>$null
    }
    return $id
}

$epicId = New-WorkItem "Epic" "Containerize & Deploy InventoryAPI to AKS" -description "End-to-end DevOps pipeline: CI, CD, multi-environment promotion on AKS."
if ($epicId) {
    $f1 = New-WorkItem "Feature" "CI Pipeline - Build, Test & Publish" $epicId
    $s1 = New-WorkItem "User Story" "As a developer, I can trigger an automated build on every commit" $f1
    foreach ($t in @("Create ci-pipeline.yml","Add ESLint lint stage","Add Jest unit-test stage with coverage","Build Docker image and push to ACR")) {
        New-WorkItem "Task" $t $s1 | Out-Null
    }

    $f2 = New-WorkItem "Feature" "CD Pipeline - Multi-Environment Deployment" $epicId
    $s2 = New-WorkItem "User Story" "As an ops engineer, I can promote a release through dev > staging > production" $f2
    foreach ($t in @("Deploy to dev on CI success","Add staging approval gate","Add production gate with rollback","Configure HPA per environment")) {
        New-WorkItem "Task" $t $s2 | Out-Null
    }

    $f3 = New-WorkItem "Feature" "Observability - Health, Metrics & Alerts" $epicId
    $s3 = New-WorkItem "User Story" "As an SRE, I can monitor the API via Prometheus metrics and liveness probes" $f3
    foreach ($t in @("Verify /health and /ready endpoints","Scrape /metrics with Prometheus","Azure Monitor alert for pod restarts")) {
        New-WorkItem "Task" $t $s3 | Out-Null
    }

    $f4 = New-WorkItem "Feature" "GitHub Copilot Agentic DevOps" $epicId
    $s4 = New-WorkItem "User Story" "As a developer, I can use GitHub Copilot to generate and explain pipeline YAML" $f4
    foreach ($t in @("Copilot: generate K8s deployment","Copilot: explain HPA config","Copilot: write unit tests for products route")) {
        New-WorkItem "Task" $t $s4 | Out-Null
    }

    New-WorkItem "Bug" "Health endpoint returns hardcoded version string" $epicId -description "APP_VERSION not injected at deploy time." | Out-Null
    New-WorkItem "Bug" "POST /api/products accepts empty product name" $epicId -description "Validation missing on name field." | Out-Null

    Done "Boards seeded: 1 Epic, 4 Features, 4 Stories, 14 Tasks, 2 Bugs."
} else {
    Warn "Could not seed Boards (API error or permissions). Seed manually or re-run."
}

# --- Import Pipelines ---
Action "Importing pipelines..."

$pipelines = @(
    @{ Name = "InventoryAPI-CI";       Path = "pipelines/ci-pipeline.yml" },
    @{ Name = "InventoryAPI-CD";       Path = "pipelines/cd-pipeline.yml" },
    @{ Name = "InventoryAPI-MultiEnv"; Path = "pipelines/multi-env-pipeline.yml" }
)

foreach ($p in $pipelines) {
    $existing = az pipelines show --name $p.Name --output none 2>&1
    if ($LASTEXITCODE -eq 0) {
        Skip "Pipeline '$($p.Name)' already exists."
    } else {
        az pipelines create `
            --name $p.Name `
            --yml-path $p.Path `
            --repository $config.AzDoProject `
            --repository-type tfsgit `
            --branch main `
            --skip-first-run true `
            --output none 2>&1
        if ($LASTEXITCODE -eq 0) { Done "Imported $($p.Name)." } else { Warn "Failed to import $($p.Name)." }
    }
}

# --- Artifacts Feed ---
Action "Creating Artifacts feed..."
$feedCheck = az artifacts feed show --feed "inventory-api-packages" --output none 2>&1
if ($LASTEXITCODE -eq 0) {
    Skip "Feed 'inventory-api-packages' already exists."
} else {
    az artifacts feed create --name "inventory-api-packages" --output none 2>&1
    if ($LASTEXITCODE -eq 0) { Done "Artifacts feed created." } else { Warn "Could not create feed." }
}

# --- Test Plans ---
Action "Creating Test Plan..."
$testPlanJson = az testplan create --name "InventoryAPI - Workshop Test Plan" --output json 2>$null | ConvertFrom-Json

if ($testPlanJson) {
    $planId = $testPlanJson.id
    $rootSuiteId = az testplan suite list --plan-id $planId --query "[0].id" -o tsv 2>$null

    # Suite 1
    $suite1 = az testplan suite create --plan-id $planId --parent-suite-id $rootSuiteId --name "API Smoke Tests" --suite-type StaticTestSuite --output json 2>$null | ConvertFrom-Json
    if ($suite1) {
        foreach ($tc in @("GET /health returns 200","GET /api/products returns array","POST /api/products creates product","GET /api/products/:id returns 404 for unknown id","GET /ready returns 200")) {
            $tcItem = az boards work-item create --type "Test Case" --title $tc --output json 2>$null | ConvertFrom-Json
            if ($tcItem) { az testplan case add --plan-id $planId --suite-id $suite1.id --test-case-id $tcItem.id --output none 2>$null }
        }
    }

    # Suite 2
    $suite2 = az testplan suite create --plan-id $planId --parent-suite-id $rootSuiteId --name "Pipeline Validation" --suite-type StaticTestSuite --output json 2>$null | ConvertFrom-Json
    if ($suite2) {
        foreach ($tc in @("CI completes in under 5 min","Docker image tagged with build number","Image visible in ACR after CI","CD deploys to dev after CI","Approval gate blocks staging")) {
            $tcItem = az boards work-item create --type "Test Case" --title $tc --output json 2>$null | ConvertFrom-Json
            if ($tcItem) { az testplan case add --plan-id $planId --suite-id $suite2.id --test-case-id $tcItem.id --output none 2>$null }
        }
    }
    Done "Test Plan created with 2 suites and 10 test cases."
} else {
    Warn "Could not create Test Plan — create manually in Azure Test Plans."
}

# =========================================================================
# PHASE 6: Environments
# =========================================================================
Phase 6 "Environments & Approval Gates"

$orgBase    = $config.AzDoOrg
$projectId  = az devops project show --project $config.AzDoProject --query id -o tsv
$envApiBase = "$orgBase/$($config.AzDoProject)/_apis/distributedtask/environments"

$environments = @(
    @{ Name = "InventoryAPI-Dev";        Desc = "Development environment" },
    @{ Name = "InventoryAPI-Staging";    Desc = "Staging environment (delay gate)" },
    @{ Name = "InventoryAPI-Production"; Desc = "Production environment (manual approval)" }
)

$envIds = @{}
foreach ($env in $environments) {
    # Check if environment exists
    $existingEnvs = Invoke-AzDoRest -Method GET -Uri "${envApiBase}?api-version=7.1"
    $found = $existingEnvs.value | Where-Object { $_.name -eq $env.Name }

    if ($found) {
        Skip "Environment '$($env.Name)' already exists (ID: $($found.id))."
        $envIds[$env.Name] = $found.id
    } else {
        $body = @{ name = $env.Name; description = $env.Desc }
        $result = Invoke-AzDoRest -Method POST -Uri "${envApiBase}?api-version=7.1" -Body $body
        if ($result) {
            $envIds[$env.Name] = $result.id
            Done "Created environment: $($env.Name) (ID: $($result.id))"
        } else {
            Warn "Failed to create environment '$($env.Name)' — will be auto-created on first pipeline run."
        }
    }
}

# Add approval check on Production
if ($envIds["InventoryAPI-Production"]) {
    Action "Adding manual approval check on Production..."
    $checksApi = "$orgBase/$($config.AzDoProject)/_apis/pipelines/checks/configurations?api-version=7.2-preview.1"

    # Get current user identity for approval
    $me = az ad signed-in-user show --query id -o tsv 2>$null
    $meDisplayName = az ad signed-in-user show --query displayName -o tsv 2>$null

    if ($me) {
        $approvalBody = @{
            type = @{ id = "8c6f20a7-a545-4486-9777-f762fafe0d4d"; name = "Approval" }
            settings = @{
                approvers = @( @{ id = $me; displayName = $meDisplayName } )
                minRequiredApprovers = 1
                instructions = "Approve production deployment"
                executionOrder = "anyOrder"
            }
            resource = @{
                type = "environment"
                id   = "$($envIds['InventoryAPI-Production'])"
            }
        }

        $checkResult = Invoke-AzDoRest -Method POST -Uri $checksApi -Body $approvalBody
        if ($checkResult) {
            Done "Manual approval added to Production (approver: $meDisplayName)."
        } else {
            Warn "Could not add approval check. Add manually: Environments > InventoryAPI-Production > Approvals & Checks."
        }
    } else {
        Warn "Could not determine current user. Add production approval manually."
    }
}

# =========================================================================
# PHASE 7: Demo Data
# =========================================================================
if ($SkipDemoData) {
    Phase 7 "Demo Data (SKIPPED)"
} else {
    Phase 7 "Demo Data (Branch Policies, Feature Branch, Broken YAML, PR)"

    # --- Branch Policies on main ---
    Action "Setting branch policies on 'main'..."
    $repoId = az repos show --repository $config.AzDoProject --query id -o tsv 2>$null

    if ($repoId) {
        # Minimum 1 reviewer
        az repos policy approver-count create `
            --branch main `
            --repository-id $repoId `
            --minimum-approver-count 1 `
            --creator-vote-counts false `
            --allow-downvotes false `
            --reset-on-source-push true `
            --blocking true `
            --enabled true `
            --output none 2>&1
        Done "Branch policy: minimum 1 reviewer."

        # Comment resolution required
        az repos policy comment-required create `
            --branch main `
            --repository-id $repoId `
            --blocking true `
            --enabled true `
            --output none 2>&1
        Done "Branch policy: comment resolution required."
    } else {
        Warn "Could not set branch policies — repo ID not found."
    }

    # --- Feature Branch ---
    Action "Creating feature branch with sample changes..."
    $b64Token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("PAT:$($script:AzDoToken)"))

    # Create feature branch locally and push
    git checkout -b feature/add-metrics 2>&1 | Out-Null

    # Add a small change to products.js
    $productsFile = "sample-app/src/routes/products.js"
    if (Test-Path $productsFile) {
        $content = Get-Content $productsFile -Raw
        if ($content -notmatch "/metrics") {
            $metricsComment = "`n// TODO: Add Prometheus metrics endpoint for request counting`n"
            Add-Content -Path $productsFile -Value $metricsComment
            git add $productsFile 2>&1 | Out-Null
            git commit -m "feat: add metrics endpoint placeholder" 2>&1 | Out-Null
        }
    }
    git -c http.extraHeader="Authorization: Basic $b64Token" push azdo feature/add-metrics --force 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Done "Feature branch 'feature/add-metrics' pushed." } else { Warn "Could not push feature branch." }

    # Switch back to main
    git checkout main 2>&1 | Out-Null

    # --- Broken YAML for Copilot demo ---
    Action "Creating broken YAML on scratch branch..."
    git checkout -b scratch/broken-yaml 2>&1 | Out-Null

    $brokenYaml = @"
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
        versionSpec: `$(nodeVersion)

    - script: |
        cd sample-app
        npm ci
        npm test
      displayName 'Install and Test'

    - task: Docker@2
      inputs:
        command: buildAndPush
        containerRegistry: ACR-ServiceConnection
        repository: `$(imageName)
        dockerfile: sample-app/Dockerfile
        tags:
          latest
"@

    $brokenYaml | Set-Content -Path "pipelines/broken-demo.yml" -Encoding UTF8
    git add pipelines/broken-demo.yml 2>&1 | Out-Null
    git commit -m "chore: add broken YAML for Copilot demo" 2>&1 | Out-Null
    git -c http.extraHeader="Authorization: Basic $b64Token" push azdo scratch/broken-yaml --force 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Done "Broken YAML pushed to 'scratch/broken-yaml'." } else { Warn "Could not push broken YAML branch." }

    # Switch back to main
    git checkout main 2>&1 | Out-Null
    # Clean up the broken file from working tree
    if (Test-Path "pipelines/broken-demo.yml") { Remove-Item "pipelines/broken-demo.yml" -ErrorAction SilentlyContinue }

    # --- Create Pull Request ---
    Action "Creating Pull Request from feature/add-metrics..."
    $pr = az repos pr create `
        --repository $config.AzDoProject `
        --source-branch feature/add-metrics `
        --target-branch main `
        --title "feat: Add Prometheus metrics endpoint" `
        --description "Adds a placeholder for Prometheus metrics collection on the products route.`n`nLinked to observability user story." `
        --output json 2>$null | ConvertFrom-Json

    if ($pr) {
        Done "Pull Request #$($pr.pullRequestId) created."
    } else {
        Warn "Could not create PR (may already exist). Create manually if needed."
    }
}

# =========================================================================
# PHASE 8: Write workshop.env
# =========================================================================
Phase 8 "Write workshop.env"

$cloneUrl = az repos show --repository $config.AzDoProject --query remoteUrl -o tsv 2>$null

$envContent = @"
# =============================================================================
# workshop.env — Auto-generated by admin-quick-setup.ps1
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm")
# Distribute this file to all participants before the workshop.
# =============================================================================

# --- Azure Subscription ---
AZURE_SUBSCRIPTION_ID=$($config.SubscriptionId)

# --- AKS ---
AKS_RESOURCE_GROUP=$($config.RgName)
AKS_CLUSTER_NAME=$($config.AksName)

# --- ACR ---
ACR_NAME=$($config.AcrName)

# --- Key Vault ---
KEY_VAULT_NAME=$($config.KvName)

# --- Azure DevOps ---
AZDO_ORG=$($config.AzDoOrg)
AZDO_PROJECT=$($config.AzDoProject)
AZDO_CLONE_URL=$cloneUrl
"@

$workshopEnvPath = Join-Path (Split-Path $PSScriptRoot) "workshop.env"
$envContent | Set-Content -Path $workshopEnvPath -Encoding UTF8
Done "workshop.env written to: $workshopEnvPath"
Info "Distribute this file to all participants."

# =========================================================================
# PHASE 9: Validation
# =========================================================================
Phase 9 "Validation"

$checks = @()

# AKS nodes
Action "Checking AKS nodes..."
$nodes = kubectl get nodes --no-headers 2>$null
if ($nodes) { $checks += @{ Name = "AKS Nodes"; Status = "OK"; Detail = "$($nodes.Count) nodes ready" } }
else        { $checks += @{ Name = "AKS Nodes"; Status = "FAIL"; Detail = "Cannot reach cluster" } }

# Namespaces
foreach ($ns in @("dev","staging","production")) {
    $nsCheck = kubectl get namespace $ns --no-headers 2>$null
    if ($nsCheck) { $checks += @{ Name = "Namespace: $ns"; Status = "OK"; Detail = "exists" } }
    else          { $checks += @{ Name = "Namespace: $ns"; Status = "FAIL"; Detail = "missing" } }
}

# ACR
$acrRepos = az acr show --name $config.AcrName --query loginServer -o tsv 2>$null
if ($acrRepos) { $checks += @{ Name = "ACR"; Status = "OK"; Detail = $acrRepos } }
else           { $checks += @{ Name = "ACR"; Status = "FAIL"; Detail = "not reachable" } }

# AzDO Project
$projState = az devops project show --project $config.AzDoProject --query state -o tsv 2>$null
if ($projState -eq "wellFormed") { $checks += @{ Name = "AzDO Project"; Status = "OK"; Detail = $config.AzDoProject } }
else                              { $checks += @{ Name = "AzDO Project"; Status = "FAIL"; Detail = "state: $projState" } }

# Pipelines
foreach ($pName in @("InventoryAPI-CI","InventoryAPI-CD","InventoryAPI-MultiEnv")) {
    $pCheck = az pipelines show --name $pName --output none 2>&1
    if ($LASTEXITCODE -eq 0) { $checks += @{ Name = "Pipeline: $pName"; Status = "OK"; Detail = "imported" } }
    else                     { $checks += @{ Name = "Pipeline: $pName"; Status = "WARN"; Detail = "not found" } }
}

# Service Connections
foreach ($scName in @("AzureRM-ServiceConnection","ACR-ServiceConnection")) {
    $scCheck = az devops service-endpoint list --query "[?name=='$scName'].id" -o tsv 2>$null
    if ($scCheck) { $checks += @{ Name = "SvcConn: $scName"; Status = "OK"; Detail = "created" } }
    else          { $checks += @{ Name = "SvcConn: $scName"; Status = "WARN"; Detail = "MANUAL STEP NEEDED" } }
}

# npm tests
Action "Running sample-app tests..."
Push-Location "sample-app"
npm install --silent 2>&1 | Out-Null
$testOut = npm test 2>&1
if ($LASTEXITCODE -eq 0) { $checks += @{ Name = "npm test"; Status = "OK"; Detail = "all tests pass" } }
else                     { $checks += @{ Name = "npm test"; Status = "WARN"; Detail = "tests failed" } }
Pop-Location

# --- Print Report ---
Write-Host ""
Banner "SETUP COMPLETE — Validation Report"
Write-Host ""

foreach ($c in $checks) {
    $color = switch ($c.Status) { "OK" { "Green" } "WARN" { "Yellow" } default { "Red" } }
    $icon  = switch ($c.Status) { "OK" { "[PASS]" } "WARN" { "[WARN]" } default { "[FAIL]" } }
    Write-Host ("  {0,-6} {1,-30} {2}" -f $icon, $c.Name, $c.Detail) -ForegroundColor $color
}

Write-Host ""
Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  AKS Cluster : $($config.AksName)" -ForegroundColor White
Write-Host "  ACR         : $($config.AcrName).azurecr.io" -ForegroundColor White
Write-Host "  AzDO Project: $($config.AzDoOrg)/$($config.AzDoProject)" -ForegroundColor White
Write-Host "  Key Vault   : $($config.KvName)" -ForegroundColor White
Write-Host ""

# Check for any manual steps still needed
$manualSteps = @()
$scSecrets = az devops service-endpoint list --query "[?name=='InventoryAPI-Secrets']" -o tsv 2>$null
if (-not $scSecrets) {
    $manualSteps += "1. Link 'InventoryAPI-Secrets' variable group to Key Vault '$($config.KvName)'"
    $manualSteps += "   → Pipelines > Library > + Variable group > Link to Key Vault > Map 'acr-admin-password'"
}

if ($manualSteps.Count -gt 0) {
    Write-Host "  REMAINING MANUAL STEP(S):" -ForegroundColor Yellow
    foreach ($step in $manualSteps) {
        Write-Host "  $step" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "  NEXT: Distribute workshop.env to participants." -ForegroundColor Cyan
Write-Host "  NEXT: Run CI pipeline once to pre-stage a successful run." -ForegroundColor Cyan
Write-Host "  NEXT: Participants run: .\scripts\participant-quick-setup.ps1" -ForegroundColor Cyan
Write-Host ""
