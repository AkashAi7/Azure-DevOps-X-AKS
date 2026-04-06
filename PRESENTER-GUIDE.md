# Presenter Demo Guide
### Azure DevOps → AKS Deployment Workshop (4 Hours)

> **This is your single-page battle card.** Keep this open on your second monitor during the session.

---

## At a Glance

```
Total: 4 hours (10:00 AM – 3:00 PM IST)
Format: 60% demo/instruction + 40% hands-on labs
Audience: Developers, DevOps Engineers, Platform Engineers
Level: L200 (Azure DevOps + AKS) · L100 (GitHub Copilot)
```

| Time | Module | What You Do | What Participants Do |
|------|--------|-------------|---------------------|
| 10:00 – 10:20 | **Kickoff** | Show architecture, confirm environments | Run `participant-quick-setup.ps1`, verify access |
| 10:20 – 10:55 | **Module 1** | Azure DevOps feature tour (live portal) | Follow along in browser |
| 10:55 – 11:10 | **Module 2 Demo** | CI pipeline YAML walkthrough + live run | Watch |
| 11:10 – 11:30 | **Module 2 Lab** | Float, answer questions | Lab 2: Build first CI pipeline |
| 11:30 – 11:40 | **Break** | Verify AKS connectivity, prep CD demo | Coffee |
| 11:40 – 12:00 | **Module 3 Demo** | K8s manifests + CD pipeline + deploy live | Watch |
| 12:00 – 12:30 | **Module 3 Lab** | Float, answer questions | Lab 3: Deploy to AKS |
| 12:30 – 1:30 | **Lunch** | Rest. Pre-check Module 4/5 resources | Eat |
| 1:30 – 2:00 | **Module 4** | Security, policies, templates, test plans | Lab 4 (embedded exercises) |
| 2:00 – 2:30 | **Module 5 Demo** | GitHub Copilot: inline → chat → agent mode | Follow along in VS Code |
| 2:30 – 2:45 | **Module 5 Lab** | Float | Lab 5: First agentic task |
| 2:45 – 3:00 | **Wrap-up** | Recap, challenges, Q&A, resources | Ask questions |

---

## Pre-Workshop Preparation (2-3 hours, day before)

### Infrastructure

> **Recommended:** Run `scripts/admin-quick-setup.ps1` (or `.sh`) to automate all of the steps below in a single command. See [lab-00-admin-setup.md](labs/lab-00-admin-setup.md) for details. Use `demo-setup.md` only if you prefer manual step-by-step commands.

- [ ] Resource Group, ACR, AKS cluster (3 nodes) provisioned
- [ ] AKS namespaces created: `dev`, `staging`, `production`
- [ ] Key Vault with sample secrets
- [ ] Azure DevOps project with repo imported
- [ ] Service connections: Azure RM + ACR Docker Registry
- [ ] Variable groups: `InventoryAPI-Common` + `InventoryAPI-Secrets` (Key Vault linked)
- [ ] `workshop.env` filled in with all resource names

### Pre-Stage Demo Data (critical — saves 15+ minutes live)

- [ ] **Boards**: 1 Epic ("InventoryAPI v1.0 Release"), 3 User Stories, 2 Tasks, assigned to sprint
- [ ] **Repos**: Feature branch with 1-2 commits, open Pull Request with branch policies triggering
- [ ] **Pipelines**: `InventoryAPI-CI` imported, at least 1 successful run
- [ ] **Pipelines**: `InventoryAPI-CD` imported, 1 full run (dev → staging → prod)
- [ ] **Environments**: `InventoryAPI-Dev`, `InventoryAPI-Staging` (5-min delay), `InventoryAPI-Production` (manual approval, you as approver)
- [ ] **Artifacts**: Feed with at least 1 published npm package
- [ ] **Dashboard**: 3-4 widgets (pipeline status, burndown, test results)
- [ ] **Copilot**: Extension installed and signed in, Chat works, Agent Mode accessible
- [ ] **Broken YAML**: `pipelines/broken-demo.yml` on a scratch branch for /fix demo

### VS Code Tabs to Pre-Open

1. `pipelines/ci-pipeline.yml`
2. `pipelines/cd-pipeline.yml`
3. `k8s/base/deployment.yaml`
4. `k8s/overlays/dev/deployment-dev.yaml`
5. `k8s/overlays/production/deployment-production.yaml`
6. `sample-app/src/routes/products.js`
7. `sample-app/src/app.js`

