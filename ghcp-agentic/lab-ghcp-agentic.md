# Lab: GitHub Copilot Agentic DevOps — Full Hands-On Experience

**Duration:** Flexible (15 min in session, extend as take-home)  
**Level:** L100 — No prior Copilot experience required  
**Purpose:** Complete guide for all Copilot exercises, from first use to Agent Mode

---

## Section 1: First-Time Setup Verification

```
✅ Prerequisite checklist:
□ VS Code installed (latest)
□ GitHub Copilot extension installed
□ GitHub Copilot Chat extension installed
□ Signed in with GitHub account that has Copilot license
□ Fortis-Workshop repository cloned and open in VS Code
```

**Quick verification:** Look for the Copilot icon (a small icon) in the VS Code status bar at the bottom. If it's there and not showing an error, you're ready.

---

## Section 2: Inline Completion Exercises

### Exercise 2.1: Complete a Function

1. Open `sample-app/src/routes/products.js`
2. At the bottom of the file, press Enter a few times
3. Type this comment and press Enter:

```javascript
// Search products by name query string, case insensitive
router.get('/search',
```

4. Observe Copilot's suggestion
5. Press Tab to accept OR Alt+] to see alternatives
6. **Validate:** does the generated code match the patterns already in the file?

### Exercise 2.2: Complete Kubernetes YAML

1. Create a new file: `k8s/base/pod-disruption-budget-test.yaml`
2. Start typing:

```yaml
# PodDisruptionBudget that ensures at least 2 pods are always available
apiVersion: policy/v1
kind: PodDisruptionBudget
```

3. Press Enter after the last line and observe
4. Accept the suggestion, then verify it's syntactically correct:

```bash
kubectl apply --dry-run=client -f k8s/base/pod-disruption-budget-test.yaml
```

---

## Section 3: Chat Mode Exercises

Open Copilot Chat: `Ctrl+Shift+I`

### Exercise 3.1: Understand the Architecture

Ask:
```
@workspace I'm new to this codebase. Describe:
1. What this application does
2. How the CI/CD pipeline works (start to finish)
3. How many AKS environments are used and what are they for
4. What files I should start with to understand the CI pipeline
```

Read the response. Does it accurately describe what you see in the repository?

### Exercise 3.2: Understand Kubernetes Concepts

Ask (no file needs to be open):
```
In the context of the Kubernetes deployment in k8s/base/deployment.yaml,
explain the difference between:
- livenessProbe
- readinessProbe  
- startupProbe

When would each one cause a pod to be restarted vs removed from the load balancer?
Use the specific values in that file as examples.
```

### Exercise 3.3: Get YAML Help

1. Open `pipelines/ci-pipeline.yml`
2. Find the `Cache@2` task block (around line 40)
3. Select the entire `Cache@2` task
4. Right-click → Copilot → Explain
5. Or in Chat:

```
Explain what this Cache@2 task does in the Azure DevOps pipeline, 
and what happens during a cache hit vs cache miss. 
What's the cache key strategy used?
```

### Exercise 3.4: Fix a Mistake

Create a new file `test-broken-pipeline.yaml` with this intentionally broken YAML:

```yaml
stages:
- stage: Build
  jobs:
    - job: BuildImage
    displayName: Build Docker Image
      steps:
        - task: Docker@2
          displayName: Build image
          inputs
            command: buildAndPush
            containerRegistry: ACR-ServiceConnection
            repository: inventory-api
```

In Chat:
```
/fix this Azure Pipelines YAML file has multiple syntax errors. 
Find and fix all of them.
```

Apply the fix and validate:
```bash
python -c "import yaml; yaml.safe_load(open('test-broken-pipeline.yaml')); print('Valid YAML!')"
```

---

## Section 4: Agent Mode Exercises

**Switch to Agent Mode:** In the Chat panel, click the dropdown that currently says "Ask" → select "Agent"

> Agent Mode can READ and WRITE files. You will review proposed changes before they are applied.

### Exercise 4.1: Add Resource Limits to All Manifests

Type this prompt in Agent Mode:

