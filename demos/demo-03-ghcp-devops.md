# Demo 03: Agentic DevOps with GitHub Copilot

**Module:** 5 (2:00 – 2:45 PM)
**Duration:** 30 min demo + 15 min lab
**Format:** Live VS Code + Azure DevOps, audience follows along for some parts
**Pre-req:** GitHub Copilot extension installed, signed in, and working in VS Code

---

## Pre-Stage Checklist (do before the workshop)

- [ ] VS Code has GitHub Copilot + GitHub Copilot Chat extensions installed and signed in
- [ ] Copilot Chat panel opens without errors (`Ctrl+Shift+I`)
- [ ] Agent Mode is accessible (Chat panel → mode dropdown → "Agent")
- [ ] Open a PR in Azure DevOps that has "Summarize with Copilot" enabled
- [ ] Have a pre-failed pipeline run to show error diagnosis (optional — break a YAML on purpose)
- [ ] Prepare a broken YAML file in a scratch branch for the /fix demo

### VS Code Tabs to Pre-Open
1. `sample-app/src/routes/products.js` (for inline completion demo)
2. `k8s/base/deployment.yaml` (for Chat explain demo)
3. `pipelines/ci-pipeline.yml` (for Chat explain demo)
4. An empty file: `pipelines/scratch-pipeline.yml` (for generation demo)

### Broken YAML (create in advance)

Create a file `pipelines/broken-demo.yml` in a scratch branch with deliberate errors:

```yaml
# Intentionally broken pipeline for Copilot /fix demo
trigger:
  branches:
    include
      - main         # missing colon after 'include'

pool:
  vmImage: 'ubuntu-latest'

steps:
  - script: |
      echo "Building..."
    displayName: Build Step
  - task: Docker@2
    inputs:
      command: buildAndPush
      repository: inventory-api
       containerRegistry: 'ACR-ServiceConnection'   # bad indentation
      dockerfile: sample-app/Dockerfile
    tags:
      - $(Build.BuildId)         # 'tags' should be inside inputs
```

---

## Demo Flow

### 5.1 — What is GitHub Copilot? (3 min — slides, not live)

**Just talk, no demo yet:**

> "GitHub Copilot is an AI coding assistant built into your editor.
> It has three modes you'll see today:"

| Mode | What it does |
|------|-------------|
| **Inline completion** | Suggests code as you type. Tab to accept. |
| **Chat** | Ask questions, explain code, generate snippets. Like a senior colleague. |
| **Agent Mode** | Multi-step task execution. Reads your workspace, plans changes, edits files. |

> "For DevOps, the killer use case is YAML. Nobody memorizes pipeline syntax.
> Copilot does. Let me show you."

---

### 5.2 — Inline Completion Demo (5 min)

**Open:** `sample-app/src/routes/products.js`

**Step-by-step:**

1. **Go to the end of the file, after the last route handler**

2. **Start typing a comment:**
   ```javascript
   // DELETE endpoint to remove a product by ID
   ```

3. **Press Enter and start typing:**
   ```javascript
   router.delete
   ```

4. **Wait for Copilot ghost text** — it should suggest the full route handler
   - Point at the grey text: "See that? Copilot read the existing routes and suggests a complete handler."
   - Press `Tab` to accept
   - "One Tab — full route with error handling, status codes, and response format matching our style."

5. **Show a Dockerfile completion** (open `sample-app/Dockerfile`)
   - Go to end, type: `# Add a healthcheck`
   - Wait for suggestion: `HEALTHCHECK --interval=30s CMD curl -f http://localhost:3000/health || exit 1`
   - "It knows our health endpoint is on port 3000 because it read app.js."

**Say:**
> "Inline completion is the gateway drug. Once you're used to it, you never go back.
> But the real power for DevOps is in Chat and Agent Mode."

---

### 5.3 — Copilot Chat Demo (10 min)

**Open Copilot Chat:** `Ctrl+Shift+I`

#### Demo 3A: Explain K8s Manifest

