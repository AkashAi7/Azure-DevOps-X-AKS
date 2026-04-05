# Facilitator Demo Setup Guide

**Time required:** 2-3 hours before the workshop  
**Purpose:** Pre-configure all Azure resources so live demos run smoothly

---

## Azure Resources to Pre-Provision

### 1. Resource Group

```bash
LOCATION="eastus"
RG_NAME="rg-workshop-aks"

az group create \
  --name $RG_NAME \
  --location $LOCATION
```

### 2. Azure Container Registry (ACR)

```bash
ACR_NAME="workshopacr$(date +%m%d)"   # e.g. workshopacr0319

az acr create \
  --resource-group $RG_NAME \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true

echo "ACR Login Server: ${ACR_NAME}.azurecr.io"
```

### 3. AKS Cluster

```bash
AKS_CLUSTER="aks-workshop-01"

az aks create \
  --resource-group $RG_NAME \
  --name $AKS_CLUSTER \
  --node-count 3 \
  --node-vm-size Standard_D2s_v5 \
  --enable-managed-identity \
  --attach-acr $ACR_NAME \
  --generate-ssh-keys

echo "AKS cluster provisioned"
```

> The `--attach-acr` flag grants the AKS managed identity `AcrPull` permission automatically.

### 4. Create Kubernetes Namespaces

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group $RG_NAME \
  --name $AKS_CLUSTER \
  --overwrite-existing

# Apply namespaces
kubectl apply -f k8s/base/namespace.yaml

# Verify
kubectl get namespaces
```

### 5. Azure Key Vault

```bash
KV_NAME="kv-workshop-$(date +%m%d)"

az keyvault create \
  --resource-group $RG_NAME \
  --name $KV_NAME \
  --location $LOCATION

# Store ACR password as a secret
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

az keyvault secret set \
  --vault-name $KV_NAME \
  --name "acr-admin-password" \
  --value "$ACR_PASSWORD"

echo "Key Vault created: $KV_NAME"
echo "Secret 'acr-admin-password' stored"
```

---

## Azure DevOps Project Setup

### 1. Create Project

1. Go to `https://dev.azure.com/<your-org>`
2. Click **New project**
3. Name: `workshop-project`
4. Visibility: Private
5. Version control: Git
6. Work item process: Agile

### 2. Import Repository

```bash
# Option A: Push this repo to Azure Repos
cd "path/to/Fortis-Workshop"
git remote add azure https://<your-org>@dev.azure.com/<your-org>/workshop-project/_git/Fortis-Workshop
git push azure --all
```

Or in Azure DevOps:
1. **Repos** → **Import repository**
2. Source type: Git
3. Clone URL: your GitHub repo URL

### 3. Create Service Connections

#### Azure Resource Manager Connection
1. **Project Settings** → **Service connections** → **New**
2. Type: **Azure Resource Manager**
3. Authentication method: Service Principal (automatic)
4. Scope: Subscription
5. Name: `AzureRM-ServiceConnection`
6. Grant access to all pipelines: ✅

#### ACR Docker Registry Connection
1. **Project Settings** → **Service connections** → **New**
2. Type: **Docker Registry**
3. Registry type: Azure Container Registry
4. Select your ACR
5. Name: `ACR-ServiceConnection`
6. Grant access: ✅

### 4. Create Variable Groups

#### Group: InventoryAPI-Common

1. **Pipelines** → **Library** → **+ Variable group**
2. Name: `InventoryAPI-Common`
3. Add variables:

```
ACR_NAME          = workshopacr0319   (your ACR name without .azurecr.io)
AKS_RESOURCE_GROUP = rg-workshop-aks
AKS_CLUSTER_NAME  = aks-workshop-01
AZURE_SUBSCRIPTION_ID = <your-subscription-id>
```

4. Save

#### Group: InventoryAPI-Secrets (Key Vault linked)

1. **Pipelines** → **Library** → **+ Variable group**
2. Name: `InventoryAPI-Secrets`
3. Toggle: **Link secrets from an Azure Key Vault as variables**
4. Service connection: `AzureRM-ServiceConnection`
5. Key vault: `kv-workshop-0319`
6. Add: `acr-admin-password`
7. Save

