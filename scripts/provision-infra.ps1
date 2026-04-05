# =============================================================================
# provision-infra.ps1
# Fortis Workshop - Workshop-day setup for teams with an existing AKS cluster
#
# What this script does:
#   1. Logs in to Azure and sets the correct subscription
#   2. Pulls kubeconfig for your existing AKS cluster
#   3. Creates Kubernetes namespaces: dev, staging, production
#   4. Creates the Azure DevOps project (if it doesn't exist)
#   5. Creates variable groups: InventoryAPI-Common and InventoryAPI-Environments
#   6. Seeds Azure Boards  - Epic -> Features -> User Stories -> Tasks + Bugs
#   7. Initialises the default Git repo and pushes workshop source code
#   8. Imports CI and CD pipelines from the pipelines/ folder
#   9. Creates an Artifacts feed: inventory-api-packages
#  10. Creates a Test Plan with two suites and sample test cases
#
# Usage (run from the root of the workshop repo):
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\scripts\provision-infra.ps1
#
# Prerequisites:
#   - Azure CLI 2.55+              (az --version)
#   - Azure DevOps CLI extension   (az extension add --name azure-devops)
#   - kubectl 1.28+                (kubectl version --client)
# =============================================================================

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# CONFIGURATION - fill in every value marked  <<<  before running
# Or place a filled-in workshop.env in the repo root and values load automatically.
# ---------------------------------------------------------------------------

# --- Azure ---
$SubscriptionId   = ""                                    # <<< your Azure Subscription ID
$AksResourceGroup = "rg-workshop-aks"                     # <<< resource group that contains your AKS cluster
$AksName          = "aks-workshop-01"                     # <<< your AKS cluster name
$AcrName          = "workshopacr01"                       # <<< your ACR name (without .azurecr.io)

# --- Azure DevOps ---
$AzDoOrg          = "https://dev.azure.com/<your-org>"    # <<< org URL only - no project name (check: dev.azure.com/<orgname>)
$AzDoProject      = "workshop-project"                    # <<< project name to create (or existing)
$AzDoProjectDesc  = "Fortis Workshop - AKS DevOps project"

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
                    'AKS_CLUSTER_NAME'      { if ($val) { $AksName          = $val } }
                    'ACR_NAME'              { if ($val) { $AcrName          = $val } }
                    'AZDO_ORG'              { if ($val) { $AzDoOrg          = $val } }
                    'AZDO_PROJECT'          { if ($val) { $AzDoProject      = $val } }
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

# ---------------------------------------------------------------------------
# Step 0 - Verify tooling
# ---------------------------------------------------------------------------
Info "Checking required tools..."
if (-not (Get-Command az      -ErrorAction SilentlyContinue)) { throw "Azure CLI not found. Install from https://aka.ms/installazurecliwindows" }
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) { throw "kubectl not found. Install from https://kubernetes.io/docs/tasks/tools/" }

# Ensure the Azure DevOps CLI extension is present
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

Info "Authenticating Azure DevOps CLI..."
$env:AZURE_DEVOPS_EXT_PAT = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv
Success "Azure DevOps CLI authenticated (token set via AZURE_DEVOPS_EXT_PAT)."

# ---------------------------------------------------------------------------
# Step 2 - Connect kubectl to the existing AKS cluster
# ---------------------------------------------------------------------------
Info "Fetching credentials for AKS cluster: $AksName..."
az aks get-credentials `
    --resource-group $AksResourceGroup `
    --name $AksName `
    --overwrite-existing
Success "kubectl context set."

Info "Verifying cluster nodes..."
kubectl get nodes
# Expect: all nodes in Ready state before continuing

# ---------------------------------------------------------------------------
# Step 3 - Kubernetes namespaces
# ---------------------------------------------------------------------------
Info "Applying namespace manifests (dev, staging, production)..."
kubectl apply -f k8s/base/namespace.yaml
Success "Namespaces applied."

Write-Host ""
kubectl get namespaces | Select-String -Pattern "NAME|dev|staging|production"

# ---------------------------------------------------------------------------
# Step 4 - Azure DevOps project
# ---------------------------------------------------------------------------
Info "Configuring Azure DevOps CLI defaults..."
az devops configure --defaults organization=$AzDoOrg

# Check if the project already exists
$existingProject = az devops project show --project $AzDoProject --output none 2>&1
if ($LASTEXITCODE -eq 0) {
    Warn "Azure DevOps project '$AzDoProject' already exists - skipping creation."
} else {
    Info "Creating Azure DevOps project: $AzDoProject..."
    az devops project create `
        --name $AzDoProject `
        --description $AzDoProjectDesc `
        --visibility private `
        --process Agile `
        --output none
    Success "Azure DevOps project created: $AzDoProject"
}

