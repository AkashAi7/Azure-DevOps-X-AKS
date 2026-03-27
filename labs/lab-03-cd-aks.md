# Lab 03: Deploy to AKS Across Dev → Staging → Production

**Duration:** 30 minutes  
**Module:** Module 3  
**Objective:** Configure Azure DevOps Environments with Kubernetes resources, set up approval gates, run the multi-stage deployment pipeline, and perform a rollback.

---

## Background

```
CI Pipeline (lab-02) completes
         ↓
CD Pipeline triggers automatically
         ↓
Stage 3: DeployDev          → AKS namespace: dev
         ↓ (auto-promote)
Stage 4: IntegrationTestDev → Run API tests vs dev
         ↓ (auto-promote if tests pass)
Stage 5: DeployStaging      → AKS namespace: staging
         ↓ 🔒 MANUAL APPROVAL REQUIRED
Stage 6: DeployProduction   → AKS namespace: production
```

---

## Task 1: Create Azure DevOps Environments

Environments allow you to track deployments, see deployment history, and configure gates.

### Create Dev Environment
1. Go to **Pipelines** → **Environments**
2. Click **New environment**
3. Name: `InventoryAPI-Dev`
4. Resource: **Kubernetes**
5. Select **Azure Kubernetes Service**
6. Subscription: your workshop subscription
7. Cluster: `aks-workshop-01`
8. Namespace: `dev` (select existing)
9. Click **Validate and create**

### Create Staging Environment
Repeat with:
- Name: `InventoryAPI-Staging`
- Namespace: `staging`

**Add a delay gate to staging (5-minute delay after dev deploys):**
1. Open `InventoryAPI-Staging` environment
2. Click `. . .` (ellipsis) → **Approvals and checks**
3. Click **+** → **Exclusive Lock**  
   *(This prevents simultaneous deployments to staging)*
4. Click **+** → **Delay** → set to 5 minutes
5. Save

### Create Production Environment
Repeat with:
- Name: `InventoryAPI-Production`
- Namespace: `production`

**Add manual approval to production:**
1. Open `InventoryAPI-Production` environment
2. Click `. . .` → **Approvals and checks**
3. Click **+** → **Approvals**
4. Approvers: add yourself or your team
5. Instructions: `"Review staging metrics before approving production deploy"`
6. Timeout: 24 hours
7. Click **Create**

---

## Task 2: Import the CD Pipeline

1. Go to **Pipelines** → **New pipeline**
2. Select **Azure Repos Git** → `Fortis-Workshop`
3. Select **Existing Azure Pipelines YAML file**
4. Path: `/pipelines/cd-pipeline.yml`
5. Review the YAML, then **Save** (name it `InventoryAPI-CD`)

**Note:** The CD pipeline uses `trigger: none` — it will be triggered by the CI pipeline, not by git push.

---

## Task 3: Link CI Pipeline to CD Pipeline

Edit `cd-pipeline.yml` — update the pipeline resource name:
```yaml
resources:
  pipelines:
    - pipeline: ci-pipeline
      source: 'InventoryAPI-CI'   # ← must match CI pipeline name exactly
      trigger:
        branches:
          include:
            - main
```

---

## Task 4: Set up ACR Pull Secret on AKS

AKS needs credentials to pull images from ACR. Run this once:

```bash
# Get ACR credentials
ACR_NAME=$(az acr list --resource-group rg-workshop-aks --query "[0].name" -o tsv)
ACR_SERVER="${ACR_NAME}.azurecr.io"
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

# Create pull secret in all 3 namespaces
for NS in dev staging production; do
  kubectl create secret docker-registry acr-pull-secret \
    --docker-server=$ACR_SERVER \
    --docker-username=$ACR_USERNAME \
    --docker-password=$ACR_PASSWORD \
    --namespace=$NS \
    --dry-run=client -o yaml | kubectl apply -f -
  echo "✅ Created acr-pull-secret in namespace: $NS"
done
```

