# Lab 00: Admin Setup for Azure DevOps + AKS

**Audience:** Workshop admin, facilitator, or platform owner  
**When to use:** Before participants join the workshop  
**Estimated time:** 45-90 minutes depending on whether you are greenfield or brownfield  
**Objective:** Prepare the Azure DevOps project and AKS platform so participants can immediately start the hands-on labs.

---

## What This Lab Is For

This lab is **not** for participants. It is the admin pre-work needed to make the workshop usable.

By the end of this lab, you should have:

- An Azure DevOps project ready for the workshop
- An AKS cluster available with `dev`, `staging`, and `production` namespaces
- An ACR available for image publishing
- A Fortis-Workshop repo pushed into Azure Repos
- Core Azure DevOps assets created: variable groups, boards seed data, pipelines, artifacts feed, and test plan
- A short handoff package for participants with the values they need on workshop day

---

## Choose Your Starting Point

Use this decision guide before doing anything else.

| Scenario | Use this section | Typical situation |
|---|---|---|
| **Fully Greenfield** | [Section C](#section-c--fully-greenfield-no-azure-devops-organization-exists) | Nothing exists: no Azure DevOps organization, no AKS cluster, no ACR. Start here at workshop creation time to provision everything end to end |
| **Greenfield** | [Section A](#section-a--greenfield-new-aks--new-azure-devops-project) | Azure DevOps organization already exists but no workshop-ready project or AKS cluster |
| **Brownfield** | [Section B](#section-b--brownfield-existing-aks--existing-or-shared-azure-devops) | AKS and Azure DevOps already exist; only workshop assets need to be onboarded |

If you are unsure, use the brownfield path only when all of the following are already available:

- An AKS cluster exists and is accessible
- An ACR exists and is approved for workshop image pushes
- An Azure DevOps organization already exists
- You know whether you are creating a new project or reusing an existing one

Use **Section C** when starting from absolute zero — no Azure DevOps organization, no Azure resources, no previously provisioned workshop infrastructure.

---

## Required Tools

Run these checks from the repository root before starting either path.

```bash
az --version
kubectl version --client
git --version
node --version
npm --version
```

Install the Azure DevOps CLI extension if needed:

```bash
az extension add --name azure-devops
```

You also need:

- Permissions to create or manage Azure DevOps projects
- Permissions to connect to the target Azure subscription
- Permissions to read or administer the target AKS cluster
- Permissions to manage ACR and Key Vault if you are creating them

---

## Values To Collect Up Front

Prepare these values before proceeding:

| Value | Example | Notes |
|---|---|---|
| Azure subscription ID | `00000000-0000-0000-0000-000000000000` | Use `az account show --query id -o tsv` |
| Azure DevOps org URL | `https://dev.azure.com/contoso` | Org only, no project path |
| Workshop project name | `workshop-project` | New or existing |
| AKS resource group | `rg-workshop-aks` | Required for both paths |
| AKS cluster name | `aks-workshop-01` | Required for both paths |
| ACR name | `workshopacr01` | Do not include `.azurecr.io` |
| Azure region | `eastus` | Needed for greenfield and fully greenfield paths |
| Key Vault name | `kv-workshop-0319` | Needed if you want Key Vault-backed secret variables |
| Azure DevOps org name | `contoso` | Needed for fully greenfield only; becomes `dev.azure.com/contoso` |

---

## Section C: Fully Greenfield — No Azure DevOps Organization Exists

Use this section when you are provisioning the entire workshop environment from scratch at workshop creation time. This includes creating the Azure DevOps organization itself, then building all Azure infrastructure and connecting everything together.

> **Note:** Azure DevOps organization creation is only available through the web portal. The `az devops` CLI requires an org to already exist. Complete C1 manually before running any CLI commands.

### C1. Create the Azure DevOps Organization

1. Sign in to [https://dev.azure.com](https://dev.azure.com) with the account that will own the workshop.
2. Select **New organization** from the left-hand panel.
3. Accept the terms of service and choose an organization name (e.g., `contoso-workshop`).
4. Select the region closest to your participants (affects latency for CI/CD pipelines).
5. Complete the CAPTCHA and select **Continue**.

Your org URL will be: `https://dev.azure.com/<your-org-name>`

Validate via CLI once the org exists:

```bash
az devops configure --defaults organization=https://dev.azure.com/<your-org-name>
az devops project list
```

### C2. Link the Azure DevOps Organization to Your Azure Subscription

This is required for service connections and billing.

1. In your Azure DevOps org, go to **Organization settings -> Billing**.
2. Select **Set up billing**.
3. Choose the Azure subscription that will host the workshop resources.
4. Select **Save**.

Alternatively, link via CLI:

```bash
az devops configure --defaults organization=https://dev.azure.com/<your-org-name>
az account set --subscription <SUBSCRIPTION_ID>
```

### C3. Log In and Set CLI Defaults

```bash
ORG_URL="https://dev.azure.com/<your-org-name>"
SUBSCRIPTION_ID="<your-subscription-id>"

az login
az account set --subscription $SUBSCRIPTION_ID
az devops configure --defaults organization=$ORG_URL
```

Validate:

```bash
az account show --query "{name:name,id:id}" -o table
```

### C4. Create the Azure DevOps Project

```bash
az devops project create \
  --name workshop-project \
  --visibility private \
  --process Agile

az devops configure --defaults project=workshop-project
```

Validate:

```bash
az devops project show --project workshop-project --query "{name:name,state:state}" -o table
```

### C5. Create the Azure Resource Group

```bash
LOCATION="eastus"
RG_NAME="rg-workshop-aks"

az group create \
  --name $RG_NAME \
  --location $LOCATION
```

### C6. Create Azure Container Registry

```bash
ACR_NAME="workshopacr0319"

az acr create \
  --resource-group $RG_NAME \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true
```

Validate:

```bash
az acr show --name $ACR_NAME --query "{name:name,loginServer:loginServer}" -o table
```

### C7. Create the AKS Cluster and Attach ACR

```bash
AKS_CLUSTER="aks-workshop-01"

az aks create \
  --resource-group $RG_NAME \
  --name $AKS_CLUSTER \
  --node-count 3 \
  --node-vm-size Standard_DS2_v2 \
  --enable-managed-identity \
  --attach-acr $ACR_NAME \
  --generate-ssh-keys \
  --kubernetes-version 1.29
```

Validate:

```bash
az aks show \
  --resource-group $RG_NAME \
  --name $AKS_CLUSTER \
  --query "{name:name,powerState:powerState.code,kubernetesVersion:kubernetesVersion}" \
  -o table
```

### C8. Connect kubectl and Create Workshop Namespaces

```bash
az aks get-credentials \
  --resource-group $RG_NAME \
  --name $AKS_CLUSTER \
  --overwrite-existing

kubectl apply -f k8s/base/namespace.yaml
kubectl get namespaces
```

Confirm that `dev`, `staging`, and `production` exist.

### C9. Create Key Vault and Store ACR Secret

```bash
KV_NAME="kv-workshop-0319"

az keyvault create \
  --resource-group $RG_NAME \
  --name $KV_NAME \
  --location $LOCATION

ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

az keyvault secret set \
  --vault-name $KV_NAME \
  --name "acr-admin-password" \
  --value "$ACR_PASSWORD"
```

### C10. Push the Repository into Azure Repos

A default empty repo is created when the project is created. Push the workshop source into it:

```bash
git remote add azure https://<your-org-name>@dev.azure.com/<your-org-name>/workshop-project/_git/Fortis-Workshop
git push azure --all
git push azure --tags
```

If the remote already has commits, initialize with force only on the first push:

```bash
git push azure --all --force
```

### C11. Create Service Connections

Create these from **Project Settings -> Service connections -> New service connection**:

1. **`AzureRM-ServiceConnection`**
   - Type: `Azure Resource Manager`
   - Authentication: `Service principal (automatic)`
   - Scope level: `Subscription`
   - Subscription: select the workshop subscription
   - Grant access permission to all pipelines: enabled

2. **`ACR-ServiceConnection`**
   - Type: `Docker Registry`
   - Registry type: `Azure Container Registry`
   - Select the workshop ACR (`workshopacr0319`)
   - Grant access permission to all pipelines: enabled

3. **`AKS-ServiceConnection`**
   - Type: `Kubernetes`
   - Authentication: `Azure subscription`
   - Target the workshop AKS cluster
   - Namespace: `dev` (environments will handle the others)
   - Grant access permission to all pipelines: enabled

> Tip: After creating `AzureRM-ServiceConnection`, you can create the Kubernetes and Docker connections using the same service principal automatically — Azure DevOps will detect the subscription resources.

### C12. Create Variable Groups

Create under **Pipelines -> Library -> + Variable group**:

#### `InventoryAPI-Common`

| Variable | Example |
|---|---|
| `ACR_NAME` | `workshopacr0319` |
| `ACR_LOGIN_SERVER` | `workshopacr0319.azurecr.io` |
| `AKS_RESOURCE_GROUP` | `rg-workshop-aks` |
| `AKS_CLUSTER_NAME` | `aks-workshop-01` |
| `AZURE_SUBSCRIPTION_ID` | your subscription ID |

#### `InventoryAPI-Environments`

| Variable | Value |
|---|---|
| `K8S_REPLICAS_DEV` | `1` |
| `K8S_REPLICAS_STAGING` | `2` |
| `K8S_REPLICAS_PROD` | `3` |
| `LOG_LEVEL_DEV` | `debug` |
| `LOG_LEVEL_STAGING` | `info` |
| `LOG_LEVEL_PROD` | `warn` |

#### `InventoryAPI-Secrets`

- Link this group to the Key Vault (`kv-workshop-0319`) created in C9.
- Map the `acr-admin-password` secret.

### C13. Import the Pipelines

Import these YAML pipelines from the repo under **Pipelines -> New pipeline -> Azure Repos Git -> Existing YAML file**:

| File | Pipeline name |
|---|---|
| `/pipelines/ci-pipeline.yml` | `InventoryAPI-CI` |
| `/pipelines/cd-pipeline.yml` | `InventoryAPI-CD` |
| `/pipelines/multi-env-pipeline.yml` | `InventoryAPI-MultiEnv` |

### C14. Create Azure DevOps Environments and Map to AKS

Create under **Pipelines -> Environments -> New environment**:

| Environment name | Kubernetes namespace | Recommended check |
|---|---|---|
| `InventoryAPI-Dev` | `dev` | None |
| `InventoryAPI-Staging` | `staging` | Exclusive lock or delay gate |
| `InventoryAPI-Production` | `production` | Manual approval required |

For each environment:
1. Select **Kubernetes** as the resource type.
2. Choose the workshop AKS cluster and the corresponding namespace.
3. Add approval and check policies as indicated above.

### C15. Create ACR Pull Secrets in All Namespaces

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

### C16. Seed the Azure DevOps Project

Run the bootstrap script from the repo root to finish seeding Boards, artifacts, and test plans:

```powershell
# PowerShell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\provision-infra.ps1
```

```bash
# Bash
chmod +x scripts/provision-infra.sh
./scripts/provision-infra.sh
```

Before running, update the configuration block at the top of the script with the `ORG_URL`, `PROJECT_NAME`, subscription ID, AKS cluster name, and ACR name you used in the steps above.

### C17. Full End-to-End Validation

```bash
kubectl get nodes
kubectl get namespaces
az acr repository list --name $ACR_NAME -o table
```

Then:

1. Run `npm install` and `npm test` in `sample-app`
2. Trigger the `InventoryAPI-CI` pipeline manually
3. Confirm an image lands in ACR
4. Trigger `InventoryAPI-MultiEnv`
5. Confirm pods are running in `dev`, `staging`, and `production`
6. Confirm the production approval gate fires and blocks deployment until approved

Once all checks pass, proceed to the [Admin Handoff Checklist](#admin-handoff-checklist).

---

## Section A: Greenfield New AKS + New Azure DevOps Project

Use this section when the workshop environment does not exist yet.

### A1. Create the Azure Resource Group

```bash
LOCATION="eastus"
RG_NAME="rg-workshop-aks"

az login
az group create \
  --name $RG_NAME \
  --location $LOCATION
```

### A2. Create Azure Container Registry

```bash
ACR_NAME="workshopacr0319"

az acr create \
  --resource-group $RG_NAME \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true
```

Validate:

```bash
az acr show --name $ACR_NAME --query "{name:name,loginServer:loginServer}" -o table
```

### A3. Create the AKS Cluster and Attach ACR

```bash
AKS_CLUSTER="aks-workshop-01"

az aks create \
  --resource-group $RG_NAME \
  --name $AKS_CLUSTER \
  --node-count 3 \
  --node-vm-size Standard_DS2_v2 \
  --enable-managed-identity \
  --attach-acr $ACR_NAME \
  --generate-ssh-keys \
  --kubernetes-version 1.29
```

Validate:

```bash
az aks show --resource-group $RG_NAME --name $AKS_CLUSTER --query "{name:name,powerState:powerState.code,kubernetesVersion:kubernetesVersion}" -o table
```

### A4. Connect kubectl and Create Workshop Namespaces

```bash
az aks get-credentials \
  --resource-group $RG_NAME \
  --name $AKS_CLUSTER \
  --overwrite-existing

kubectl apply -f k8s/base/namespace.yaml
kubectl get namespaces
```

Confirm that `dev`, `staging`, and `production` exist.

### A5. Create Key Vault for Secret-Backed Variable Groups

```bash
KV_NAME="kv-workshop-0319"

az keyvault create \
  --resource-group $RG_NAME \
  --name $KV_NAME \
  --location $LOCATION

ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

az keyvault secret set \
  --vault-name $KV_NAME \
  --name "acr-admin-password" \
  --value "$ACR_PASSWORD"
```

### A6. Create the Azure DevOps Project

1. Open your Azure DevOps organization.
2. Select **New project**.
3. Use these values:
   - Name: `workshop-project`
   - Visibility: `Private`
   - Version control: `Git`
   - Work item process: `Agile`

If you prefer CLI, first set the default organization:

```bash
az devops configure --defaults organization=https://dev.azure.com/<your-org>
az devops project create --name workshop-project --visibility private --process Agile
```

### A7. Push This Repository into Azure Repos

```bash
git remote add azure https://<your-org>@dev.azure.com/<your-org>/workshop-project/_git/Fortis-Workshop
git push azure --all
git push azure --tags
```

If the project already contains an empty repo, you can also import the repo from the Azure DevOps UI.

### A8. Create the Core Service Connections

Create these from **Project Settings -> Service connections**:

1. `AzureRM-ServiceConnection`
   - Type: Azure Resource Manager
   - Scope: Subscription
   - Grant access permission to all pipelines: enabled

2. `ACR-ServiceConnection`
   - Type: Docker Registry
   - Registry type: Azure Container Registry
   - Select the workshop ACR
   - Grant access permission to all pipelines: enabled

3. `AKS-ServiceConnection`
   - Type: Kubernetes
   - Target the workshop AKS cluster
   - Namespace can be `dev` initially; environments can be refined later
   - Grant access permission to all pipelines: enabled

### A9. Create Variable Groups

Create or verify these under **Pipelines -> Library**:

#### `InventoryAPI-Common`

| Variable | Example |
|---|---|
| `ACR_NAME` | `workshopacr0319` |
| `ACR_LOGIN_SERVER` | `workshopacr0319.azurecr.io` |
| `AKS_RESOURCE_GROUP` | `rg-workshop-aks` |
| `AKS_CLUSTER_NAME` | `aks-workshop-01` |
| `AZURE_SUBSCRIPTION_ID` | your subscription ID |

#### `InventoryAPI-Environments`

| Variable | Value |
|---|---|
| `K8S_REPLICAS_DEV` | `1` |
| `K8S_REPLICAS_STAGING` | `2` |
| `K8S_REPLICAS_PROD` | `3` |
| `LOG_LEVEL_DEV` | `debug` |
| `LOG_LEVEL_STAGING` | `info` |
| `LOG_LEVEL_PROD` | `warn` |

#### `InventoryAPI-Secrets`

Link this group to Key Vault if you want the workshop to demonstrate secret-backed variables.

### A10. Import the Pipelines

Import these YAML pipelines from the repo:

- `/pipelines/ci-pipeline.yml` -> `InventoryAPI-CI`
- `/pipelines/cd-pipeline.yml` -> `InventoryAPI-CD`
- `/pipelines/multi-env-pipeline.yml` -> `InventoryAPI-MultiEnv`

### A11. Create Azure DevOps Environments

Create these environments and map them to AKS namespaces:

- `InventoryAPI-Dev` -> namespace `dev`
- `InventoryAPI-Staging` -> namespace `staging`
- `InventoryAPI-Production` -> namespace `production`

Recommended checks:

- Add an approval check to production
- Add a delay or exclusive lock to staging

### A12. Create ACR Pull Secrets in All Namespaces

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

### A13. Seed the Azure DevOps Project

If you want the project seeded automatically with Boards items, variable groups, test plans, artifacts, and imported pipelines, use the brownfield bootstrap script after the greenfield infrastructure exists.

Before running it, update the configuration block in one of these files:

- `scripts/provision-infra.ps1`
- `scripts/provision-infra.sh`

Then run the appropriate script from the repo root.

### A14. Do a Full Validation Run

Before the workshop starts, validate the environment end to end.

```bash
kubectl get nodes
kubectl get namespaces
az acr repository list --name $ACR_NAME -o table
```

Then:

1. Run `npm install` and `npm test` in `sample-app`
2. Trigger the CI pipeline once
3. Confirm an image lands in ACR
4. Trigger the multi-environment deployment
5. Confirm pods deploy into `dev`, `staging`, and `production`

---

## Section B: Brownfield Existing AKS + Existing or Shared Azure DevOps

Use this section when AKS and/or Azure DevOps already exist and you only need to onboard the workshop assets.

### B1. Validate the Existing Platform Before You Touch Anything

Confirm these facts with the platform owner or by checking directly:

- Which subscription should be used for the workshop
- Which AKS cluster and namespaces are approved for use
- Which ACR is approved for image publishing
- Whether a new Azure DevOps project should be created or an existing one reused
- Whether service connections already exist and what they are named
- Whether Key Vault-backed variable groups are required or optional

If your brownfield environment does not already contain `dev`, `staging`, and `production` namespaces, you still need to create them.

### B2. Update the Bootstrap Script Configuration

The repository bootstrap scripts are designed for brownfield onboarding and assume AKS already exists.

Edit one of these files and fill in the configuration values at the top:

- `scripts/provision-infra.ps1`
- `scripts/provision-infra.sh`

Required values:

- Subscription ID
- AKS resource group
- AKS cluster name
- ACR name
- Azure DevOps org URL
- Azure DevOps project name

### B3. Run the Bootstrap Script

#### Option A: PowerShell

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\provision-infra.ps1
```

#### Option B: Bash

```bash
chmod +x scripts/provision-infra.sh
./scripts/provision-infra.sh
```

### B4. Understand What the Script Does

The script is intended to set up the workshop inside an existing AKS and Azure DevOps footprint. It performs these actions:

1. Authenticates to Azure and Azure DevOps CLI
2. Connects `kubectl` to the existing AKS cluster
3. Applies the `dev`, `staging`, and `production` namespaces
4. Creates the Azure DevOps project if it does not already exist
5. Creates the `InventoryAPI-Common` and `InventoryAPI-Environments` variable groups
6. Seeds Azure Boards with workshop work items
7. Pushes the workshop source into Azure Repos
8. Imports pipelines
9. Creates the artifacts feed and test plan

### B5. Complete the Manual Steps the Script Cannot Finish Reliably

These steps should always be verified manually in brownfield environments:

1. Create or validate `InventoryAPI-Secrets`
   - Go to **Pipelines -> Library**
   - Link it to the correct Key Vault if you are using Key Vault-backed secrets

2. Validate service connections
   - Confirm `AzureRM-ServiceConnection`
   - Confirm `ACR-ServiceConnection`
   - Confirm or create `AKS-ServiceConnection`

3. Validate Azure DevOps environments
   - `InventoryAPI-Dev`
   - `InventoryAPI-Staging`
   - `InventoryAPI-Production`

4. Validate approvals and checks
   - Staging delay or exclusive lock
   - Production manual approval

### B6. Validate the Existing AKS Integration

```bash
kubectl get nodes
kubectl get namespaces
kubectl get secret -n dev acr-pull-secret
kubectl get secret -n staging acr-pull-secret
kubectl get secret -n production acr-pull-secret
```

If the pull secret does not exist, create it using the commands from [Section A12](#a12-create-acr-pull-secrets-in-all-namespaces).

### B7. Validate the Azure DevOps Project Contents

Before handing the environment to participants, confirm that the project contains:

- Repo: `Fortis-Workshop`
- Pipelines: `InventoryAPI-CI`, `InventoryAPI-CD`, `InventoryAPI-MultiEnv`
- Variable groups: `InventoryAPI-Common`, `InventoryAPI-Environments`, and optionally `InventoryAPI-Secrets`
- Boards seed data
- Artifacts feed
- Test plan

---

## Admin Handoff Checklist

Share these values with participants or facilitators before workshop day:

- Azure subscription ID to use
- Azure DevOps organization URL
- Azure DevOps project URL
- Azure Repos clone URL
- AKS resource group and cluster name
- ACR name
- Any required branch or permission constraints
- Whether participants should have read-only, contributor, or admin access

---

## Workshop-Day Readiness Checklist

- [ ] AKS cluster is reachable and nodes are healthy
- [ ] `dev`, `staging`, and `production` namespaces exist
- [ ] ACR exists and is reachable from the pipelines
- [ ] Azure DevOps project is ready and participants have access
- [ ] Repo is present in Azure Repos
- [ ] CI/CD pipelines are imported
- [ ] Variable groups are present and correct
- [ ] Environments are mapped to the right namespaces
- [ ] ACR pull secret exists in all namespaces
- [ ] A full CI/CD dry run has been completed successfully

---

## Related Guides

- `demos/demo-setup.md` for facilitator-oriented pre-work
- `labs/lab-01-setup.md` for participant onboarding during kickoff