---

## Module-by-Module Presenter Script

---

### KICKOFF (10:00 – 10:20) — 20 min

**Your goal:** Everyone logged in, architecture understood, energy set.

**Step 1: Open strong**
- Screen-share the architecture diagram (in AGENDA.md)
- "Today you'll build a complete CI/CD pipeline that deploys a containerized app to 3 environments on AKS"
- Quick poll: "Raise your hand if you've used Azure DevOps before? Deployed to AKS?"

**Step 2: Environment check**
- "Open `labs/lab-01-setup.md` and run `participant-quick-setup.ps1` (or `.sh`)"
- Give them 5 minutes. Walk around / check chat for issues
- Common fix: `az login --use-device-code` if login fails

**Step 3: Confirm success criteria**
- They can see the Azure DevOps project in browser
- `kubectl get namespaces` shows dev/staging/production
- `cd sample-app && npm test` passes

**Transition line:**
> "Everyone's connected? Great. Let's start with a tour of everything Azure DevOps gives you."

---

### MODULE 1: Azure DevOps Tour (10:20 – 10:55) — 35 min

**Your goal:** Participants understand all 5 pillars, not just Pipelines.

**Open:** `https://dev.azure.com/<your-org>/workshop-project`

#### Boards (8 min) — Navigate: Boards → Backlogs
1. Show Epic → User Stories hierarchy
2. Switch to Sprint board → drag a task across columns live
3. Switch to Kanban board → point out WIP limits
4. Quick-create a work item: `Add /metrics endpoint for Prometheus`
5. Show the pre-built Dashboard (Overview → Dashboards)

**Say:** "Boards integrates with everything. PRs auto-close work items. Pipeline failures create bugs."

#### Repos (8 min) — Navigate: Repos → Files
1. Browse `sample-app/src/app.js`, `pipelines/ci-pipeline.yml`, `k8s/base/deployment.yaml`
2. Show branch policies on `main` (Repos → Branches → ⋮ → Branch policies)
3. Open the pre-created Pull Request → show inline diff, policies section, add a review comment

**Say:** "Branch policies + PR reviews = quality gates. Nobody bypasses the process."

#### Pipelines (8 min) — Navigate: Pipelines → Pipelines
1. Show pipeline list: CI and CD
2. Click into a completed CI run → show stages, matrix (Node 20/22)
3. Click Tests tab → show pass/fail, Code Coverage tab → show percentage
4. Click "View YAML" → "Everything is YAML — version controlled, auditable"

#### Artifacts (5 min) — Navigate: Artifacts
1. Show the feed with published npm package
2. Click the package → show versions, install command
3. Click Upstream Sources → explain proxy caching

**Say:** "Artifacts is your private package registry. Enterprise orgs route all deps through controlled feeds."

#### Test Plans (3 min) — Navigate: Test Plans
1. Quick overview — "Manual and exploratory testing, linked to work items"
2. "We'll create a quick test plan in Module 4"

**Timing checkpoint:** You should finish by 10:55.

**Transition line:**
> "That's the full platform. Now let's build a real pipeline. This is where it gets fun."

---

### MODULE 2: CI Pipeline (10:55 – 11:30) — 35 min

**Your goal:** Participants understand CI YAML structure and can build their own pipeline.

#### Demo (15 min)

**Part A — YAML Walkthrough (7 min)**
Open `pipelines/ci-pipeline.yml` in VS Code, walk top-to-bottom:

| Section | What to say |
|---------|-------------|
| **Trigger** | "Runs on push to main/develop/feature — but only if app code or pipeline YAML changes" |
| **Variables** | "Two variable groups (one from Key Vault). Secrets NEVER in YAML." |
| **Stage 1 — Validate** | "Matrix strategy: same tests, Node 20 AND 22 in parallel. Catches version bugs." |
| **Test publishing** | "JUnit + Cobertura results published — Azure DevOps renders in the UI" |
| **Stage 2 — Build** | "Docker@2 handles login, build, tag, push to ACR. One task does it all." |

**Key line:** "This entire pipeline is ~120 lines of YAML. Version controlled. Auditable. No click-ops."

