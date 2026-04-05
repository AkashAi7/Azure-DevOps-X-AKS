# Workshop Walkthrough Guide
### Azure DevOps → AKS Deployment with GitHub Copilot Agentic DevOps

> **Use this document as a step-by-step companion during the 4-hour workshop.**
> Each section maps to a module in [AGENDA.md](AGENDA.md).

---

## Before You Begin

| Who | What to do | Doc |
|-----|-----------|-----|
| **Admin / Facilitator** | Provision infra & create the Azure DevOps project | [lab-00-admin-setup.md](labs/lab-00-admin-setup.md) |
| **Every Participant** | Install tools & validate access | [lab-01-setup.md](labs/lab-01-setup.md) |

### Pre-Requisites Checklist

```
☐ Azure CLI 2.55+          →  az --version
☐ kubectl 1.28+             →  kubectl version --client
☐ Docker Desktop running    →  docker info
☐ Node.js 20 LTS            →  node -v
☐ Git 2.40+                 →  git --version
☐ VS Code + GitHub Copilot  →  Extensions panel
```

> **Quick install:** Run the dependency script for your OS:
> ```powershell
> # Windows (PowerShell)
> .\scripts\install-dependencies.ps1
>
> # macOS / Linux
> bash scripts/install-dependencies.sh
>
> # Cross-platform (Python 3.9+)
> python scripts/install-dependencies.py
> ```

---

## Phase 0 — Kickoff (20 min)

**Goal:** Everyone is logged in, connected, and understands the architecture.

### Steps

1. **Get the config file** — The facilitator has filled in `workshop.env` with all Azure & Azure DevOps details. Copy it to your repo root.

2. **Run the participant setup script:**
   ```powershell
   # Windows
   .\scripts\participant-setup.ps1

   # macOS / Linux
   bash scripts/participant-setup.sh

   # Python
   python scripts/participant-setup.py
   ```
   The script will:
   - Load config from `workshop.env`
   - Validate all tools are installed
   - Log you into Azure and connect to AKS
   - Verify your namespace access (dev / staging / production)
   - Clone the workshop repo from Azure Repos
   - Run `npm test` to prove the sample app works

3. **Verify you can see:**
   - Azure DevOps Project in the browser (`https://dev.azure.com/<org>/<project>`)
   - AKS namespaces: `kubectl get namespaces`
   - The sample app passes tests: `cd sample-app && npm test`

4. **Review the architecture diagram** in the AGENDA (facilitator will screen-share).

---

## Phase 1 — Azure DevOps Feature Tour (35 min)

**Goal:** Understand the 5 pillars of Azure DevOps.

### What to Watch For (Facilitator Demo)

| Service | Key Concept | What You'll See |
|---------|-------------|-----------------|
| **Boards** | Epics → Features → Stories → Tasks | Sprint board, Kanban, burndown chart |
| **Repos** | Branch policies, PRs, code review | Protected `main` branch, review workflow |
| **Pipelines** | YAML CI/CD, stages, agents | Pipeline editor, run history |
| **Artifacts** | npm / NuGet / Maven feeds | Published packages, upstream sources |
| **Test Plans** | Manual test cases, traceability | Test suites linked to work items |

### Follow Along

1. Open your Azure DevOps Project in the browser.
2. Navigate to **Boards → Backlogs** — notice the pre-created Epics and Stories.
3. Navigate to **Repos** — browse the code, check branch policies on `main`.
4. Navigate to **Pipelines** — you'll set these up in the next phases.
5. Navigate to **Artifacts** — notice the feed is ready for published packages.

---

## Phase 2 — CI Pipeline: Build, Test, Publish (35 min)

**Goal:** Create a working CI pipeline that builds, tests, and publishes on every commit.

### Hands-On Lab → [lab-02-ci-pipeline.md](labs/lab-02-ci-pipeline.md)

### Walkthrough Summary

#### Step 1: Understand the Pipeline YAML

Open [`pipelines/ci-pipeline.yml`](pipelines/ci-pipeline.yml) in VS Code and review:
- **Trigger** — runs on `main` branch commits to `sample-app/` or `pipelines/`
- **Stage 1 — Validate** — runs `npm test` across Node 20 + 22 matrix, publishes test results + coverage
- **Stage 2 — Build** — builds Docker image, pushes to ACR, publishes npm package to Artifacts

#### Step 2: Create the Pipeline in Azure DevOps

1. Go to **Pipelines → New Pipeline → Azure Repos Git**
2. Select your repo → **Existing Azure Pipelines YAML file**
3. Pick `pipelines/ci-pipeline.yml`
4. **Don't run yet** — first set up the ACR service connection

#### Step 3: Create the ACR Service Connection

1. **Project Settings → Service Connections → New → Docker Registry**
2. Type: **Azure Container Registry**
3. Select your subscription and ACR
4. Name it: `acr-service-connection`

