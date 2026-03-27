# GitHub Copilot in VS Code — Practical DevOps Guide
## *Hands-On Tips for Pipeline & Infrastructure Work*

---

## Interface Overview

```
VS Code with Copilot
├── Inline Suggestions    ← appears as grey text while typing
├── Chat Panel           ← Ctrl+Shift+I — conversational AI
│   ├── Ask Mode         ← Q&A, focused on selected code
│   └── Agent Mode       ← multi-step actions across files
└── Right-click Menu     ← Copilot actions on selected code
```

---

## Inline Completions — Keyboard Shortcuts

| Action | Shortcut |
|--------|---------|
| Accept suggestion | `Tab` |
| Reject suggestion | `Escape` |
| See next suggestion | `Alt+]` |
| See previous suggestion | `Alt+[` |
| See all suggestions (in panel) | `Ctrl+Enter` |
| Trigger suggestion manually | `Alt+\` |

---

## Chat Panel — Slash Commands

| Command | Purpose | Example |
|---------|---------|---------|
| `/explain` | Explain selected code or a concept | `/explain this YAML deployment` |
| `/fix` | Fix bugs or issues in selected code | `/fix the syntax error in this pipeline` |
| `/tests` | Generate unit tests | `/tests for the products router` |
| `/doc` | Generate documentation | `/doc add JSDoc to this module` |
| `@workspace` | Query the entire workspace | `@workspace where is the database connection?` |
| `@vscode` | VS Code questions | `@vscode how do I format YAML on save?` |

---

## Context Management

Copilot's quality directly depends on the context it has:

### How to give more context

1. **Open relevant files** before asking — Copilot sees all open editor tabs
2. **Select specific code** before asking — Copilot focuses on the selection
3. **Mention file names** — "In the file `deployment.yaml`, explain..."
4. **Use `@workspace`** — scans the entire repo for answers

### What Copilot sees

```
Your prompt
+ Your currently open file
+ Your selected text (if any)
+ Other open tabs (limited)
+ Your conversation history (this session only)
```

**It does NOT see:**
- Other files not open in your editor (unless you use @workspace)
- Azure portal, Key Vault secrets, live system state
- Previous chat sessions
- Your private GitHub repos (unless shared in chat)

---

## DevOps-Specific Workflows

### Workflow 1: Understand a New Pipeline

When you're given an unfamiliar pipeline YAML:

1. Open the file in VS Code
2. Press `Ctrl+Shift+I` to open Chat
3. Ask:
```
@workspace Explain what pipelines/ci-pipeline.yml does, 
step by step, in plain English. Who triggers it and what 
artifacts does it produce?
```

### Workflow 2: Modify an Existing Pipeline

When you need to add a new stage:

1. Open the pipeline file
2. Select the existing stage that's most similar to what you need
3. Ask:
```
Based on this stage I've selected, create a new stage 
called "SecurityScan" that runs Trivy container scanning 
after the Build stage. Use the same variable references 
format. Make it fail fast on CRITICAL CVEs.
```

### Workflow 3: Debug a Failed Pipeline

When a pipeline step fails:

1. Copy the error message from the pipeline logs
2. Open the relevant file in VS Code
3. Ask:
```
My Azure DevOps pipeline step failed with this error:
[PASTE ERROR MESSAGE]

Here is the step that failed:
[PASTE YAML STEP]

What caused this error and how do I fix it?
```

### Workflow 4: Generate K8s Manifests

When you need a new Kubernetes object:

```
I need a Kubernetes NetworkPolicy for the production namespace 
that:
- Allows ingress to pods with label app=inventory-api 
  only from the ingress controller namespace
- Allows egress from inventory-api pods to DNS (port 53)
- Denies all other ingress and egress

My namespaces: dev, staging, production, ingress-nginx
```

### Workflow 5: Write kubectl Commands

When you're not sure of the kubectl syntax:

```
Give me the kubectl command to:
1. Watch the rollout status of a deployment named "inventory-api" 
   in the "production" namespace
2. See the last 100 log lines from pods with label app=inventory-api
3. Get a JSON list of all images currently running in the production namespace
```

---

## Agent Mode — When to Use It

Agent Mode is for **multi-step tasks** that touch multiple files:

| Use Agent Mode for | Use Chat for |
|-------------------|-------------|
| "Add health probes to all K8s files" | "What is a health probe?" |
| "Create a new pipeline template file" | "Explain this YAML step" |
| "Refactor deployments to use HPA" | "How does HPA work?" |
| "Generate observability manifests" | "What does Prometheus scrape?" |
| "Update all image tags to use a variable" | "What's a YAML variable?" |

### Agent Mode Workflow

```
1. Switch to Agent (Chat dropdown → Agent)
2. Describe your goal clearly:
   - WHAT you want (not HOW — let Copilot decide)
   - Which folders/files are relevant
   - Any constraints or requirements
3. Review Copilot's proposed actions (it will show you what it plans to do)
4. Let it execute
5. Review the diff for each changed file
6. Accept or discard changes file by file
7. Validate: run tests, dry-run kubectl apply, etc.
```

---

## Copilot in Azure DevOps (Beyond VS Code)

As of 2025-2026, Copilot is available in Azure DevOps for:

### PR Summaries
When creating a PR, a **Summarize** button appears powered by AI:
- Reads the diff automatically
- Generates a human-readable description
- Saves time writing PR descriptions
- Still editable — always review before publishing

### Work Item Assistance
In Azure Boards:
- AI-assisted description filling
- Suggest acceptance criteria based on title
- Helps break down large items into tasks

### Pipeline Failure Analysis
In failed pipeline runs:
- "Ask Copilot" button on failed steps
- Provides AI analysis of the error
- Suggests potential fixes
- Links to relevant documentation

> These features are rolled out incrementally — availability depends on your Azure DevOps tier and region.

---

## Security and Privacy Notes

**What goes to the AI model:**
- Your prompts and selected code
- File content you share in chat

**What you should NEVER share with Copilot:**
- Passwords, secrets, API keys
- Connection strings with credentials
- PII (customer data, employee data)
- Proprietary business logic if your org policy prohibits it

**For Business/Enterprise users:**
- Your code is NOT used to train the model
- There is a 30-day data retention policy for prompt/response data
- Your org admin can configure additional controls

**Bottom line:** Treat Copilot Chat like a Slack conversation that your security team can see.

---

## Quick Reference Prompts for This Workshop

```bash
# Understanding the sample app
"Explain what the InventoryAPI does based on the files in sample-app/"

# Fixing pipeline issues
"My pipeline fails with 'container registry not found'. 
What's wrong with this Docker@2 task? [paste task]"

# Kubernetes questions
"My pod is in CrashLoopBackOff. How do I diagnose this?"

# Security
"Review this Dockerfile for security issues. 
Is there anything that violates container security best practices?"

# Understanding deployment strategies
"What's the difference between RollingUpdate and Recreate deployment 
strategies in Kubernetes, and when should I use each?"

# YAML syntax help
"I keep getting 'mapping values not allowed here' in my YAML. 
Can you explain common YAML indentation mistakes?"
```
