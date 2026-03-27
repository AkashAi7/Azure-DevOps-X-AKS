# Lab 05: Agentic DevOps with GitHub Copilot

**Duration:** 15 minutes  
**Module:** Module 5  
**Level:** L100 — No prior Copilot experience required  
**Objective:** Get hands-on experience with GitHub Copilot in VS Code for DevOps tasks, and experience the power of Copilot's Agent Mode.

---

## Part A: Verify GitHub Copilot is Installed

### A1: Check VS Code Extension

1. Open VS Code
2. Click the Extensions icon (Ctrl+Shift+X)
3. Search for "GitHub Copilot" — it should show as **installed**
4. Also check: "GitHub Copilot Chat" — also installed

If not installed:
1. Click **Install** on both extensions
2. Sign in with your GitHub account when prompted
3. Verify your account has a Copilot license: `https://github.com/settings/copilot`

### A2: Test Inline Completion

1. Open `sample-app/src/routes/products.js`
2. Scroll to the bottom of the file
3. Press Enter a few times after the last line
4. Start typing:

```javascript
// GET /api/products/category/:category - filter products by cat
```

5. Pause — Copilot should suggest the full handler function
6. Press **Tab** to accept the suggestion
7. If you don't like it, press **Escape** and type more context

> **Tip:** Copilot uses your surrounding code as context. The better your comment, the better the suggestion.

---

## Part B: Using Copilot Chat

### B1: Open Copilot Chat

Press `Ctrl+Shift+I` (or click the chat icon in the sidebar)

### B2: Ask Copilot to Explain Code

In the chat box, type:

```
/explain the deployment.yaml in the k8s/base folder. 
What do the livenessProbe and readinessProbe do, and 
why are there two separate probes?
```

Read the explanation. Ask a follow-up:

```
What would happen if we didn't have a readinessProbe 
and the app was still starting up?
```

### B3: Explain the Pipeline

```
/explain the ci-pipeline.yml. Walk me through what 
happens step by step when a developer pushes to main.
```

### B4: Fix a YAML Error

Copy this broken YAML into a new file (Ctrl+N, save as `test-broken.yaml`):

```yaml
stages:
- stage: Build
  jobs
  - job: Test
    steps:
    - script: npm test
      displayName 'Run tests'
    - task: PublishTestResults@2
      inputs:
        testResultsFormat: JUnit
        testResultsFiles: '**/*.xml
```

In Copilot Chat, type:

```
/fix this pipeline YAML has syntax errors. Fix all of them.
```

Observe the corrections Copilot suggests. Apply them.

---

## Part C: Copilot Agent Mode

This is the most powerful feature — Copilot can take multi-step actions across multiple files.

### C1: Switch to Agent Mode

In Copilot Chat, click the dropdown that says **"Ask"** → switch to **"Agent"**

You'll see a different icon, indicating Copilot can now read/write files and take actions.

### C2: Your First Agent Task

Type this in Agent Mode:

```
I want to add resource quotas to all Kubernetes namespace 
definitions in k8s/base/namespace.yaml. Add a ResourceQuota 
object for each namespace with:
- dev: 500m CPU, 512Mi memory
- staging: 1 CPU, 1Gi memory
- production: 2 CPU, 2Gi memory

Also add a LimitRange to each namespace that sets default 
container limits to 100m CPU and 128Mi memory.
```

Watch what Copilot does:
1. It reads the existing namespace.yaml file
2. It proposes the changes
3. It shows you a diff view
4. You can **Accept** or **Discard** each change

### C3: Review and Accept Changes

1. Review the proposed changes in the diff view
2. The changes should add `ResourceQuota` and `LimitRange` objects
3. Click **Accept** if the changes look correct
4. Verify the file was updated:

```bash
kubectl apply --dry-run=client -f k8s/base/namespace.yaml
# Expected: no errors (dry run validates the YAML)
```

### C4: Generate a Deployment Runbook

Type this in Agent Mode:

```
Create a new file called docs/runbook-deployment.md with 
a deployment runbook for the InventoryAPI application. 
Include:
1. Pre-deployment checklist
2. How to trigger a deployment
3. How to monitor the rollout
4. How to verify success
5. How to rollback if something goes wrong

Base it on the actual pipeline files and kubernetes manifests 
in this repository.
```

Agent mode will:
1. Read the relevant pipeline and K8s files
2. Create a contextually accurate runbook
3. Save it to `docs/runbook-deployment.md`

---

## Part D: Copilot in Azure DevOps (Facilitator Demo)

> At this point, follow the facilitator's screen

The facilitator will demonstrate:

1. **PR Summary generation** in Azure DevOps:
   - Open a PR in Azure DevOps
   - Click "Summarize" (Copilot-powered)
   - See auto-generated PR description based on the diff

2. **Work Item generation**:
   - In Azure Boards, create a new User Story
   - Use Copilot to fill in acceptance criteria

3. **Pipeline failure explanation**:
   - Look at a previously failed pipeline
   - Use Copilot to explain why it failed
   - Get suggested fix

---

## ✅ Lab 5 Completion Checklist

- [ ] GitHub Copilot and Copilot Chat extensions installed and signed in
- [ ] Inline code completion tested in products.js
- [ ] Used `/explain` to understand the K8s deployment probes
- [ ] Used `/fix` to repair a broken YAML file
- [ ] Switched to Agent Mode
- [ ] Resource quotas added to namespace.yaml via Agent Mode
- [ ] Deployment runbook generated at `docs/runbook-deployment.md`
- [ ] Watched PR summary demo (facilitator-led)

---

## Copilot Quick Reference Card

| What you want | How to do it |
|---|---|
| Get code suggestion | Just start typing — Copilot suggests |
| Accept suggestion | `Tab` |
| Reject suggestion | `Escape` |
| See alternative suggestions | `Alt+]` or `Alt+[` |
| Open Chat | `Ctrl+Shift+I` |
| Explain selected code | Select code → right-click → "Explain" |
| Fix selected code | Select code → right-click → "Fix" |
| Explain a file | Chat: `/explain <describe what>` |
| Generate tests | Chat: `/tests` or ask naturally |
| Agent mode (multi-file) | Chat → dropdown → switch to Agent |

---

## Key Copilot Prompting Tips (L100)

1. **Be specific** — "Create a Kubernetes readiness probe for port 3000 with /ready path" is better than "add a probe"

2. **Give context** — Open the relevant files before asking. Copilot sees what's open in your editor.

3. **Iterate** — If the first answer isn't right, ask follow-up questions: "That's good, but also add a timeout of 3 seconds"

4. **Use `/explain` a lot** — You don't need to understand YAML or K8s to work with it. Ask Copilot what things mean!

5. **Trust but verify** — Copilot is helpful but not perfect. Always review what it generates before applying to production.

6. **Agent mode is powerful** — Use it for tasks that span multiple files. Let it do the heavy lifting.

---

## Bonus: Explore Copilot's Limits

Try asking Copilot something it can't or shouldn't do:
```
Give me the password for the workshop Key Vault
```
Expected: Copilot will decline or explain it doesn't have access to live Azure credentials.

Try asking it about its reasoning:
```
Why did you choose to use a RollingUpdate strategy instead of 
Recreate in the deployment manifest?
```
Copilot will explain the trade-offs — this is a great way to learn!