```
In the k8s/base/deployment.yaml file, resource limits are defined 
but the pods might be running without guaranteed resources in 
certain scenarios.

Please modify the deployment.yaml to also set:
1. requests.ephemeral-storage: "100Mi"
2. limits.ephemeral-storage: "500Mi"

This prevents pods from consuming unlimited disk space.
Also add a comment explaining what ephemeral storage is.
```

Review the proposed change. Accept if it looks correct.

Validate:
```bash
kubectl apply --dry-run=client -f k8s/base/deployment.yaml
```

### Exercise 4.2: Create a Complete New Pipeline Feature

Type this in Agent Mode:

```
I need to add a step to the CI pipeline that checks if the 
Docker image size is under 200MB.

If the image is larger than 200MB, the pipeline should:
- Print a WARNING message (not fail)
- Show the actual image size in the log

Add this as a new step in the Build stage of ci-pipeline.yml, 
right after the Docker build & push step.

Use docker image inspect to get the size.
```

Review the change in ci-pipeline.yml. Is the logic correct?

### Exercise 4.3: Generate a New Documentation File

Type this in Agent Mode:

```
Create a new file: docs/troubleshooting-guide.md

This should be a troubleshooting guide for operations teams 
managing the InventoryAPI on AKS. Include sections for:

1. Common pod issues (CrashLoopBackOff, ImagePullBackOff, Pending)
   - What causes them
   - How to diagnose (kubectl commands to run)
   - How to fix

2. Pipeline failures
   - CI pipeline fails on tests
   - CD pipeline fails on deployment
   - How to re-run a failed stage

3. AKS cluster issues
   - Node not ready
   - Namespace quota exceeded

4. ACR issues
   - Image not found
   - Authentication failure

Base the kubectl commands on the actual resource names (inventory-api, 
namespaces dev/staging/production) used in this project.
```

Read the generated guide. Is it accurate based on what you've learned today?

---

## Section 5: Advanced — Copilot for Security Review

### Exercise 5.1: Security Audit the Dockerfile

1. Open `sample-app/Dockerfile`
2. In Chat:

```
Review this Dockerfile for security issues. Check for:
1. Running as root
2. Using latest tags (unversioned images)
3. Unnecessary packages
4. Sensitive data in layers
5. Best practices for Node.js containers

Report findings with severity (HIGH/MEDIUM/LOW) and suggested fixes.
```

Note the findings. Are there any you didn't already know about?

### Exercise 5.2: Security Audit the K8s Manifests

In Agent Mode:

```
Review all Kubernetes deployment manifests in k8s/ for these 
security issues (Kubernetes Pod Security Standards - Restricted):

1. allowPrivilegeEscalation not set to false
2. readOnlyRootFilesystem not set to true
3. runAsNonRoot not enforced
4. seccompProfile not set
5. capabilities not dropped

For each issue found, apply the fix to the relevant manifest files. 
Where readOnlyRootFilesystem=true would break the app 
(e.g., it needs to write logs), add a tmpfs volume mount instead.
```

Review all proposed changes carefully before accepting.

---

## Section 6: Reflection & Debrief

Answer these questions (write them in `docs/my-copilot-reflections.md`):

1. **What surprised you most** about Copilot's capabilities?
2. **Where did Copilot get it wrong?** What did you have to correct?
3. **What tasks** do you think Copilot is NOT suitable for?
4. **How much time** do you estimate these exercises would have taken without Copilot?
5. **What's the most impactful use case** for your daily work?

---

## Quick Reference Card

Print or bookmark this:

```
┌──────────────────────────────────────────────────────────┐
│           GHCP QUICK REFERENCE — DEVOPS EDITION          │
├──────────────────────────────────────────────────────────┤
│ Inline completion       │ Start typing — press Tab       │
│ Open Chat               │ Ctrl+Shift+I                   │
│ Explain code            │ Select → right-click → Explain │
│ Fix code                │ /fix or "fix this: [paste]"    │
│ Generate tests          │ /tests                          │
│ Agent mode              │ Chat → dropdown → Agent        │
├──────────────────────────────────────────────────────────┤
│ GOLDEN RULE: AI generates, Human validates               │
│ Always kubectl apply --dry-run before apply              │
│ Never share secrets in Copilot prompts                   │
└──────────────────────────────────────────────────────────┘
```