---

## Task 5: Trigger the Full Pipeline

```bash
# Make a code change to trigger CI, which will then trigger CD
cd sample-app/src
# Update the version in the health response by editing app.js
# Change: APP_VERSION = process.env.APP_VERSION || '1.0.0'
# To:     APP_VERSION = process.env.APP_VERSION || '1.1.0-lab03'

git add .
git commit -m "feat: update version for lab-03 deployment"
git push origin main
```

**Watch the pipeline flow:**
1. CI pipeline starts (`InventoryAPI-CI`)
2. After CI Build stage, CD pipeline auto-triggers (`InventoryAPI-CD`)
3. DeployDev runs → watch in Azure DevOps
4. IntegrationTestDev runs
5. DeployStaging runs (after 5-minute delay)
6. DeployProduction **pauses** for your approval

---

## Task 6: Approve the Production Deployment

1. In Azure DevOps, you will see a notification: **"Review deployment to InventoryAPI-Production"**
2. Click the notification or navigate to the pipeline run
3. Click **Review** → **Approve**
4. Add a comment: `"Verified staging is healthy, approving for production"`
5. Click **Approve**

Watch the production deployment complete!

---

## Task 7: Verify the Deployment

```bash
# Check all three namespaces
for NS in dev staging production; do
  echo "=== Namespace: $NS ==="
  kubectl get pods -n $NS
  kubectl get deployments -n $NS
done

# Check that dev has 1 replica, staging 2, production 3
kubectl get deployments --all-namespaces | grep inventory

# Check the full deployment history in Azure DevOps
# Pipelines → Environments → InventoryAPI-Production → Deployments tab
```

---

## Task 8: Simulate a Failed Deployment (Rollback Demo)

```bash
# Edit deployment.yaml to use a non-existent image tag
# This simulates a deployment failure
kubectl set image deployment/inventory-api \
  inventory-api=<acr-name>.azurecr.io/inventory-api:DOES-NOT-EXIST \
  -n production

# Watch the rollout fail
kubectl rollout status deployment/inventory-api -n production
# Expected: error — imagePullBackOff

# Roll it back
kubectl rollout undo deployment/inventory-api -n production

# Verify rollback
kubectl rollout status deployment/inventory-api -n production
kubectl get pods -n production
```

> **Note:** The CD pipeline's `on: failure:` block in the `rolling` strategy does this rollback automatically when a pipeline-triggered deploy fails.

---

## Task 9: Explore Environment Deployment History

1. Go to **Pipelines** → **Environments** → `InventoryAPI-Production`
2. Click the **Deployments** tab
3. See all deployment history with: who deployed, when, which build
4. Click on any deployment to see the logs
5. Note: you can **re-deploy** a previous version from this screen

---

## ✅ Lab 3 Completion Checklist

- [ ] All 3 Environments created in Azure DevOps with Kubernetes resources
- [ ] Staging environment has 5-minute delay gate
- [ ] Production environment has manual approval gate configured
- [ ] ACR pull secret created in all 3 namespaces
- [ ] CD pipeline imported and linked to CI pipeline
- [ ] Full deployment ran: dev → staging → production
- [ ] Production approval completed
- [ ] All 3 namespaces have correct replica counts (1/2/3)
- [ ] Rollback demonstrated via `kubectl rollout undo`

---

## Key Concepts Covered

| Concept | Where |
|---------|-------|
| `environment:` in YAML | cd-pipeline.yml `DeployToDev` job |
| `deployment:` job type | Enables environment tracking |
| `strategy: runOnce` vs `rolling` | Dev/staging vs production |
| Manual approval gate | InventoryAPI-Production environment |
| Delay gate | InventoryAPI-Staging environment |
| `on: failure: rollback` | cd-pipeline.yml production stage |
| `KubernetesManifest@1` | Deploy K8s manifests from pipeline |
| ACR pull secret | Allow AKS to pull from private registry |