#### Step 4: Run the Pipeline

1. Make a small change (e.g., edit a comment in `sample-app/src/app.js`)
2. Commit and push to `main`
3. Watch the pipeline trigger automatically

#### Step 5: Verify Results

- **Pipeline → Tests tab** — see unit test results (pass/fail)
- **Pipeline → Code Coverage tab** — see line/branch coverage
- **ACR** — verify the Docker image was pushed: `az acr repository list --name <acr-name>`
- **Artifacts feed** — verify npm package was published

---

## ☕ Break (10 min)

---

## Phase 3 — CD Pipeline: Deploy to AKS (50 min)

**Goal:** Deploy the containerized app to dev → staging → production with approval gates.

### Hands-On Lab → [lab-03-cd-aks.md](labs/lab-03-cd-aks.md)

### Walkthrough Summary

#### Step 1: Understand the K8s Manifests

```
k8s/
├── base/                    ← shared: namespace, deployment, service, HPA, configmap
│   ├── deployment.yaml      ← 1 replica, image placeholder
│   ├── service.yaml         ← ClusterIP on port 80 → 3000
│   └── hpa.yaml             ← autoscaler (production only)
└── overlays/
    ├── dev/                 ← 1 replica, lowered resources
    ├── staging/             ← 2 replicas
    └── production/          ← 3 replicas + HPA
```

#### Step 2: Create Azure DevOps Environments

For each namespace (`dev`, `staging`, `production`):
1. **Pipelines → Environments → New Environment**
2. Resource type: **Kubernetes**
3. Select your AKS cluster and the matching namespace
4. For **staging** — add a delay gate (e.g., 5 min after dev succeeds)
5. For **production** — add a **manual approval** (assign yourself)

#### Step 3: Import the CD Pipeline

1. Import `pipelines/cd-pipeline.yml` as a new pipeline (or use `multi-env-pipeline.yml` for full flow)
2. Ensure the ACR service connection is referenced correctly

#### Step 4: Deploy and Promote

1. Trigger the pipeline — watch **dev** deploy automatically
2. After dev succeeds, **staging** will wait for the delay gate
3. After staging succeeds, **production** requires your manual approval
4. Approve → watch production deploy with 3 replicas

#### Step 5: Verify Deployments

```bash
# Check pods in each namespace
kubectl get pods -n dev
kubectl get pods -n staging
kubectl get pods -n production

# Test the service
kubectl port-forward svc/inventory-api 8080:80 -n dev
curl http://localhost:8080/health
curl http://localhost:8080/api/products
```

#### Step 6: Practice Rollback

1. Push a "bad" commit (e.g., break the health endpoint)
2. Watch the pipeline deploy to dev
3. Run: `kubectl rollout undo deployment/inventory-api -n dev`
4. Verify the rollback: `kubectl rollout status deployment/inventory-api -n dev`

---

## 🍽️ Lunch Break (60 min)

---

## Phase 4 — Advanced: Security, Policies & Templates (30 min)

**Goal:** Harden the pipeline with secrets management, branch policies, and reusable templates.

### Hands-On Lab → [lab-04-multi-environment.md](labs/lab-04-multi-environment.md)

### Walkthrough Summary

#### 4A: Key Vault Integration

1. Create an Azure Key Vault (or use the pre-provisioned one)
2. Add secrets: `acr-password`, `db-connection-string` (sample values)
3. In Azure DevOps → **Pipelines → Library → Variable Groups**
4. Create a variable group linked to your Key Vault
5. Reference in pipeline YAML:
   ```yaml
   variables:
     - group: InventoryAPI-Secrets  # linked to Key Vault
   ```

#### 4B: Branch Policies

1. **Repos → Branches → ⋮ on `main` → Branch Policies**
2. Enable:
   - ☑ Minimum 1 reviewer
   - ☑ Check for linked work items
   - ☑ Build validation (the CI pipeline must pass)
   - ☑ Squash merge only
3. Test it: create a feature branch, push a change, open a PR — see the policy checks

#### 4C: Pipeline Templates

Review the template structure in [`pipelines/templates/`](pipelines/templates/):
- `build-template.yml` — reusable build + push job
- `deploy-template.yml` — reusable deploy-to-AKS job
- `test-template.yml` — reusable test job

See how `multi-env-pipeline.yml` references these templates with `template:` and `parameters:`.

#### 4D: Azure Test Plans (Quick Tour)

1. **Test Plans → New Test Plan** → name it "Sprint 1 Testing"
2. Create a test suite → add a test case: "Verify /health returns 200"
3. Run the test case manually → mark Pass
4. Link the test case to a User Story in Boards

#### 4E: Dashboard

1. **Overview → Dashboards → New Dashboard**
2. Add widgets: Pipeline status, Test results trend, Work item chart
3. This becomes the team's health-at-a-glance view

