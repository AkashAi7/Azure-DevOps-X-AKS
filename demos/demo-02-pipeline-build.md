# Demo 02: CI/CD Pipeline — Build, Test, Deploy to AKS

**Modules:** 2 + 3 (10:55 AM – 12:30 PM, with break)
**Duration:** Module 2 = 15 min demo, Module 3 = 20 min demo
**Format:** Live pipeline execution + VS Code YAML walkthrough
**Pre-req:** CI pipeline imported, ACR service connection configured, at least one successful CI run

---

## Pre-Stage Checklist (do before the workshop)

### For Module 2 (CI)
- [ ] `InventoryAPI-CI` pipeline imported and named correctly
- [ ] ACR service connection (`ACR-ServiceConnection`) created and tested
- [ ] One successful CI run completed (so you can show test results + ACR image)
- [ ] Have `sample-app/src/app.js` open in a VS Code tab ready to edit
- [ ] Artifacts feed has at least one published package

### For Module 3 (CD)
- [ ] `InventoryAPI-CD` pipeline imported and named correctly
- [ ] Three environments created: `InventoryAPI-Dev`, `InventoryAPI-Staging`, `InventoryAPI-Production`
- [ ] Staging: 5-minute delay gate configured
- [ ] Production: manual approval gate configured (add yourself as approver)
- [ ] ACR pull secrets created in all 3 namespaces
- [ ] One successful end-to-end CD run so you have deployment history to show
- [ ] `kubectl` context set to the workshop AKS cluster

### VS Code Tabs to Pre-Open
1. `pipelines/ci-pipeline.yml`
2. `pipelines/cd-pipeline.yml`
3. `k8s/base/deployment.yaml`
4. `k8s/overlays/dev/deployment-dev.yaml`
5. `k8s/overlays/production/deployment-production.yaml`
6. `sample-app/src/app.js`

---

## MODULE 2 DEMO: CI Pipeline (15 min)

### 2.1 — Walk Through the CI YAML (7 min)

**Open:** `pipelines/ci-pipeline.yml` in VS Code

**Walk top-to-bottom:**

1. **Trigger block** (lines 7-17)
   ```yaml
   trigger:
     branches:
       include: [main, develop, feature/*]
     paths:
       include: [sample-app/**, pipelines/ci-pipeline.yml]
   ```
   > "This pipeline runs when you push to main, develop, or any feature branch —
   > but only if you change the app code or the pipeline YAML itself.
   > No unnecessary runs."

2. **Variables block** (lines 22-35)
   ```yaml
   variables:
     - group: InventoryAPI-Common      # from Azure DevOps Library
     - group: InventoryAPI-Secrets     # linked to Key Vault
     - name: imageName
       value: 'inventory-api'
   ```
   > "Notice two kinds of variables — variable groups (shared, some from Key Vault)
   > and inline values. Secrets NEVER appear in YAML. They're injected at runtime."

3. **Stage 1 — Validate** (the test matrix)
   ```yaml
   strategy:
     matrix:
       Node20:
         nodeVersion: '20'
       Node22:
         nodeVersion: '22'
   ```
   > "This runs our test suite on Node 20 AND Node 22 in parallel.
   > Matrix strategy = same steps, different config. Catches version-specific bugs."

4. **Test publishing tasks**
   > "After tests run, we publish JUnit results and Cobertura coverage.
   > Azure DevOps renders these in the pipeline UI — no external tool needed."

5. **Stage 2 — Build** (Docker + ACR)
   > "If validation passes, we build the Docker image and push to ACR.
   > The Docker@2 task handles login, build, tag, and push in one step.
   > We also publish the image tag as a pipeline artifact — the CD pipeline reads this."

**Talking point:**
> "Key insight: this entire pipeline is ~120 lines of YAML. It's version controlled,
> it goes through PRs, and it's auditable. No click-ops, no magic, no 'it works on my machine.'"

---

### 2.2 — Trigger Live + Show Results (8 min)

**Option A — Trigger a fresh run (if time allows):**

```bash
# In VS Code terminal
cd sample-app/src
# Make a tiny change to app.js — e.g., update version comment
# Line: const APP_VERSION = process.env.APP_VERSION || '1.0.0'
```

1. Edit `app.js` — change version string to `'1.0.1-demo'`
2. Commit and push:
   ```bash
   git add .
   git commit -m "demo: bump version to show CI trigger"
   git push origin main
   ```
