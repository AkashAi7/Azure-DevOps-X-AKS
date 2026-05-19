# Lab 06: MCP Server Use Cases — Azure DevOps and AKS

**Duration:** 30 minutes  
**Module:** Module 6  
**Level:** L200 — Familiarity with Azure DevOps, AKS, and GitHub Copilot recommended  
**Objective:** Set up and use Model Context Protocol (MCP) servers for Azure DevOps and Azure Kubernetes Service (AKS) with GitHub Copilot, enabling AI-assisted DevOps workflows that go beyond static chat — letting Copilot read and act on your real pipeline data and cluster state.

---

## What is MCP?

The **Model Context Protocol (MCP)** is an open standard that lets AI assistants (like GitHub Copilot) connect to external tools and live data sources through a consistent interface.

Without MCP, Copilot can only reason about code you paste into the chat window.  
With MCP, Copilot can **query your real Azure DevOps project** and **inspect your live AKS cluster** and then act on what it finds.

```
Traditional Copilot Chat:
  You: "My pipeline is failing" → Copilot: guesses based on your description

Copilot + MCP:
  You: "My pipeline is failing" → Copilot: reads the actual failed run logs → explains root cause → proposes fix
```

### MCP Servers Used in This Lab

| MCP Server | What it exposes to Copilot |
|---|---|
| **Azure DevOps MCP** | Work items, pipelines, repos, test results, environments |
| **Azure MCP (AKS)** | Cluster resources, pod logs, deployments, services, namespaces |

---

## Prerequisites

Before starting this lab, ensure you have:

- VS Code (latest) with **GitHub Copilot** and **GitHub Copilot Chat** extensions installed and signed in
- Azure CLI (`az --version` → 2.55+) and logged in (`az login`)
- `kubectl` connected to the workshop AKS cluster (`kubectl get nodes` returns 3 nodes)
- Node.js 20+ (`node --version`)
- Azure DevOps project access (from Lab 01)

---

## Part A: Install and Configure MCP Servers

### A1: Install the Azure DevOps MCP Server

The Azure DevOps MCP server exposes Azure Boards, Repos, Pipelines, and Artifacts to AI assistants.

```bash
# Install the Azure DevOps MCP server globally via npm
npm install -g @azure-devops/mcp
```

Verify the install:

```bash
azdo-mcp --version
```

### A2: Install the Azure MCP Server (includes AKS)

The Azure MCP server provides AI access to your Azure resources, including AKS clusters.

```bash
# Install the Azure MCP server globally
npm install -g @azure/mcp
```

Verify:

```bash
azure-mcp --version
```

### A3: Configure VS Code to Use Both MCP Servers

MCP servers are registered in VS Code's Copilot configuration. Create or update `.vscode/mcp.json` in the workshop repo:

1. In VS Code, open the Command Palette (`Ctrl+Shift+P`)
2. Search for **"MCP: Add Server"** and select it
3. If that command is not available, create the file manually:

```bash
mkdir -p .vscode
```

Create `.vscode/mcp.json` with the following content (replace the placeholders with values from your `workshop.env`):

```json
{
  "servers": {
    "azure-devops": {
      "type": "stdio",
      "command": "azdo-mcp",
      "args": [],
      "env": {
        "AZURE_DEVOPS_ORG_URL": "<your-org-url>",
        "AZURE_DEVOPS_PROJECT": "<your-project-name>",
        "AZURE_DEVOPS_PAT": "<your-personal-access-token>"
      }
    },
    "azure": {
      "type": "stdio",
      "command": "azure-mcp",
      "args": [],
      "env": {
        "AZURE_SUBSCRIPTION_ID": "<your-subscription-id>",
        "AZURE_RESOURCE_GROUP": "<your-aks-resource-group>",
        "AZURE_AKS_CLUSTER": "<your-aks-cluster-name>"
      }
    }
  }
}
```

> **Security Note:** Never commit `.vscode/mcp.json` containing a Personal Access Token to source control.
> Add it to `.gitignore` or use environment variable references instead (see `mcp/README.md` for the secure pattern).

### A4: Generate an Azure DevOps Personal Access Token (PAT)

The Azure DevOps MCP server authenticates with a PAT.