1. **Open** `k8s/base/deployment.yaml` (make sure it's the active tab)
2. **Type in Chat:**
   > `Explain what this Kubernetes deployment does, including the resource limits and probe configuration`

3. **Wait for response** — Copilot will explain:
   - The deployment creates X replicas
   - Resource requests/limits
   - Any probes configured
   - The image pull policy

4. **Say:**
   > "Imagine you're a new team member. Instead of Googling every K8s field,
   > you ask Copilot. It reads the file and explains in plain English."

#### Demo 3B: Explain Pipeline

1. **Open** `pipelines/ci-pipeline.yml`
2. **Type in Chat:**
   > `What does this CI pipeline do step by step? Summarize each stage.`

3. Copilot will break down all stages and steps.

4. **Say:**
   > "For a 120-line pipeline, you get a plain-English summary in 5 seconds.
   > New hires can onboard to your CI/CD without a 2-hour walkthrough."

#### Demo 3C: Generate Code

1. **Type in Chat:**
   > `Generate a Kubernetes liveness probe and readiness probe for a Node.js app that serves /health on port 3000. Use 10 second initial delay, 15 second period.`

2. Copilot will output ready-to-paste YAML.

3. **Say:**
   > "No Googling, no Stack Overflow, no reading 5 pages of K8s docs.
   > Describe what you need, get production-ready YAML."

#### Demo 3D: Fix Broken YAML

1. **Open** the pre-created `pipelines/broken-demo.yml`
2. **Select all the YAML** (`Ctrl+A`)
3. **Type in Chat:**
   > `Fix the YAML errors in this pipeline file`

4. Copilot will identify:
   - Missing colon after `include`
   - Bad indentation on `containerRegistry`
   - `tags` key in wrong place

5. **Say:**
   > "It found three errors and explained each one. This is /fix on steroids —
   > it doesn't just flag the error, it tells you WHY and gives you the corrected version."

---

### 5.4 — Copilot in Azure DevOps (5 min)

**Switch to browser — Azure DevOps**

#### Demo 4A: PR Summary

1. **Open the pre-created Pull Request** (from Module 1 or create one)
2. **Click "Summarize with Copilot"** (if the button is available)
   - Wait for AI-generated PR description
   - "Instead of writing 'Changed some stuff' — Copilot reads the diff and writes
     a proper description with what changed and why."

> **If button isn't available:** Show a screenshot or say:
> "In orgs with Copilot for Azure DevOps enabled, this button appears on every PR.
> It reads the diff and generates a structured summary."

#### Demo 4B: Work Item Assistance (if available)

1. **Go to Boards** → create a new User Story
2. **Type title:** `Add rate limiting to production API`
3. **Click "Fill with Copilot"** (if available)
   - Copilot fills in: description, acceptance criteria, tasks
   - "Product managers love this — describe the feature, get automaated acceptance criteria."

#### Demo 4C: Pipeline Failure Diagnosis (if you have a failed run)

1. **Open a failed pipeline run**
2. **Click the failure** → read the error log
3. **In Copilot Chat (VS Code), ask:**
   > `This Azure DevOps pipeline step failed with this error: [paste error]. What caused this and how do I fix it?`

4. **Say:**
   > "Instead of Googling the error, you paste it into Copilot and get a diagnosis.
   > This is especially powerful for cryptic K8s errors."

---

### 5.5 — Agent Mode: The Star of the Show (7 min)

**Switch to VS Code. This is the demo everyone will remember.**

**Open Copilot Chat → switch to Agent Mode** (dropdown at top of Chat panel)

#### Agent Demo 1: Multi-File K8s Changes

1. **Type:**
   > `I need to add a readiness probe and liveness probe to all my Kubernetes deployments in the k8s/ folder. The app serves /health on port 3000. Use initialDelaySeconds: 10, periodSeconds: 15, failureThreshold: 3.`

2. **Watch Copilot:**
   - It reads `k8s/base/deployment.yaml`
   - It reads the overlay files
   - It proposes changes to multiple files
   - Changes appear in diff view

3. **Narrate as it works:**
   > "See — it's reading the files first... now it's planning changes...
   > now it's showing us the diff. We review this before accepting anything."

4. **Show the diff view** — point at the green lines (additions)
   - "Readiness probe, liveness probe, correct port, correct path. All correct."

5. **Accept the changes** (click Accept in the diff)

#### Agent Demo 2: Generate a Pipeline Step

1. **Continue in Agent Mode:**
   > `Now add a pipeline step to the CI pipeline that validates all K8s manifests using kubeval before the Build stage.`

2. Copilot will:
   - Read `pipelines/ci-pipeline.yml`
   - Propose a new step/job that runs `kubeval`
   - Show the diff

3. **Say:**
   > "Two prompts. Multi-file changes. Validated K8s manifests in CI.
   > That used to be a 30-minute task — finding the tool, writing the YAML,
   > testing it. Agent Mode did it in 30 seconds."

#### If Time: Agent Demo 3 — Generate a Runbook

1. **Type:**
   > `Generate a production deployment runbook in markdown format. Include pre-deployment checks, deployment steps using our pipeline, post-deployment verification commands, and rollback procedures. Base it on our k8s/ manifests and cd-pipeline.yml.`

2. Copilot will generate a complete runbook reading your actual files.

3. **Say:**
   > "It didn't generate generic content — it read YOUR manifests, YOUR pipeline,
   > and wrote a runbook specific to YOUR setup. That's the agentic difference."

---

## Timing Checkpoints

| Time | You Should Be At |
|------|-----------------|
| 2:00 | Starting — "What is GitHub Copilot?" slides |
| 2:03 | Inline completion demo |
| 2:08 | Copilot Chat demo (explain, generate, fix) |
| 2:18 | Copilot in Azure DevOps demo |
| 2:23 | Agent Mode demo (the star) |
| 2:30 | Wrapping Agent Mode, "Your turn!" |
| 2:30 | Participants start Lab 5 |
| 2:45 | Lab 5 done → transition to Wrap-Up |

---

## Recovery Plays

| If This Happens | Do This |
|-----------------|---------|
| Copilot isn't suggesting inline | Check: extension installed, signed in, file is not gitignored |
| Chat is slow to respond | Say "Copilot is thinking — it's reading all the files in our workspace" |
| Agent Mode makes a wrong change | **Perfect teaching moment** — "See, it's not perfect. Always review the diff. This is AI-assisted, not AI-replaced." |
| Copilot generates wrong YAML syntax | Use it as the /fix demo: "Let's ask Copilot to fix its own mistake" |
| Azure DevOps Copilot features unavailable | Skip 5.4, spend more time on Agent Mode demos |
| Copilot is completely down | Switch to the cached screenshots/GIFs you prepared (see Backup Plan) |

---

## Audience Engagement Tactics

### During Chat demo:
- "Who wants to suggest a prompt? What should we ask Copilot?"
- Let someone from the audience suggest a question — type it live

### During Agent Mode:
- "Notice I'm not writing any code. I'm describing the outcome I want."
- "This is the mental shift — from 'I need to know the syntax' to 'I need to know what I want.'"

### After Agent Mode:
- "Raise your hand if you'd use this tomorrow at work." (expect most hands)
- "Now it's your turn — Lab 5 has exercises for you to try."

---

## Key Messages to Land

1. **Copilot reads your actual codebase** — suggestions are contextual, not generic
2. **Three progression levels:** inline (Tab) → Chat (ask) → Agent (delegate multi-step tasks)
3. **For DevOps, the biggest win is YAML and config** — the boilerplate nobody wants to write
4. **Always review the output** — Copilot is an assistant, not a replacement for understanding
5. **Agentic DevOps = less toil, more thinking** — let AI handle the syntax, you handle the strategy
6. **This is L100** — what you've seen today is just the beginning. Copilot gets better the more context it has.