**Part B — Show Results (8 min)**
- Open the pre-staged successful CI run (or trigger a fresh one if time allows)
- Walk through: Stages view → Matrix jobs → Tests tab → Code Coverage tab
- Verify image in ACR: `az acr repository show-tags --name <acr> --repository inventory-api -o table`
- Quick look at Artifacts feed

**Transition line:**
> "That's CI. Every push: test on 2 Node versions, build Docker image, push to ACR, publish package. Your turn!"

#### Lab (20 min)
- "Open `labs/lab-02-ci-pipeline.md` and follow the steps"
- Float the room. Common issues:
  - ACR service connection not created → guide them through Project Settings → Service Connections
  - Pipeline YAML path wrong → must be `pipelines/ci-pipeline.yml`
  - Tests fail → `npm install` first

---

### BREAK (11:30 – 11:40)

**While they're away:**
- Run `kubectl get nodes` to verify AKS connectivity
- Have the CD pipeline page open in browser
- Have `k8s/base/deployment.yaml` open in VS Code

---

### MODULE 3: CD Pipeline — Deploy to AKS (11:40 – 12:30) — 50 min

**Your goal:** Participants deploy to 3 environments with approval gates.

#### Demo (20 min)

**Part A — K8s Manifests (5 min)**
Show side-by-side in VS Code:

| File | Key difference |
|------|---------------|
| `k8s/base/deployment.yaml` | 1 replica, image placeholder |
| `k8s/overlays/dev/` | 1 replica, low resources, `NODE_ENV=development` |
| `k8s/overlays/staging/` | 2 replicas |
| `k8s/overlays/production/` | 3 replicas, HPA, higher resources |

**Say:** "Same app, different muscles. Dev is lightweight. Production has autoscaling."

**Part B — CD Pipeline YAML (5 min)**
Open `pipelines/cd-pipeline.yml`:
- Trigger: `trigger: none` → triggers when CI completes (pipeline chaining)
- Three stages: DeployDev → DeployStaging → DeployProduction
- `environment:` keyword links to Azure DevOps Environments
- `KubernetesManifest@1` applies YAML to the right namespace

**Part C — Environments UI (3 min)**
Navigate: Pipelines → Environments
- Show `InventoryAPI-Dev` → deployment history
- Show `InventoryAPI-Staging` → 5-min delay gate
- Show `InventoryAPI-Production` → manual approval

**Say:** "Environments are the governance layer. Admins control gates without changing YAML."

**Part D — Trigger CD Pipeline Live (5 min) — THE MONEY SHOT**
1. Manually run `InventoryAPI-CD` (or let it auto-trigger)
2. Narrate as stages light up: "Dev is deploying..."
3. Quick kubectl check: `kubectl get pods -n dev`
4. Show staging waiting for delay gate
5. Show production approval prompt → Approve with comment

**Part E — Rollback Demo (2 min)**
```bash
# Break it on purpose
kubectl set image deployment/inventory-api inventory-api=fake.azurecr.io/inventory-api:NOPE -n dev
# Watch it fail
kubectl get pods -n dev -w
# Roll back
kubectl rollout undo deployment/inventory-api -n dev
kubectl rollout status deployment/inventory-api -n dev
```

**Say:** "One command — back to previous version. That's the safety net."

#### Lab (30 min)
- "Open `labs/lab-03-cd-aks.md`"
- Common issues:
  - Pods in `ImagePullBackOff` → ACR pull secret missing or image tag mismatch
  - Pipeline waits forever → check Environments → Approvals & Checks
  - `kubectl` can't reach cluster → `az aks get-credentials --resource-group <rg> --name <cluster>`

---

### LUNCH (12:30 – 1:30)

**While they eat:** Verify Module 4/5 resources. Open Key Vault in portal. Test Copilot is still signed in.

---

### MODULE 4: Security, Policies & Templates (1:30 – 2:00) — 30 min

**Your goal:** Harden the pipeline. Show enterprise-grade practices.

