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

## Task 9: Explore Ingress and External Access

Each environment overlay includes an **Ingress** resource that exposes the InventoryAPI externally via an NGINX Ingress Controller.

### 9.1 Verify the Ingress Controller is Running

```bash
# Check that the NGINX Ingress Controller is deployed
kubectl get pods -n ingress-nginx
# Expected: 1-2 pods in Running state

# Get the external IP of the Ingress Controller
kubectl get svc -n ingress-nginx
# Expected: EXTERNAL-IP column shows a public IP or <pending>
```

> If no Ingress Controller exists, the admin will need to install one:
> ```bash
> helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
> helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
> ```

### 9.2 Inspect the Ingress Resources

```bash
# List all Ingress resources across namespaces
kubectl get ingress --all-namespaces
# Expected: one Ingress per environment (dev, staging, production)

# Describe the dev Ingress to see routing rules
kubectl describe ingress inventory-api-ingress -n dev
```

You should see:
- **Host**: `dev.inventory-api.workshop.local`
- **Path**: `/` → routes to `inventory-api` Service on port 80
- **Annotations**: rewrite-target, `ingressClassName: nginx`

### 9.3 Understand the Ingress Differences per Environment

Open the overlay files and compare:

| Environment | Host | TLS | Extra Annotations |
|-------------|------|-----|-------------------|
| **dev** | `dev.inventory-api.workshop.local` | ❌ No | Basic rewrite only |
| **staging** | `staging.inventory-api.workshop.local` | ❌ No | Basic rewrite only |
| **production** | `api.inventory.workshop.io` | ✅ Yes (cert-manager) | Rate limiting, body size limit |

> **Key takeaway:** Production Ingress uses TLS via `cert-manager` and adds rate-limiting annotations. This is a common progressive hardening pattern.

### 9.4 Test the Ingress (via port-forward if no DNS)

If DNS is not configured for the workshop, you can test using port-forward:

```bash
# Port-forward the Ingress Controller to localhost
kubectl port-forward svc/ingress-nginx-controller -n ingress-nginx 8080:80 &

# Test the dev endpoint (pass the Host header manually)
curl -H "Host: dev.inventory-api.workshop.local" http://localhost:8080/health
# Expected: {"status":"healthy","version":"...","environment":"dev"}

# Test the staging endpoint
curl -H "Host: staging.inventory-api.workshop.local" http://localhost:8080/health

# Clean up the port-forward
kill %1
```

---

## Task 10: Create and Use Kubernetes Secrets

Beyond the ACR pull secret, real applications need secrets for API keys, database passwords, and other sensitive configuration.

### 10.1 Create an Application Secret

```bash
# Create a secret with application-level values
kubectl create secret generic inventory-api-secrets \
  --from-literal=DB_CONNECTION_STRING="Server=mydb.database.windows.net;Database=inventorydb" \
  --from-literal=API_KEY="workshop-demo-key-12345" \
  --namespace=dev

# Verify it was created
kubectl get secrets -n dev
# Expected: inventory-api-secrets in the list

# Inspect the secret (values are base64 encoded)
kubectl describe secret inventory-api-secrets -n dev
# Note: values are NOT shown — only key names and byte sizes
```

### 10.2 Understand Secret Types

```bash
# List all secrets in dev namespace with their types
kubectl get secrets -n dev -o custom-columns=NAME:.metadata.name,TYPE:.type
```

| Type | Used For |
|------|----------|
| `Opaque` | Generic key-value secrets (what you just created) |
| `kubernetes.io/dockerconfigjson` | Image pull secrets (acr-pull-secret) |
| `kubernetes.io/tls` | TLS certificates (used by production Ingress) |
| `kubernetes.io/service-account-token` | Auto-generated for ServiceAccounts |

### 10.3 Mount a Secret as Environment Variables

To use the secret in a Deployment, you would add this to the container spec:

```yaml
# Example: mount secret as environment variables
env:
  - name: DB_CONNECTION_STRING
    valueFrom:
      secretKeyRef:
        name: inventory-api-secrets
        key: DB_CONNECTION_STRING
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: inventory-api-secrets
        key: API_KEY
```

> **Key Point:** Secrets in Kubernetes are base64-encoded, **not encrypted** by default. For production clusters, enable **encryption at rest** and consider using **Azure Key Vault Provider for Secrets Store CSI Driver** to sync secrets from Azure Key Vault directly into pods.

### 10.4 Clean Up the Demo Secret

```bash
kubectl delete secret inventory-api-secrets -n dev
```

---

## Task 11: Monitor Your Deployment

The InventoryAPI app includes a built-in Prometheus metrics endpoint at `/metrics`. This task teaches you how to inspect logs and metrics.

### 11.1 View Pod Logs

```bash
# Get the pod name
POD_NAME=$(kubectl get pods -n dev -l app=inventory-api -o jsonpath='{.items[0].metadata.name}')

# View the last 50 lines of logs
kubectl logs $POD_NAME -n dev --tail=50

# Stream logs in real time (Ctrl+C to stop)
kubectl logs $POD_NAME -n dev -f

# View logs from the previous container (useful after a crash restart)
kubectl logs $POD_NAME -n dev --previous
# Expected: error if the pod hasn't restarted — that's normal
```