# Set project as default for subsequent az devops commands
az devops configure --defaults project=$AzDoProject

# ---------------------------------------------------------------------------
# Step 5 - Variable Groups
# ---------------------------------------------------------------------------

# --- Group 1: InventoryAPI-Common ---
Info "Creating variable group: InventoryAPI-Common..."
$acrLoginServer = az acr show --name $AcrName --query loginServer -o tsv
$subId          = az account show --query id -o tsv

$vgCommon = az pipelines variable-group create `
    --name "InventoryAPI-Common" `
    --variables `
        ACR_NAME=$AcrName `
        AKS_RESOURCE_GROUP=$AksResourceGroup `
        AKS_CLUSTER_NAME=$AksName `
        AZURE_SUBSCRIPTION_ID=$subId `
        ACR_LOGIN_SERVER=$acrLoginServer `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {
    Success "Variable group 'InventoryAPI-Common' created."
} else {
    Warn "Could not create 'InventoryAPI-Common' (may already exist). Check Azure DevOps Library manually."
}

# --- Group 2: InventoryAPI-Environments ---
Info "Creating variable group: InventoryAPI-Environments..."
$vgEnv = az pipelines variable-group create `
    --name "InventoryAPI-Environments" `
    --variables `
        K8S_REPLICAS_DEV=1 `
        K8S_REPLICAS_STAGING=2 `
        K8S_REPLICAS_PROD=3 `
        LOG_LEVEL_DEV=debug `
        LOG_LEVEL_STAGING=info `
        LOG_LEVEL_PROD=warn `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {
    Success "Variable group 'InventoryAPI-Environments' created."
} else {
    Warn "Could not create 'InventoryAPI-Environments' (may already exist). Check Azure DevOps Library manually."
}

# ---------------------------------------------------------------------------
# Step 6 - Seed Azure Boards
# ---------------------------------------------------------------------------
Info "Seeding Azure Boards (Epic -> Features -> Stories -> Tasks + Bugs)..."

# Helper: create a work item and return its ID
function New-WorkItem ($type, $title, $parentId = $null, $description = "") {
    $args = @("boards", "work-item", "create",
        "--type",  $type,
        "--title", $title,
        "--output", "json")
    if ($description -ne "") { $args += @("--description", $description) }
    $json = az @args | ConvertFrom-Json
    $id   = $json.id
    if ($parentId) {
        az boards work-item relation add `
            --id $id `
            --relation-type "System.LinkTypes.Hierarchy-Reverse" `
            --target-id $parentId `
            --output none 2>$null
    }
    return $id
}

# Epic
$epicId = New-WorkItem "Epic" "Containerize & Deploy InventoryAPI to AKS" -description "End-to-end DevOps pipeline for the InventoryAPI microservice covering CI, CD, and multi-environment promotion on AKS."
Success "Created Epic #$epicId"

# Feature 1 - CI Pipeline
$f1 = New-WorkItem "Feature" "CI Pipeline - Build, Test & Publish" $epicId
$s1 = New-WorkItem "User Story" "As a developer, I can trigger an automated build on every commit" $f1
New-WorkItem "Task" "Create ci-pipeline.yml in Azure DevOps" $s1 | Out-Null
New-WorkItem "Task" "Add ESLint lint stage" $s1 | Out-Null
New-WorkItem "Task" "Add Jest unit-test stage with coverage threshold" $s1 | Out-Null
New-WorkItem "Task" "Build Docker image and push to ACR" $s1 | Out-Null
Success "Created Feature 1 (CI Pipeline) and child items."

# Feature 2 - CD Pipeline
$f2 = New-WorkItem "Feature" "CD Pipeline - Multi-Environment Deployment" $epicId
$s2 = New-WorkItem "User Story" "As an ops engineer, I can promote a release through dev -> staging -> production" $f2
New-WorkItem "Task" "Deploy to dev namespace on every successful CI run" $s2 | Out-Null
New-WorkItem "Task" "Add manual approval gate before staging deployment" $s2 | Out-Null
New-WorkItem "Task" "Add production gate with rollback strategy" $s2 | Out-Null
New-WorkItem "Task" "Configure HPA and resource limits per environment" $s2 | Out-Null
Success "Created Feature 2 (CD Pipeline) and child items."

# Feature 3 - Observability
$f3 = New-WorkItem "Feature" "Observability - Health, Metrics & Alerts" $epicId
$s3 = New-WorkItem "User Story" "As an SRE, I can monitor the API via Prometheus metrics and liveness probes" $f3
New-WorkItem "Task" "Verify /health and /ready endpoints respond correctly" $s3 | Out-Null
New-WorkItem "Task" "Scrape /metrics with Prometheus" $s3 | Out-Null
New-WorkItem "Task" "Set up Azure Monitor alert for pod restarts" $s3 | Out-Null
Success "Created Feature 3 (Observability) and child items."

# Feature 4 - GitHub Copilot Integration
$f4 = New-WorkItem "Feature" "GitHub Copilot Agentic DevOps" $epicId
$s4 = New-WorkItem "User Story" "As a developer, I can use GitHub Copilot to generate and explain pipeline YAML" $f4
New-WorkItem "Task" "Use Copilot to generate a Kubernetes deployment manifest" $s4 | Out-Null
New-WorkItem "Task" "Use Copilot to explain the HPA configuration" $s4 | Out-Null
New-WorkItem "Task" "Use Copilot to write unit tests for the products route" $s4 | Out-Null
Success "Created Feature 4 (Copilot) and child items."

# Bugs
$b1 = New-WorkItem "Bug" "Health endpoint returns hardcoded version string" $epicId -description "APP_VERSION env var is not injected at deploy time so /health always returns 1.0.0 regardless of the image tag."
$b2 = New-WorkItem "Bug" "POST /api/products accepts empty product name" $epicId -description "Validation is missing on the name field - an empty string is accepted and stored in the in-memory array."
Success "Created 2 sample Bugs (#$b1, #$b2)."

# ---------------------------------------------------------------------------
# Step 7 - Initialise Git repo and push workshop source
# ---------------------------------------------------------------------------
Info "Initialising the default Azure DevOps Git repository..."

# Get the default repo URL (same name as the project)
$repoUrl = az repos show `
    --repository $AzDoProject `
    --query remoteUrl -o tsv 2>$null

if ($repoUrl) {
    # Initialise a local git repo if one doesn't exist yet
    if (-not (Test-Path ".git")) {
        Info "Initialising local git repository..."
        git init -b main
        git add -A
        git commit -m "chore: initial workshop scaffold" --allow-empty
    } else {
        # Make sure there is at least one commit so push doesn't fail
        $commitCount = git rev-list --count HEAD 2>$null
        if ($commitCount -eq 0) {
            git add -A
            git commit -m "chore: initial workshop scaffold" --allow-empty
        }
    }

    # Configure git credential helper for Azure DevOps
    git config credential.helper manager 2>$null

    # Add/update the azdo remote
    $existingRemote = git remote get-url azdo 2>$null
    if (-not $existingRemote) {
        git remote add azdo $repoUrl
    } else {
        git remote set-url azdo $repoUrl
    }

    git push azdo HEAD:main --force 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Success "Workshop source pushed to Azure DevOps repo: $repoUrl"
    } else {
        Warn "Git push failed. Authenticate with 'git credential-manager' or push manually: git push azdo HEAD:main"
    }
} else {
    Warn "Could not resolve repo URL for '$AzDoProject' - push to Azure Repos manually."
}

# ---------------------------------------------------------------------------
# Step 8 - Import pipelines
# ---------------------------------------------------------------------------
Info "Importing CI pipeline..."
az pipelines create `
    --name "InventoryAPI-CI" `
    --yml-path "pipelines/ci-pipeline.yml" `
    --repository $AzDoProject `
    --repository-type tfsgit `
    --branch main `
    --skip-first-run true `
    --output none 2>&1