3. Switch to Azure DevOps → Pipelines → watch `InventoryAPI-CI` trigger

**Option B — Use the pre-staged run (recommended for time):**

1. Open the last successful CI run

**In either case, walk through:**

1. **Pipeline run overview** — show stages: Validate ✅ → Build ✅
2. **Click Validate stage** → show the matrix jobs (Node 20 ✅, Node 22 ✅)
3. **Click a job** → expand step logs briefly
   - "See each step: install deps, lint, test, publish results"
   - Don't read every log line — just show the structure
4. **Click the Tests tab**
   - "X tests passed, 0 failed — we can see exactly which tests ran"
   - Click into a test to show the detail view
5. **Click Code Coverage tab**
   - Show the percentage: "Our coverage is X%. You can set gates — fail if below 80%."
6. **Verify image in ACR** (terminal):
   ```bash
   az acr repository show-tags --name <acr-name> --repository inventory-api --output table
   ```
   - "There's our image — tagged with the build number"
7. **Show Artifacts feed** (quick — navigate to Artifacts)
   - "The npm package was published too — teams can consume it as a dependency"

**Say:**
> "That's CI. Every push: lint, test on 2 Node versions, build Docker image, push to ACR,
> publish npm package. All automated, all auditable. Now let's deploy it."

---

## ☕ BREAK (11:30 – 11:40)

> **During break:** Verify AKS connectivity: `kubectl get nodes`
> Have the CD pipeline page open and ready.

---

## MODULE 3 DEMO: CD Pipeline — Deploy to AKS (20 min)

### 3.1 — Walk Through K8s Manifests (5 min)

**Open:** `k8s/base/deployment.yaml` in VS Code

> "Our K8s manifests use a base + overlays pattern.
> Base has the shared config — overlays patch per environment."

**Show side-by-side** (or tab switch):

| File | Key Difference |
|------|---------------|
| `k8s/base/deployment.yaml` | 1 replica, resource requests, image placeholder |
| `k8s/overlays/dev/deployment-dev.yaml` | 1 replica, lower resources, `NODE_ENV=development` |
| `k8s/overlays/staging/deployment-staging.yaml` | 2 replicas |
| `k8s/overlays/production/deployment-production.yaml` | 3 replicas, HPA, higher resources |

> "Same app, different muscles. Dev is lightweight for fast iteration.
> Production has 3 replicas, HPA for autoscaling, and higher resource limits."

---

### 3.2 — Walk Through the CD Pipeline YAML (5 min)

**Open:** `pipelines/cd-pipeline.yml` in VS Code

**Key sections to highlight:**

1. **Trigger**
   ```yaml
   trigger: none
   resources:
     pipelines:
       - pipeline: ci-pipeline
         source: 'InventoryAPI-CI'
         trigger:
           branches:
             include: [main]
   ```
   > "CD doesn't trigger on git push — it triggers when CI completes on main.
   > This is pipeline chaining. CI builds and tests. CD deploys."

2. **Stage progression**
   > "Three stages: DeployDev → DeployStaging → DeployProduction.
   > Each uses `dependsOn` and `condition: succeeded()` to chain them."

3. **Environment keyword**
   ```yaml
   environment: 'InventoryAPI-Dev'
   ```
   > "This links the pipeline to the Azure DevOps Environment.
   > Environments give us: deployment history, approval gates, and Kubernetes targeting."

4. **The KubernetesManifest@1 task**
   > "This applies our YAML manifests to the right namespace.
   > It substitutes the image tag so each deploy uses the exact image from CI."

---

### 3.3 — Show Environments UI (3 min)

**Navigate:** Pipelines → Environments

1. **Click `InventoryAPI-Dev`**
   - Show: deployment history (pre-staged runs)
   - "Every deploy is tracked — who, what image, when, success/fail"

2. **Click `InventoryAPI-Staging`**
   - Click ⋮ → Approvals and checks
   - Show the **5-minute delay gate**
   - "Staging won't start until 5 minutes after dev succeeds. This is a soak time — gives you a buffer."

3. **Click `InventoryAPI-Production`**
   - Show the **manual approval gate**
   - "Production requires a human to say 'go'. You set who can approve, timeout, and instructions."