### 11.2 Check Resource Usage

```bash
# See CPU and memory usage per pod
kubectl top pods -n dev
# Expected: CPU in millicores, memory in Mi

# See resource usage per node
kubectl top nodes

# Check if any pods are being OOMKilled or throttled
kubectl describe pod $POD_NAME -n dev | grep -A5 "State:"
```

> If `kubectl top` shows `error: Metrics API not available`, the admin needs to install the metrics-server:
> ```bash
> kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
> ```

### 11.3 Query the Prometheus Metrics Endpoint

```bash
# Port-forward to the pod directly
kubectl port-forward $POD_NAME 3000:3000 -n dev &

# Fetch the metrics
curl http://localhost:3000/metrics
# Expected: Prometheus-format text output including:
#   http_requests_total{method="GET",route="/health",status_code="200"} 5
#   process_cpu_user_seconds_total
#   nodejs_heap_size_total_bytes

# Clean up
kill %1
```

### 11.4 Inspect Events and Deployment History

```bash
# View recent events in the dev namespace (useful for debugging)
kubectl get events -n dev --sort-by=.metadata.creationTimestamp | tail -20

# View deployment rollout history
kubectl rollout history deployment/inventory-api -n dev

# See details of a specific revision
kubectl rollout history deployment/inventory-api -n dev --revision=1
```

### 11.5 Azure Monitor Quick Check (Optional)

If Azure Monitor for Containers is enabled on the AKS cluster:

1. Go to **Azure Portal** → your AKS cluster → **Insights**
2. Click the **Containers** tab
3. Find `inventory-api` pods across all namespaces
4. Click on a pod → **Live logs** to see real-time log streaming from the portal
5. Click **Metrics** → explore `CPU Usage`, `Memory Working Set`, `Pod Count`

> **Key Point:** Azure Monitor for Containers automatically collects stdout/stderr logs and performance metrics. You do not need to install anything extra in your pods.

---

## ✅ Lab 3 Completion Checklist

- [ ] Azure DevOps Environments created: Dev, Staging, Production
- [ ] Manual approval configured for Production environment
- [ ] CD pipeline imported and linked to CI pipeline
- [ ] ACR pull secret created in all 3 namespaces
- [ ] Full pipeline triggered: CI → CD (dev → staging → production)
- [ ] Production deployment approved manually
- [ ] Deployment verified with `kubectl get pods` across all namespaces
- [ ] Rollback performed and verified
- [ ] Ingress resources inspected across environments
- [ ] Kubernetes Secret created and understood
- [ ] Pod logs and resource usage checked
- [ ] Prometheus `/metrics` endpoint queried
- [ ] Deployment history and events reviewed

---

## Key Kubernetes Concepts Covered

| Concept | Where Used |
|---------|-----------|
| Namespaces | Multi-environment isolation: dev, staging, production |
| Deployments | Rolling updates with maxSurge/maxUnavailable |
| Services (ClusterIP) | Internal networking between pods and Ingress |
| Ingress | External access with host-based routing per environment |
| Ingress TLS | Production uses cert-manager for HTTPS |
| Secrets | Image pull secrets + application secrets |
| ConfigMaps | Environment-specific configuration |
| HPA | Auto-scaling based on CPU/memory (staging + production) |
| PodDisruptionBudget | Production availability during disruptions |
| Resource requests/limits | CPU and memory guardrails per environment |
| Kustomize overlays | Environment-specific overrides |
| Health probes | Liveness, readiness, startup probes |
| `kubectl rollout` | Deployment history, status, undo |
| `kubectl logs` | Container log inspection |
| `kubectl top` | Resource usage monitoring |

---

## 🔧 Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| Pod stuck in `ImagePullBackOff` | ACR pull secret missing or incorrect image tag | Run `kubectl describe pod <name> -n <ns>` and check the Events section. Re-create the pull secret with Task 4 commands |
| Pod stuck in `CrashLoopBackOff` | App is crashing on startup | Check logs: `kubectl logs <pod-name> -n <ns> --previous` |
| Rollout timeout (5 min) | Pod failed readiness probe | Check: `kubectl describe pod <name>` → look at readiness probe events |
| CD pipeline not triggering after CI | Pipeline resource `source` name doesn't match CI pipeline name | Ensure `source: 'InventoryAPI-CI'` matches exactly (case-sensitive) |
| Environment shows "0 resources" | Kubernetes resource not linked during environment creation | Delete environment and re-create with the Kubernetes resource option |
| Approval notification not received | You are not in the approvers list | Go to **Environments → InventoryAPI-Production → Approvals and checks** and add yourself |
| `kubectl top` says "Metrics API not available" | Metrics server not installed on the cluster | Admin: `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml` |
| Ingress returns 404 | Host header doesn't match or Ingress controller not running | Verify with `kubectl get ingress -n <ns>` and check the host value. Ensure `ingress-nginx` pods are running |
| Service shows no endpoints | No pods match the Service's label selector | Check: `kubectl get endpoints inventory-api -n <ns>` — should list pod IPs |
| Port-forward disconnects frequently | Idle timeout or pod restart | Re-run the `kubectl port-forward` command |

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
