# Lab 01: Environment Setup & Azure DevOps Orientation

**Duration:** 20 minutes  
**Module:** Kickoff  
**Objective:** Validate all tools, explore the Azure DevOps project, and understand the workshop environment.

---

## Starting From Scratch? Provision Azure Resources First

> **Skip this section** if a facilitator has already pre-provisioned the cluster and ACR for your team.

If your team has **no existing Azure project, AKS cluster, or namespaces**, run the provisioning script before anything else.  
The script creates: Resource Group → ACR → AKS cluster (with ACR attached) → `dev` / `staging` / `production` namespaces.

### Step 1 — Fill in your values

Open the script for your OS and set these **5 values** at the top before running anything else:

| Variable | What to put | How to find it |
|---|---|---|
| `SubscriptionId` / `SUBSCRIPTION_ID` | Your Azure Subscription ID | `az account show --query id -o tsv` |
| `AksResourceGroup` / `AKS_RESOURCE_GROUP` | Resource group containing your AKS cluster | Azure Portal → your AKS → Resource group field |
| `AksName` / `AKS_NAME` | Your AKS cluster name | Azure Portal → Kubernetes services |
| `AcrName` / `ACR_NAME` | Your ACR name **without** `.azurecr.io` | Azure Portal → Container registries |
| `AzDoOrg` / `AZDO_ORG` | Your Azure DevOps org URL | `https://dev.azure.com/<your-org-name>` |

`AzDoProject` / `AZDO_PROJECT` defaults to `workshop-project` — change it only if you want a different project name.

### Step 2 — Run the script

#### Option A – PowerShell (Windows)

```powershell
# Run from the root of the workshop repo
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\provision-infra.ps1
```

#### Option B – Bash (Linux / macOS / Azure Cloud Shell)

```bash
# Run from the root of the workshop repo
chmod +x scripts/provision-infra.sh
./scripts/provision-infra.sh
```

### What the script sets up for you

| # | What gets created |
|---|---|
| 1 | Connects `kubectl` to your existing AKS cluster |
| 2 | Kubernetes namespaces: `dev`, `staging`, `production` |
| 3 | Azure DevOps project (`workshop-project`) |
| 4 | Variable groups: `InventoryAPI-Common`, `InventoryAPI-Environments` |
| 5 | Boards: 1 Epic → 4 Features → 4 Stories → 14 Tasks + 2 Bugs |
| 6 | Git repo initialised and workshop source pushed |
| 7 | Pipelines imported: CI, CD, MultiEnv |
| 8 | Artifacts feed: `inventory-api-packages` |
| 9 | Test Plan: 2 suites, 10 test cases |

> **Estimated time:** ~3–5 minutes.

### Two manual steps after the script

These require browser consent and cannot be automated:

1. **`InventoryAPI-Secrets` variable group** — go to `Project Settings → Library → + Variable group`, link it to your Key Vault (see [pipelines/variable-groups/README-variable-groups.md](../pipelines/variable-groups/README-variable-groups.md))
2. **AKS service connection** — go to `Project Settings → Service connections → New → Kubernetes`

---

## Prerequisites Check

Run these commands in your terminal to verify your environment:

```bash
# 1. Azure CLI
az --version
# Expected: azure-cli 2.55+

# 2. kubectl
kubectl version --client
# Expected: Client Version: v1.28+

# 3. Docker
docker --version
docker run hello-world
# Expected: "Hello from Docker!"

# 4. Node.js
node --version
npm --version
# Expected: v18+ or v20+

# 5. Git
git --version
# Expected: git version 2.40+
```

If any tool is missing, refer to the [prerequisites install guide](../demos/demo-setup.md).

---

## Task 1: Log in to Azure

```bash
# Log in to Azure CLI
az login

# Set the subscription for this workshop
az account set --subscription "<subscription-id-provided-by-facilitator>"

# Verify
az account show --query "{Name:name, ID:id}" -o table
```

---

## Task 2: Connect to the AKS Cluster

```bash
# Get AKS credentials (ask facilitator for values)
az aks get-credentials \
  --resource-group rg-workshop-aks \
  --name aks-workshop-01 \
  --overwrite-existing

# Verify connection
kubectl get nodes
# Expected: 3 nodes in Ready state

# Check the pre-created namespaces
kubectl get namespaces
# Expected: dev, staging, production namespaces exist
```

---

## Task 3: Explore the Azure DevOps Project

1. Open your browser and navigate to: `https://dev.azure.com/<your-org>/workshop-project`
2. Click through each section in the left navigation:

| Section | What to look for |
|---------|-----------------|
| **Boards** | Open work items, active sprint |
| **Repos** | `Fortis-Workshop` repository with all files |
| **Pipelines** | Pre-imported CI and CD pipelines |
| **Artifacts** | `workshop-packages` feed |
| **Test Plans** | Existing test plan for InventoryAPI |

3. Navigate to **Pipelines → Library** — you should see `InventoryAPI-Common` and `InventoryAPI-Secrets` variable groups already configured.

---

## Task 4: Clone the Repository

```bash
# Clone using Azure Repos URL (get from Repos → Clone)
git clone https://<your-org>@dev.azure.com/<your-org>/workshop-project/_git/Fortis-Workshop

cd Fortis-Workshop

# Install sample app dependencies
cd sample-app
npm install
npm test
# Expected: All tests pass
```

---

## Task 5: Run the App Locally

```bash
cd sample-app
npm start
# Expected: "InventoryAPI v1.0.0 running on port 3000 [local]"

# In a new terminal, test the endpoints:
curl http://localhost:3000/health
# Expected: {"status":"healthy","version":"1.0.0","environment":"local",...}

curl http://localhost:3000/api/products
# Expected: {"count":4,"products":[...]}

curl -X POST http://localhost:3000/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Product","category":"Test","quantity":5,"price":9.99}'
# Expected: 201 Created with the new product

# Stop the server with Ctrl+C
```

---

## Task 6: Run the App with Docker

```bash
cd sample-app

# Build the image
docker build -t inventory-api:local .

# Run the container
docker run -p 3000:3000 \
  -e ENVIRONMENT=local-docker \
  -e APP_VERSION=dev \
  inventory-api:local

# Test it (in another terminal)
curl http://localhost:3000/health
# Verify ENVIRONMENT field shows "local-docker"

# Stop with Ctrl+C
```

---

## ✅ Lab 1 Completion Checklist

- [ ] Azure CLI logged in and subscription set
- [ ] kubectl connected to AKS cluster, can see 3 nodes
- [ ] Explored all 5 Azure DevOps sections
- [ ] Repository cloned and npm tests pass
- [ ] App runs locally (npm start)
- [ ] App runs in Docker container

**Raise your hand if you're stuck — do not skip ahead without completing this lab!**

---

## Bonus (If You Finish Early)
Explore the AKS cluster more:
```bash
# See what's already running on the cluster
kubectl get pods --all-namespaces

# Look at the dev namespace
kubectl describe namespace dev

# Check ACR images (ask facilitator for ACR name)
az acr repository list --name <acr-name> -o table
```