if ($LASTEXITCODE -eq 0) { Success "CI pipeline imported." } else { Warn "CI pipeline import failed or already exists." }

Info "Importing CD pipeline..."
az pipelines create `
    --name "InventoryAPI-CD" `
    --yml-path "pipelines/cd-pipeline.yml" `
    --repository $AzDoProject `
    --repository-type tfsgit `
    --branch main `
    --skip-first-run true `
    --output none 2>&1
if ($LASTEXITCODE -eq 0) { Success "CD pipeline imported." } else { Warn "CD pipeline import failed or already exists." }

Info "Importing multi-env pipeline..."
az pipelines create `
    --name "InventoryAPI-MultiEnv" `
    --yml-path "pipelines/multi-env-pipeline.yml" `
    --repository $AzDoProject `
    --repository-type tfsgit `
    --branch main `
    --skip-first-run true `
    --output none 2>&1
if ($LASTEXITCODE -eq 0) { Success "Multi-env pipeline imported." } else { Warn "Multi-env pipeline import failed or already exists." }

# ---------------------------------------------------------------------------
# Step 9 - Artifacts feed
# ---------------------------------------------------------------------------
Info "Creating Artifacts feed: inventory-api-packages..."
# Check if the feed already exists before trying to create
$feedCheck = az artifacts feed show --feed "inventory-api-packages" --output none 2>&1
if ($LASTEXITCODE -eq 0) {
    Warn "Artifacts feed 'inventory-api-packages' already exists - skipping."
} else {
    az artifacts feed create `
        --name "inventory-api-packages" `
        --output none 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Success "Artifacts feed 'inventory-api-packages' created."
    } else {
        Warn "Could not create Artifacts feed - create 'inventory-api-packages' manually in Azure Artifacts."
    }
}