| Topic | Time | Key action |
|-------|------|------------|
| **Key Vault integration** | 8 min | Show variable group linked to Key Vault. "Secrets are injected at runtime — NEVER in YAML." |
| **Branch policies** | 7 min | Show: min reviewers, build validation, linked work items, squash merge. "Nobody pushes to main." |
| **Pipeline templates** | 8 min | Open `pipelines/templates/` → show how `multi-env-pipeline.yml` references templates. "DRY pipelines." |
| **Test Plans quick tour** | 4 min | Create a test plan, add a test case, run it, link to a User Story. |
| **Dashboard** | 3 min | Add widgets: pipeline status, test trend, work item chart. "Executive health-at-a-glance." |

**Lab 4 exercises are embedded** — participants do quick tasks between demos.
Reference: `labs/lab-04-multi-environment.md`

**Transition line:**
> "Your pipelines are now secure, templated, and governed. Let's add AI superpowers."

---

### MODULE 5: GitHub Copilot Agentic DevOps (2:00 – 2:45) — 45 min

**Your goal:** Blow their minds with Agent Mode. This is what they'll talk about after the workshop.

#### 5.1 — Quick Intro (3 min, slides only)

| Mode | What it does |
|------|-------------|
| **Inline completion** | Suggests code as you type. Tab to accept. |
| **Chat** | Ask questions, explain code, generate snippets. |
| **Agent Mode** | Multi-step task execution. Reads workspace, plans, edits files. |

**Say:** "For DevOps, the killer use case is YAML. Nobody memorizes pipeline syntax. Copilot does."

#### 5.2 — Inline Completion (5 min)

1. Open `sample-app/src/routes/products.js`
2. Type at end of file: `// DELETE endpoint to remove a product by ID`
3. Press Enter, type `router.delete` → wait for ghost text → Tab to accept
4. Open `Dockerfile` → type `# Add a healthcheck` → accept suggestion

**Say:** "It read the existing routes and generated a matching handler. One Tab."

#### 5.3 — Copilot Chat (10 min) — `Ctrl+Shift+I`

| Demo | Prompt | Point to make |
|------|--------|---------------|
| **Explain K8s** | `Explain what this Kubernetes deployment does` (with `deployment.yaml` open) | "New team members onboard without a 2-hour walkthrough" |
| **Explain pipeline** | `What does this CI pipeline do step by step?` (with `ci-pipeline.yml` open) | "120-line pipeline summarized in 5 seconds" |
| **Generate code** | `Generate a K8s liveness probe for Node.js on port 3000` | "No Googling, no Stack Overflow — production-ready YAML" |
| **Fix broken YAML** | Open `broken-demo.yml`, select all, ask `Fix the YAML errors` | "It found 3 errors and explained each one" |

**Engagement:** "Who wants to suggest a prompt? What should we ask Copilot?"

#### 5.4 — Copilot in Azure DevOps (5 min)

- Show PR "Summarize with Copilot" button (if available)
- Show work item "Fill with Copilot" (if available)
- Paste a pipeline error into Chat → get diagnosis

> Skip if Azure DevOps Copilot features aren't available — spend more time on Agent Mode.

#### 5.5 — Agent Mode: THE STAR (7 min)

**Open Chat → switch to Agent Mode dropdown**

**Demo 1 — Multi-file K8s changes:**
> `Add readiness and liveness probes to all Kubernetes deployments in k8s/. The app serves /health on port 3000. Use initialDelaySeconds: 10, periodSeconds: 15, failureThreshold: 3.`

Narrate as it works:
- "It's reading the files... planning changes... showing the diff..."
- Show the diff view → Accept

**Demo 2 — Generate a pipeline step:**
> `Now add a pipeline step to CI that validates K8s manifests with kubeval before the Build stage.`

**Demo 3 (if time) — Generate a runbook:**
> `Generate a production deployment runbook based on our k8s/ manifests and cd-pipeline.yml.`

**Key line:** "Two prompts. Multi-file changes. AI-assisted, not AI-replaced. Always review the diff."

#### Lab 5 (15 min)
- "Open `labs/lab-05-ghcp-agentic.md`"
- Participants try their own Agent Mode prompts

---

### WRAP-UP (2:45 – 3:00) — 15 min

**Recap (5 min):**
```
Azure DevOps = Boards + Repos + Pipelines + Artifacts + Test Plans
CI/CD Flow   = git push → build → test → scan → deploy (dev → staging → prod)
Copilot      = Inline → Chat → Agent Mode → Azure DevOps integration  
```

**Challenges (5 min):**