### 5. Import Pipelines

#### CI Pipeline
1. **Pipelines** → **New pipeline** → **Azure Repos Git**
2. Repository: `Fortis-Workshop`
3. Select **Existing YAML** → `/pipelines/ci-pipeline.yml`
4. **Save** (name it `InventoryAPI-CI`)

#### CD Pipeline
1. Repeat above with `/pipelines/cd-pipeline.yml`
2. Name it `InventoryAPI-CD`

#### Multi-Env Pipeline (for demo only)
1. Repeat with `/pipelines/multi-env-pipeline.yml`
2. Name it `InventoryAPI-MultiEnv`

### 6. Create Azure DevOps Environments

Run this script to pre-create environments via CLI (or do it manually):

```bash
# These are created via the UI — see Lab 03 instructions
# Pre-create them before the workshop session
echo "Create these environments in Azure DevOps:"
echo "  - InventoryAPI-Dev    (Kubernetes: dev namespace)"
echo "  - InventoryAPI-Staging (Kubernetes: staging namespace + 5min delay)"
echo "  - InventoryAPI-Production (Kubernetes: production namespace + approval)"
```

### 7. Create ACR Pull Secrets in AKS

```bash
ACR_SERVER="${ACR_NAME}.azurecr.io"
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

for NS in dev staging production; do
  kubectl create secret docker-registry acr-pull-secret \
    --docker-server=$ACR_SERVER \
    --docker-username=$ACR_USERNAME \
    --docker-password=$ACR_PASSWORD \
    --namespace=$NS \
    --dry-run=client -o yaml | kubectl apply -f -
done
```

### 8. Do a Full Pre-Run

Before the workshop, run the CI → CD pipeline once end-to-end:

```bash
# Trigger CI by pushing a commit
git commit --allow-empty -m "chore: pre-workshop pipeline warm-up"
git push azure main
```

Watch it complete fully. Verify:
- Image exists in ACR
- Pods running in all 3 namespaces
- `kubectl get pods --all-namespaces | grep inventory`

---

## Azure Boards Setup

### Create Sample Work Items

1. **Boards** → **Backlogs**
2. Create:
   - Epic: "InventoryAPI v1.0 Release"
   - Feature: "Core API Endpoints"
   - User Story: "As a warehouse manager, I can view product inventory" 
   - User Story: "As a warehouse manager, I can add new products"
   - Task: "Write unit tests for GET /api/products"

3. Assign all to current sprint

### Create a Dashboard

1. **Overview** → **Dashboards** → **+ New dashboard**
2. Name: "InventoryAPI Build & Release"
3. Add widgets:
   - **Build History** — linked to `InventoryAPI-CI`
   - **Deployment Status** — all 3 environments
   - **Burndown Chart** — current sprint
   - **Test Results Trend** — from CI pipeline

---

## GitHub Copilot Verification

Before the session, verify participants have Copilot:

```
Share this test prompt with participants:
"Open VS Code, create a file test.js, 
type: // function to add two numbers
and see if Copilot suggests the function body"
```

---

## Facilitator Screen Layout (Recommended)

```
Monitor 1 (main/presenter):
┌────────────────────┬────────────────────┐
│   VS Code / Code   │  Azure DevOps      │
│   (left half)      │  (right half)      │
└────────────────────┴────────────────────┘

Monitor 2 (notes/reference):
┌────────────────────────────────────────┐
│  This demo-setup.md file               │
│  Terminal with kubectl commands ready  │
└────────────────────────────────────────┘
```

---

## Emergency Backup Plan

If the live pipeline demo fails (network, auth, etc.):

1. **Have screenshots** of each stage ready
2. **Pre-run the pipeline** before the session — show the already-completed run
3. **Demo on a local Kubernetes** cluster (kind/minikube) as fallback
4. For GitHub Copilot demos — have pre-recorded GIFs in `/demos/recordings/`

---

## Cleanup After Workshop

```bash
# Remove all Azure resources when done
az group delete --name $RG_NAME --yes --no-wait

echo "Resources scheduled for deletion. This takes ~10 minutes."
```
