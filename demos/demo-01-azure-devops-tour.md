# Demo 01: Azure DevOps — Full Feature Tour

**Module:** 1 (10:20 – 10:55 AM)
**Duration:** 35 minutes
**Format:** Facilitator-led, live in Azure DevOps portal
**Pre-req:** `demo-setup.md` completed — project exists with repo, pipelines, and boards

---

## Pre-Stage Checklist (do before the workshop)

- [ ] Create at least 1 Epic, 3 User Stories, and 2 Tasks in Boards
- [ ] Assign stories to a sprint with capacity set
- [ ] Create a feature branch with 1-2 commits
- [ ] Open (but don't complete) a Pull Request with branch policies triggering
- [ ] Run the CI pipeline at least once so Artifacts feed has a package
- [ ] Build a basic Dashboard with 3-4 widgets

> **Why pre-stage:** Creating work items and waiting for pipeline runs eats time.
> Pre-stage the data, then just narrate and click through it live.

---

## Demo Flow

### 1.1 — Azure DevOps Overview (5 min)

**Open:** `https://dev.azure.com/<your-org>/workshop-project`

**Talk through:**
- Point at the left sidebar — "These 5 icons are the 5 pillars of Azure DevOps"
- Click each icon briefly: Boards, Repos, Pipelines, Test Plans, Artifacts
- "Everything lives under one project — code, builds, deploys, work tracking, packages"

**Say:**
> "Azure DevOps is not just a CI/CD tool — it's a complete DevOps platform.
> Many people only know Pipelines, but Boards, Repos, Artifacts, and Test Plans
> are equally powerful. We'll tour each one now."

**Comparison slide moment:**
> "If you're wondering how this compares to GitHub — Azure DevOps is stronger
> for enterprise governance, while GitHub is stronger for open-source and
> developer experience. Many orgs use both. We'll use Azure DevOps today
> because our target is a regulated AKS deployment."

---

### 1.2 — Azure Boards (8 min)

**Navigate:** Boards → Backlogs

**Step-by-step:**

1. **Show the backlog view**
   - Point out: Epic → User Stories hierarchy
   - "This is where your product owner plans the sprint"

2. **Click into the pre-created Epic:** "InventoryAPI v1.0 Release"
   - Show child User Stories linked underneath
   - "Each story can have tasks, acceptance criteria, and be linked to PRs"

3. **Switch to Sprint board** (Boards → Sprints)
   - Show the Taskboard with columns: New, Active, Resolved, Closed
   - Drag a task across columns live: "This is how developers update status"

4. **Switch to Kanban board** (Boards → Boards)
   - "Product managers love this view — swimlanes, WIP limits, card styles"
   - Point out the WIP limit indicator

5. **Quick create a work item live:**
   - Click **+ New Work Item** on the Kanban board
   - Title: `Add /metrics endpoint for Prometheus`
   - "Notice how fast this is — no forms, just type and go"

6. **Show the pre-built Dashboard** (Overview → Dashboards)
   - Point at widgets: burndown chart, pipeline status, test results
   - "Executives love dashboards — one glance tells you project health"

**Talking point:**
> "Boards integrates with everything else. When you complete a PR, work items
> auto-close. When a pipeline fails, you can create a bug from the failure.
> It's all connected."

---

### 1.3 — Azure Repos (8 min)

**Navigate:** Repos → Files

**Step-by-step:**

1. **Browse the repo**
   - Open `sample-app/src/app.js` — "This is our sample app, simple Node.js API"
   - Open `pipelines/ci-pipeline.yml` — "All pipeline config is YAML, version controlled"
   - Open `k8s/base/deployment.yaml` — "K8s manifests live alongside the code"

2. **Show branch policies** (Repos → Branches → ⋮ on `main` → Branch policies)
   - Point at each policy: "Min reviewers, linked work items, build validation"
   - "This means nobody can push directly to main — everything goes through a PR"
   - **This is a security feature — highlight it**

3. **Open the pre-created Pull Request** (Repos → Pull Requests)
   - Show the PR: files changed tab, inline diff
   - Scroll to the **Policies** section: show build validation running/passed
   - Show the reviewer requirement
   - Click **Add a comment** on a code line: "See — inline code review right here"
   - Type: `Consider adding input validation for product IDs` → Post
   - "PR comments become discussion threads. Nothing gets lost."

4. **Show "Suggest changes"** (if PR is open)
   - Click the **Suggest** button on a line
   - "This is like GitHub's suggested changes — the author can accept with one click"

**Talking point:**
> "Branch policies + PR reviews = quality gates before code hits main.
> Combined with build validation, you can't merge unless CI passes.
> This is trunk-based development with guardrails."

---

### 1.4 — Azure Pipelines (8 min — overview only)

**Navigate:** Pipelines → Pipelines

**Step-by-step:**

1. **Show the pipeline list**
   - Point at `InventoryAPI-CI` and `InventoryAPI-CD`
   - "CI triggers on push, CD triggers when CI succeeds. We'll build these in Modules 2 and 3."

2. **Click into a completed CI run** (pre-staged from before)
   - Show the **stages view**: Validate → Build
   - Click into the Validate stage → show the matrix (Node 20 / Node 22)
   - "See — it ran the same tests on two Node versions in parallel"

3. **Click the Tests tab**
   - Show: X tests passed, 0 failed
   - "Test results are published directly into the pipeline UI — no external tool needed"

4. **Click the Code Coverage tab**
   - Show the line/branch coverage percentage
   - "You can set a threshold — fail the pipeline if coverage drops below 80%"

5. **Show the YAML tab** (click "…" → View YAML)
   - "Everything is YAML — version controlled, reviewable in PRs, no click-ops"

**Talking point:**
> "We'll go deep into CI in the next module. For now, the key insight is:
> YAML pipelines are code. They live in the repo. They go through PRs.
> Your pipeline IS your deployment process, documented and auditable."

---

### 1.5 — Azure Artifacts (5 min)

**Navigate:** Artifacts

**Step-by-step:**

1. **Click the Artifacts feed** (pre-created: `workshop-feed` or `InventoryAPI`)
   - Show the published npm package from the CI run
   - "This is our private npm registry — the CI pipeline publishes here automatically"

2. **Click the package** → show versions
   - "See the version history — every CI run publishes a new version"
   - Show the **Install** command: `npm install @workshop/inventory-api`

3. **Click Upstream Sources** (Feed settings → Upstream sources)
   - "Upstream sources proxy npmjs.com through your feed — one `npm install` hits your feed first,
      then falls through to the public registry. This gives you caching and auditability."

**Talking point:**
> "Artifacts is often overlooked. It's your private package registry.
> In enterprise orgs, you want all dependencies flowing through a controlled feed —
> not everyone downloading directly from npmjs.com."

---

### 1.6 — Azure Test Plans (3 min)

**Navigate:** Test Plans

**Step-by-step:**

1. **Quick overview** — don't go deep, just show the page exists
   - "Test Plans is for manual and exploratory testing"
   - Show a pre-created test plan if you have one, or just show the empty UI

2. **Key point to mention:**
   - "You can create test cases linked to User Stories"
   - "When the pipeline runs tests, results appear here too"
   - "The Test & Feedback browser extension lets testers do exploratory testing and auto-file bugs"

**Say:**
> "We won't spend much time here today — the focus is CI/CD.
> But know that Test Plans closes the loop between code and QA.
> We'll create a quick test plan in Module 4."

---

## Timing Checkpoints

| Time | You Should Be At |
|------|-----------------|
| 10:25 | Starting Boards demo |
| 10:33 | Starting Repos demo |
| 10:41 | Starting Pipelines overview |
| 10:49 | Starting Artifacts demo |
| 10:54 | Wrapping up Test Plans |
| 10:55 | "Let's build a real pipeline!" → Module 2 |

---

## Recovery Plays

| If This Happens | Do This |
|-----------------|---------|
| Boards is empty (forgot to pre-stage) | Create one Epic + one Story live — takes 2 min, fills the gap |
| PR build validation takes too long | Say "It's running in the background" and move to the next demo |
| Artifacts feed is empty | Show the CLI: `az artifacts feed list` and explain what would be published |
| Test Plans license missing | Just show the page, explain the concept, move on |

---

## Key Messages to Land

1. **Azure DevOps is 5 services, not just Pipelines**
2. **Branch policies enforce quality — no one bypasses the PR process**
3. **Everything connects — work items to PRs to pipelines to deployments**
4. **YAML pipelines are code — version controlled and auditable**
5. **Artifacts gives you a controlled, auditable package supply chain**