| # | Challenge | Difficulty | Doc |
|---|-----------|-----------|-----|
| 1 | Add security scanning (Trivy + npm audit) to CI | ⭐⭐ | `challenges/challenge-01-pipeline.md` |
| 2 | Implement blue-green deployment for production | ⭐⭐⭐ | `challenges/challenge-02-security.md` |
| 3 | Build observability stack with Copilot Agent Mode | ⭐⭐ | `challenges/challenge-03-agentic.md` |

**Q&A (5 min):**
- Open the floor
- End with: "The repo is yours. Keep experimenting. The challenges are there for when you're ready."

---

## Recovery Playbook

| Problem | Quick Fix |
|---------|-----------|
| Boards empty (forgot to pre-stage) | Create 1 Epic + 1 Story live — 2 min |
| CI pipeline slow | Use pre-staged successful run, walk through results |
| CD pipeline fails | Check: service connection, image tag, ACR pull secret. Debug live — it's a teaching moment |
| Pods in `ImagePullBackOff` | ACR pull secret missing → `kubectl describe pod <name> -n <ns>` to diagnose |
| `kubectl` can't reach cluster | `az aks get-credentials --resource-group <rg> --name <cluster>` |
| Staging delay too long | "In prod you'd set 30 min. We set 5 min for demo speed." |
| Production approval missing | Check Environments → Approvals & Checks |
| Copilot won't suggest | Extension installed? Signed in? File not in `.gitignore`? |
| Copilot Chat slow | "It's reading all workspace files — thinking hard for us" |
| Agent Mode makes wrong change | **Great teaching moment:** "Always review the diff. AI-assisted, not AI-replaced." |
| Copilot completely down | Use cached screenshots/GIFs. Focus more on AzDO demos |
| Artifacts feed empty | Show CLI: `az artifacts feed list`, explain what would be published |
| `npm test` fails | `npm install` first, confirm Node 20+ |

---

## Presenter Energy Tips

| When | Do |
|------|-----|
| Opening | Start energetic. Quick poll. Set the pace. |
| After Boards demo | Pause — "Any questions before we move to Repos?" |
| Before Lab 2 | "This is YOUR time. Try things. Break things. I'm here to help." |
| After lunch | Re-energize: "Who's ready for the best part? AI-powered DevOps." |
| Agent Mode | Build suspense: "Watch this..." — let the room react to the magic |
| Wrap-up | End confident: "You now have a production-grade DevOps pipeline. Go build." |

---

## Critical Timing Checkpoints

| Time | You MUST be at |
|------|---------------|
| 10:20 AM | Kickoff done. Starting Module 1. |
| 10:55 AM | Module 1 done. Starting CI demo. |
| 11:10 AM | CI demo done. Participants start Lab 2. |
| 11:30 AM | Lab 2 wrapped. BREAK. |
| 11:40 AM | Starting CD demo. |
| 12:10 PM | CD demo done. Participants start Lab 3. |
| 12:30 PM | Lab 3 wrapped. LUNCH. |
| 1:30 PM | Starting Module 4. |
| 2:00 PM | Module 4 done. Starting Copilot demos. |
| 2:30 PM | Copilot demos done. Participants start Lab 5. |
| 2:45 PM | Lab 5 done. Starting wrap-up. |
| 3:00 PM | Done. |

---

## Key Reference Files

| File | What it's for |
|------|---------------|
| [AGENDA.md](AGENDA.md) | Full module details + facilitator notes |
| [WALKTHROUGH.md](WALKTHROUGH.md) | Step-by-step participant companion |
| [PPT-CONTENT.md](PPT-CONTENT.md) | Slide-by-slide content for your deck |
| [demos/demo-setup.md](demos/demo-setup.md) | Pre-provision infrastructure commands |
| [demos/demo-01-azure-devops-tour.md](demos/demo-01-azure-devops-tour.md) | Module 1 detailed script |
| [demos/demo-02-pipeline-build.md](demos/demo-02-pipeline-build.md) | Module 2+3 detailed script |
| [demos/demo-03-ghcp-devops.md](demos/demo-03-ghcp-devops.md) | Module 5 detailed script |
| [workshop.env](workshop.env) | Resource names and config |

---

*You've got this. Stay on time, keep it live, let the demos speak. Good luck!*