---

## Phase 5 — Agentic DevOps with GitHub Copilot (45 min)

**Goal:** Experience AI-assisted DevOps — from code completion to agent mode.

### Hands-On Lab → [lab-05-ghcp-agentic.md](labs/lab-05-ghcp-agentic.md)

### Walkthrough Summary

#### 5A: Copilot Basics in VS Code (10 min)

1. Open `sample-app/src/routes/products.js`
2. Start typing a new route — watch Copilot suggest the full handler
3. Accept with `Tab` — review what it generated

#### 5B: Copilot Chat (10 min)

Open **Copilot Chat** (`Ctrl+Shift+I`) and try these:

| Prompt | What You'll Learn |
|--------|-------------------|
| *"Explain what k8s/base/deployment.yaml does"* | Copilot reads and explains K8s manifests |
| *"What does pipelines/ci-pipeline.yml do step by step?"* | Copilot analyzes pipeline YAML |
| *"Fix this broken YAML: ..."* | Copilot detects and repairs syntax errors |
| *"Generate a liveness probe for a Node.js app on port 3000"* | Copilot generates K8s config snippets |

#### 5C: Copilot in Azure DevOps (5 min — facilitator demo)

Watch the facilitator demonstrate:
- **PR Summaries** — auto-generated pull request descriptions
- **Work Item Assistance** — AI-generated acceptance criteria
- **Pipeline Error Diagnosis** — Copilot explains why a step failed

#### 5D: Agent Mode — The Star of the Show (15 min)

1. Open VS Code → switch to **Agent Mode** (`Ctrl+Shift+I` → Agent)
2. Give it a task:
   > *"Add readiness and liveness probes to all Kubernetes deployments in k8s/. The app serves /health on port 3000. Use appropriate initial delays and periods."*
3. Watch Copilot:
   - **Read** your files
   - **Propose** changes (diff view)
   - **Apply** changes across multiple files
4. Review the diff — accept or reject
5. Try a follow-up:
   > *"Now add a pipeline step that validates K8s manifests with kubeval before deploying"*

#### 5E: Your First Agentic Task (5 min)

Try on your own:
- *"Add a new environment variable `LOG_LEVEL=debug` to the dev overlay deployment"*
- *"Generate a deployment runbook for production releases"*

---

## Phase 6 — Wrap-Up & Challenges (15 min)

### Quick Recap

```
Azure DevOps Services:
  Boards     → Plan and track work
  Repos      → Version control with policies
  Pipelines  → CI/CD automation
  Artifacts  → Package management
  Test Plans → Quality assurance

CI/CD Flow:
  git push → CI (build + test + scan) → CD (dev → staging → prod)

GitHub Copilot:
  Inline completion → Chat → Agent Mode → Azure DevOps Integration
```

### Take-Home Challenges

| # | Challenge | Difficulty | Time | Doc |
|---|-----------|-----------|------|-----|
| 1 | Add security scanning (npm audit + Trivy) to CI | ⭐⭐ | 45-60 min | [challenge-01](challenges/challenge-01-pipeline.md) |
| 2 | Implement blue-green deployment for production | ⭐⭐⭐ | 60-90 min | [challenge-02](challenges/challenge-02-security.md) |
| 3 | Build observability stack with Copilot Agent Mode | ⭐⭐ | 45-60 min | [challenge-03](challenges/challenge-03-agentic.md) |

### Resources

| Resource | Link |
|----------|------|
| Azure DevOps Documentation | [docs.microsoft.com/azure/devops](https://docs.microsoft.com/azure/devops) |
| AKS Best Practices | [docs.microsoft.com/azure/aks/best-practices](https://docs.microsoft.com/azure/aks/best-practices) |
| GitHub Copilot Docs | [docs.github.com/copilot](https://docs.github.com/copilot) |
| Azure DevOps Labs | [azuredevopslabs.com](https://azuredevopslabs.com) |
| GitHub Skills | [skills.github.com](https://skills.github.com) |

---

## Troubleshooting Quick Reference

| Problem | Fix |
|---------|-----|
| `az login` fails | Try `az login --use-device-code` |
| Pipeline can't pull from ACR | Check ACR service connection + `AcrPull` role on AKS identity |
| `kubectl` can't reach cluster | Run `az aks get-credentials --resource-group <rg> --name <cluster>` |
| Pods stuck in `ImagePullBackOff` | ACR login server wrong or image tag mismatch — check `kubectl describe pod <name> -n <ns>` |
| Pipeline waits forever on approval | Check **Environments → Approvals & Checks** — make sure you're an approver |
| Copilot not suggesting | Verify license is active, extension is enabled, and you're signed in |
| `npm test` fails locally | Run `npm install` first, ensure Node 20+ |
| Docker build fails | Ensure Docker Desktop is running — `docker info` |

---

*Happy building! 🚀*