1. Open your Azure DevOps organization URL in a browser
2. Click your profile picture → **Personal Access Tokens**
3. Click **+ New Token**
4. Set:
   - **Name:** `MCP-Workshop-Token`
   - **Expiration:** 7 days
   - **Scopes:** Select the following:
     - Work Items: Read & Write
     - Build: Read & Execute
     - Code: Read
     - Release: Read
     - Test Management: Read
5. Click **Create** and copy the token

Paste the token value into the `AZURE_DEVOPS_PAT` field in `.vscode/mcp.json`.

### A5: Verify MCP Servers Are Connected

1. Open Copilot Chat (`Ctrl+Shift+I`)
2. Switch to **Agent Mode** (click the dropdown → Agent)
3. You should see both MCP servers listed in the Tools panel (the plug icon)
4. Type:

```
What MCP tools do you have available?
```

Expected: Copilot lists the Azure DevOps and Azure tools available from the two servers.

---

## Part B: Azure DevOps MCP Use Cases

### B1: Query Work Items with Natural Language

In Copilot Chat (Agent Mode), try the following prompts:

**Query your backlog:**
```
Using the Azure DevOps MCP tools, list all open User Stories
in the current sprint for this project.
```

**Find blocked work items:**
```
Using Azure DevOps, show me any work items that are in "Active"
state but have not been updated in the last 3 days.
```

**Summarise pipeline health:**
```
Using Azure DevOps, get the status of the last 5 pipeline runs
for the CI pipeline. Were any of them failures? If so, what
stage failed?
```

Observe how Copilot calls the MCP server, retrieves real data, and presents a human-readable answer.

### B2: Diagnose a Pipeline Failure

1. In Azure DevOps, navigate to **Pipelines** and find a failed pipeline run
2. Note the run ID (shown in the URL: `.../runs/<run-id>`)
3. In Copilot Chat, ask:

```
Using the Azure DevOps MCP tools, get the logs for pipeline
run <run-id>. Explain what caused the failure and suggest
how to fix it.
```

Copilot will:
- Fetch the pipeline run details via MCP
- Read the failing task logs
- Provide a root-cause explanation
- Suggest a concrete fix

Compare this to the traditional approach (navigating the UI, scrolling through logs manually).

### B3: Create a Work Item Automatically

Ask Copilot to create a work item based on a finding:

```
Using Azure DevOps MCP tools, create a new Bug work item with:
- Title: "Pipeline intermittently fails on Node.js 20 matrix leg"
- Description: "The CI pipeline occasionally fails the test stage
  on the Node.js 20 agent. Appears to be a timing issue in the
  mock server startup. Needs investigation."
- Area Path: the default area path for this project
- Priority: 2
```

Verify the work item was created by checking **Boards → Backlogs** in the Azure DevOps UI.

### B4: Generate a Pipeline YAML Based on Live Repository Structure

```
Using the Azure DevOps MCP tools, look at the files in the
main branch of this project's repository. Then generate a new
pipeline YAML file at pipelines/nightly-test-pipeline.yml that:
1. Runs on a schedule at midnight UTC
2. Runs the full test suite for sample-app
3. Publishes test results to Azure DevOps
4. Sends a notification if tests fail
```

Review the generated YAML. Copilot used the actual repo structure (not a guess) to create a contextually accurate pipeline.

---

## Part C: AKS MCP Use Cases

### C1: Inspect Cluster Resources with Natural Language

In Copilot Chat (Agent Mode):

```
Using the Azure MCP tools, list all pods running in the dev,
staging, and production namespaces of my AKS cluster.
Which pods are not in Running state?
```

```
Using the Azure MCP tools, check the CPU and memory requests
and limits for all inventory-api deployments across namespaces.
Are any deployments missing resource limits?
```

### C2: Diagnose a Pod Issue

If a pod is in `CrashLoopBackOff` or `Pending` state:

```
Using the Azure MCP tools, get the logs and events for the
inventory-api pod in the dev namespace. Diagnose why it is
not starting correctly and suggest a fix.
```

If all pods are healthy, simulate an issue first:

```bash
# Set a bad image to trigger an ImagePullBackOff
kubectl set image deployment/inventory-api \
  inventory-api=notaregistry.io/notanimage:broken -n dev
```

Then ask Copilot to diagnose it via MCP. Afterwards restore the correct image:

```bash
kubectl rollout undo deployment/inventory-api -n dev
```

### C3: Review Resource Quotas and HPA Status

```
Using the Azure MCP tools, check the HorizontalPodAutoscaler
status in the production namespace. Is the current replica
count within expected bounds? What is the CPU utilization
that is driving the autoscaler?
```

```
Using the Azure MCP tools, check whether any pods in any
namespace are hitting their memory limits. Show me the top
3 most memory-consuming pods.
```

### C4: Generate a Kubernetes Manifest Based on Live Cluster State

```
Using the Azure MCP tools, inspect the existing inventory-api
Deployment in the staging namespace. Based on what is actually
deployed, generate an updated Kubernetes manifest at
k8s/overlays/staging/deployment-patch.yaml that:
1. Increases the replica count to 3
2. Adds a PodDisruptionBudget with minAvailable: 1
3. Adds a topologySpreadConstraint for zone-level spreading
```

Copilot reads the real cluster state and generates a patch that matches the actual resource structure.

---

## Part D: Combined Azure DevOps + AKS Agentic Workflow

This part demonstrates the power of combining both MCP servers in a single conversation.

### D1: End-to-End Incident Response

Simulate an incident and let Copilot investigate using both tools:

```
We have an incident. The inventory-api in production is returning
errors. Use all available MCP tools to:
1. Check the pod status and recent logs in the production namespace
2. Check if there was a recent deployment that may have caused this
3. Look at the Azure DevOps deployment history to find the last
   release to production
4. Summarise what changed between the previous release and the current one
5. Recommend whether to roll back or fix forward
```

Watch how Copilot:
- Calls the AKS MCP to inspect pods and logs
- Calls the Azure DevOps MCP to check deployment history
- Correlates the two data sets
- Produces an actionable recommendation

### D2: Pre-Deployment Checklist Automation

Before deploying to production, ask Copilot to run a pre-deployment checklist using live data:

```
Before we deploy to production, use MCP tools to verify:
1. Azure DevOps: all required approvals for the current release are granted
2. Azure DevOps: the CI pipeline for the commit being deployed passed all stages
3. AKS: the staging namespace pods are all healthy (pre-condition check)
4. AKS: there is enough capacity in the production node pool to add 2 replicas

Summarise the result as PASS / WARN / FAIL for each item.
```

### D3: Generate a Post-Deployment Report

After a successful deployment, ask Copilot to create a report:

```
Using all available MCP tools, create a post-deployment report
for the latest production deployment. Include:
1. Which pipeline run triggered the deployment and who approved it
2. What code changes were included (commit messages from Azure Repos)
3. Current pod health in the production namespace
4. Any HPA scaling events in the last hour
5. A brief "all clear" or list of items requiring follow-up

Save the report as docs/post-deployment-report.md
```

---

## Part E: Secure MCP Configuration (Best Practices)

### E1: Use Environment Variables Instead of Inline Credentials

Instead of putting your PAT directly in `mcp.json`, source values from environment variables:

```json
{
  "servers": {
    "azure-devops": {
      "type": "stdio",
      "command": "azdo-mcp",
      "args": [],
      "env": {
        "AZURE_DEVOPS_ORG_URL": "${env:AZURE_DEVOPS_ORG_URL}",
        "AZURE_DEVOPS_PROJECT": "${env:AZURE_DEVOPS_PROJECT}",
        "AZURE_DEVOPS_PAT": "${env:AZURE_DEVOPS_PAT}"
      }
    },
    "azure": {
      "type": "stdio",
      "command": "azure-mcp",
      "args": [],
      "env": {
        "AZURE_SUBSCRIPTION_ID": "${env:AZURE_SUBSCRIPTION_ID}"
      }
    }
  }
}
```

Then set the variables in your shell profile or use the `workshop.env` file you source before opening VS Code:

```bash
# Source your workshop environment before opening VS Code
source workshop.env
code .
```

### E2: Restrict PAT Scope to the Minimum Required

| MCP Feature Used | Required PAT Scope |
|---|---|
| Read work items | Work Items: Read |
| Create/update work items | Work Items: Read & Write |
| Read pipeline runs and logs | Build: Read |
| Trigger a pipeline run | Build: Read & Execute |
| Read repository files | Code: Read |
| Read test results | Test Management: Read |