# ---------------------------------------------------------------------------
# Step 10 - Test Plans
# ---------------------------------------------------------------------------
Info "Creating Test Plan with sample test cases..."

# Create the Test Plan
$testPlanJson = az testplan create `
    --name "InventoryAPI - Workshop Test Plan" `
    --output json 2>$null | ConvertFrom-Json

if ($testPlanJson) {
    $planId = $testPlanJson.id
    Success "Test Plan created (ID: $planId)"

    # Retrieve the root static suite that Azure DevOps auto-creates on every plan
    $rootSuiteId = az testplan suite list `
        --plan-id $planId `
        --query "[0].id" -o tsv 2>$null

    # Suite 1 - API Smoke Tests
    $suite1Json = az testplan suite create `
        --plan-id $planId `
        --parent-suite-id $rootSuiteId `
        --name "API Smoke Tests" `
        --suite-type StaticTestSuite `
        --output json 2>$null | ConvertFrom-Json
    $s1Id = $suite1Json.id

    foreach ($tc in @(
        "GET /health returns 200 with status=healthy",
        "GET /ready returns 200 with status=ready",
        "GET /api/products returns an array",
        "POST /api/products creates a new product",
        "GET /api/products/:id returns 404 for unknown id"
    )) {
        $tcJson = az boards work-item create --type "Test Case" --title $tc --output json 2>$null | ConvertFrom-Json
        az testplan case add --plan-id $planId --suite-id $s1Id --test-case-id $tcJson.id --output none 2>$null
    }
    Success "Suite 'API Smoke Tests' created with 5 test cases."

    # Suite 2 - Pipeline Validation
    $suite2Json = az testplan suite create `
        --plan-id $planId `
        --parent-suite-id $rootSuiteId `
        --name "Pipeline Validation" `
        --suite-type StaticTestSuite `
        --output json 2>$null | ConvertFrom-Json
    $s2Id = $suite2Json.id

    foreach ($tc in @(
        "CI pipeline completes in under 5 minutes",
        "Docker image is tagged with the build number",
        "Image is visible in ACR after successful CI run",
        "CD deploys to dev namespace after CI succeeds",
        "Manual approval gate blocks staging deployment"
    )) {
        $tcJson = az boards work-item create --type "Test Case" --title $tc --output json 2>$null | ConvertFrom-Json
        az testplan case add --plan-id $planId --suite-id $s2Id --test-case-id $tcJson.id --output none 2>$null
    }
    Success "Suite 'Pipeline Validation' created with 5 test cases."

} else {
    Warn "Could not create Test Plan - create 'InventoryAPI Workshop Test Plan' manually in Azure Test Plans."
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  SETUP COMPLETE"                                              -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  AKS Cluster      : $AksName"
Write-Host "  ACR              : $AcrName  ($acrLoginServer)"
Write-Host "  Namespaces       : dev | staging | production"
Write-Host "  Azure DevOps Org : $AzDoOrg"
Write-Host "  ADO Project      : $AzDoProject"
Write-Host "  Variable Groups  : InventoryAPI-Common, InventoryAPI-Environments"
Write-Host "  Boards           : 1 Epic | 4 Features | 4 Stories | 14 Tasks | 2 Bugs"
Write-Host "  Pipelines        : InventoryAPI-CI | InventoryAPI-CD | InventoryAPI-MultiEnv"
Write-Host "  Artifacts Feed   : inventory-api-packages"
Write-Host "  Test Plan        : InventoryAPI Workshop Test Plan (2 suites, 10 cases)"
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  NEXT STEPS:"
Write-Host "  1. Go to $AzDoOrg/$AzDoProject/_library"
Write-Host "     and manually add 'InventoryAPI-Secrets' linked to Key Vault"
Write-Host "     (see pipelines/variable-groups/README-variable-groups.md)"
Write-Host "  2. Create an Azure DevOps service connection to your AKS cluster"
Write-Host "     (Project Settings -> Service connections -> New -> Kubernetes)"
Write-Host "  3. Continue with labs/lab-02-ci-pipeline.md"
Write-Host "============================================================" -ForegroundColor Green