**Say:**
> "Environments are the governance layer. Without changing a line of YAML,
> an admin can add or remove gates. The pipeline author doesn't need to know."

---

### 3.4 — Trigger the CD Pipeline Live (5 min)

**This is the money shot — do this live.**

**Option A — Trigger via CI (if you pushed a commit in Module 2):**
- CD auto-triggers after CI succeeds
- Switch to Pipelines → watch `InventoryAPI-CD` appear

**Option B — Manual trigger:**
1. Go to `InventoryAPI-CD` → **Run pipeline** → Run
2. (This works because the pipeline can be manually triggered too)

**Narrate as stages light up:**

1. **DeployDev starts** — "Now it's deploying to the dev namespace..."
   - Wait for it to go green ✅
   - "Dev is live. Let's verify."

2. **Quick kubectl check** (terminal):
   ```bash
   kubectl get pods -n dev
   # Show: inventory-api pod Running
   
   kubectl logs deployment/inventory-api -n dev --tail=5
   # Show: "Server running on port 3000"
   ```

3. **DeployStaging starts** (after delay gate)
   - "See — it's waiting for the 5-minute delay. In a real pipeline, this soak time
     lets you check dev metrics before promoting."
   - **Don't wait** — say: "We'll come back to this. Let me show you what happens at production."

4. **Show the production approval notification**
   - If staging already completed (from pre-staged run), show the approval prompt
   - Click **Review** → **Approve** → add comment: "Staging verified, deploying to prod"
   - "This is the human-in-the-loop. No one deploys to production without approval."

---

### 3.5 — Verify + Rollback Demo (2 min)

**Verify all three namespaces:**
```bash
# Quick check across all namespaces
for NS in dev staging production; do
  echo "=== $NS ===" 
  kubectl get pods -n $NS -l app=inventory-api --no-headers
done
```

**Live rollback demo:**
```bash
# Simulate a bad deploy — set a non-existent image
kubectl set image deployment/inventory-api \
  inventory-api=fake.azurecr.io/inventory-api:DOES-NOT-EXIST \
  -n dev

# Watch it fail
kubectl get pods -n dev -w
# Expected: ImagePullBackOff after a few seconds
# Press Ctrl+C

# Roll back
kubectl rollout undo deployment/inventory-api -n dev

# Verify recovery
kubectl rollout status deployment/inventory-api -n dev
# Expected: "deployment successfully rolled out"
```

> "That's the safety net. One command and you're back to the previous version.
> In the CD pipeline, this happens automatically if a deploy step fails."

---

## Timing Checkpoints

| Time | You Should Be At |
|------|-----------------|
| 10:55 | Starting CI YAML walkthrough |
| 11:02 | Showing live CI run results |
| 11:10 | Wrapping CI, "Questions before we break?" |
| 11:30 | BREAK |
| 11:40 | Starting K8s manifests walkthrough |
| 11:45 | Walking through CD pipeline YAML |
| 11:50 | Showing Environments UI |
| 11:55 | Triggering CD pipeline live |
| 12:05 | Verify + rollback demo |
| 12:10 | "Your turn!" → Participants start Lab 3 |
| 12:30 | Wrap Lab 3, announce lunch |

---

## Recovery Plays

| If This Happens | Do This |
|-----------------|---------|
| CI pipeline takes too long | Use the pre-staged successful run — just walk through results |
| CD pipeline fails on deploy | Check: service connection, image tag, ACR pull secret. While debugging, walk through the YAML |
| `kubectl` can't reach cluster | Run `az aks get-credentials --resource-group rg-workshop-aks --name aks-workshop-01` |
| Pods stuck in ImagePullBackOff | ACR pull secret missing — create it live (shows debugging) |
| Staging delay feels too long | Say "In production you'd set this to 30 min. We set 5 min for demo speed." |
| Production approval doesn't appear | Check Environments → the approval gate may not be configured |

---

## Key Messages to Land

1. **CI and CD are separate pipelines** — CI builds and tests, CD deploys. Pipeline chaining connects them.
2. **YAML pipelines are auditable** — every change to deployment process goes through a PR.
3. **Environments add governance without changing pipeline code** — admins control gates.
4. **Rollback is one command** — `kubectl rollout undo`. The CD pipeline does this automatically on failure.
5. **Same app, different configs per environment** — base + overlays pattern keeps things DRY.