Create the narrowest PAT that covers only the operations you intend to use.

### E3: Rotate PAT After the Workshop

PATs are long-lived credentials. After the workshop:

1. Go to **Azure DevOps → User Settings → Personal Access Tokens**
2. Revoke the `MCP-Workshop-Token`
3. Remove `.vscode/mcp.json` from your local machine (or clear the PAT value)

---

## Part F: Exploring the MCP Tool Catalogue

MCP servers expose their capabilities as a catalogue of named tools. You can ask Copilot to list them:

```
List all the tools available from the Azure DevOps MCP server,
grouped by category (work items, pipelines, repos, etc.)
```

```
List all the tools available from the Azure MCP server,
grouped by Azure service.
```

Use this to discover capabilities that were not covered in this lab. Some useful ones to explore:

| Tool Category | Example Prompt |
|---|---|
| Azure Boards queries | "Run the saved query 'All open bugs' and summarize the results" |
| PR reviews | "List all open pull requests assigned to me and their review status" |
| Release environments | "Show the deployment history for the production environment" |
| AKS node health | "Check if any AKS nodes are under memory pressure" |
| AKS events | "Show warning events from all namespaces in the last 30 minutes" |
| ConfigMaps | "Show the ConfigMap values for inventory-api in production" |

---

## Lab Completion Checklist

- [ ] Azure DevOps MCP server installed (`azdo-mcp --version` succeeds)
- [ ] Azure MCP server installed (`azure-mcp --version` succeeds)
- [ ] `.vscode/mcp.json` created with both server configurations
- [ ] Azure DevOps PAT generated with correct scopes
- [ ] Both MCP servers appear in Copilot Agent Mode tool list
- [ ] Queried work items and pipeline runs via Copilot + Azure DevOps MCP (Part B)
- [ ] Diagnosed a pod issue via Copilot + AKS MCP (Part C)
- [ ] Completed at least one combined workflow task from Part D
- [ ] Reviewed secure MCP configuration best practices (Part E)

---

## Troubleshooting

| Problem | Likely Cause | Fix |
|---|---|---|
| `azdo-mcp: command not found` | npm global bin not in PATH | Run `npm root -g` and add the bin folder to your PATH |
| `azure-mcp: command not found` | Same as above | Run `export PATH="$PATH:$(npm bin -g)"` |
| MCP server not listed in Agent Mode | VS Code version too old or MCP feature flag not enabled | Update VS Code to the latest release. MCP support requires VS Code 1.90+ and Copilot Chat 0.24+ |
| "Authentication failed" from Azure DevOps MCP | PAT is invalid, expired, or has insufficient scope | Regenerate the PAT and ensure all required scopes are granted |
| "Subscription not found" from Azure MCP | `az login` session expired or wrong subscription set | Run `az login` and `az account set --subscription <id>` |
| Copilot says "I don't have access to Azure DevOps" | MCP server not started or config path wrong | Check `.vscode/mcp.json` exists in the repo root; restart VS Code |
| MCP tool call times out | Network latency or slow Azure DevOps API response | Retry the prompt. If persistent, check Azure DevOps service health at `status.dev.azure.com` |
| PAT in mcp.json was committed to git | Credentials accidentally tracked | Revoke the PAT immediately, generate a new one, and add `.vscode/mcp.json` to `.gitignore` |

---

## Key Takeaways

1. **MCP bridges the gap between AI and live systems** — Copilot stops guessing and starts knowing
2. **Azure DevOps MCP** lets you interact with work items, pipelines, repos, and test plans using natural language
3. **Azure MCP** lets you inspect and reason about your AKS clusters without switching to a terminal or the Azure portal
4. **Combining both MCP servers** enables end-to-end agentic workflows — from incident detection to root-cause analysis to remediation
5. **Security first** — treat MCP configuration files like `.env` files: never commit secrets, use minimum-scope PATs, rotate credentials after use

---

## Next Steps

- **Challenge 03** in `challenges/challenge-03-agentic.md` — use Agent Mode + MCP to build an observability stack
- Explore the full Azure MCP tool catalogue: https://github.com/Azure/azure-mcp
- Read the MCP specification: https://spec.modelcontextprotocol.io
- Set up MCP servers for your own team's Azure DevOps organization
