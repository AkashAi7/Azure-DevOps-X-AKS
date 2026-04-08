# MCP Example Prompts — Azure DevOps and AKS

A curated collection of prompts to use in GitHub Copilot **Agent Mode** once both
MCP servers are connected. Use these as starting points and adapt them to your
actual project state.

---

## Azure DevOps Prompts

### Work Items and Boards

```
Using Azure DevOps MCP tools, list all work items assigned to me
that are in Active state across all area paths.
```

```
Using Azure DevOps MCP tools, show me the current sprint's
burndown: how many story points are complete vs remaining?
```

```
Using Azure DevOps MCP tools, find all Bug work items created
in the last 7 days and group them by assigned user.
```

```
Using Azure DevOps MCP tools, create a new Task work item:
- Title: "Add MCP server configuration to developer onboarding guide"
- Assigned to: me
- Parent: the "GitHub Copilot Agentic DevOps" User Story
- State: Active
```

### Pipelines

```
Using Azure DevOps MCP tools, get the last 10 pipeline runs for
the CI pipeline. Show run number, trigger reason, status, and duration.
```

```
Using Azure DevOps MCP tools, show me all pipeline runs that failed
in the last 24 hours. For each failure, tell me which stage and task
caused the failure.
```

```
Using Azure DevOps MCP tools, get the full logs for the most recent
failed pipeline run and explain what went wrong.
```

```
Using Azure DevOps MCP tools, trigger the CI pipeline manually
for the main branch.
```

### Repositories

```
Using Azure DevOps MCP tools, list all open pull requests in this
project. For each PR, show the author, target branch, number of
reviewers, and current review status.
```

```
Using Azure DevOps MCP tools, show me the commit history for the
main branch over the last 7 days, grouped by author.
```

```
Using Azure DevOps MCP tools, get the content of the file
pipelines/ci-pipeline.yml from the main branch and explain
what each stage does.
```

### Test Plans and Results

```
Using Azure DevOps MCP tools, show the test results for the most
recent CI pipeline run. How many tests passed, failed, and were skipped?
```

```
Using Azure DevOps MCP tools, list all test cases in the current
test plan that have not been run in the last 14 days.
```

---

## Azure / AKS Prompts

### Cluster Overview

```
Using Azure MCP tools, list all namespaces in my AKS cluster
and the number of running pods in each.
```

```
Using Azure MCP tools, list all deployments in the production
namespace with their current replica count, desired replica count,
and image tag.
```

```
Using Azure MCP tools, show the resource requests and limits for
every container in the dev namespace. Highlight any containers
with no limits set.
```

### Pod Health and Logs

```
Using Azure MCP tools, list all pods in all namespaces that are
NOT in Running or Completed state. For each, show the status
and the last event.
```

```
Using Azure MCP tools, get the last 100 log lines from the
inventory-api pod in the dev namespace and identify any errors
or warnings.
```

```
Using Azure MCP tools, describe the inventory-api pod in the
production namespace. Are there any recent warning events?
```

### Autoscaling and Capacity

```
Using Azure MCP tools, show the HorizontalPodAutoscaler status
for all deployments in the production namespace. Is any autoscaler
at its maximum replica count?
```

```
Using Azure MCP tools, show the current resource utilization
(CPU and memory) for each node in the AKS cluster. Are any nodes
above 80% utilization?
```

### Configuration and Secrets

```
Using Azure MCP tools, list all ConfigMaps in the production
namespace. Show the keys (not values) in each ConfigMap.
```

```
Using Azure MCP tools, show the current ingress rules in all
namespaces. Which hostnames are exposed?
```

---

## Combined Azure DevOps + AKS Prompts

### Deployment Correlation

```
Using all available MCP tools:
1. Find the most recent successful deployment to the production
   environment in Azure DevOps
2. Check the current version of the inventory-api image running
   in the production namespace of AKS
3. Confirm whether these match. If not, explain the discrepancy.
```

### Incident Investigation

```
Using all available MCP tools, investigate the following incident:
"The inventory-api response times increased sharply 2 hours ago."

Check:
1. Pod logs in the production namespace for errors around that time
2. HPA scaling events that may indicate CPU saturation
3. Whether any pipeline deployments happened around that time
4. Recent commits that may have introduced a performance regression

Summarise findings and recommend next steps.
```

### Change Impact Analysis

```
Using all available MCP tools:
1. List the last 5 commits merged to main in Azure Repos
2. For each commit, identify which files were changed
3. Check which Kubernetes deployments use the components that changed
4. Assess the blast radius of these changes

Present the analysis in a table format.
```

### Pre-Deployment Health Check

```
Using all available MCP tools, run a pre-deployment health check
before we promote from staging to production:

1. Azure DevOps: confirm the staging deployment pipeline completed
   successfully
2. Azure DevOps: confirm all required approvals are in place
3. AKS: confirm all pods in the staging namespace are Running
4. AKS: confirm the production namespace has at least 2 available
   nodes with sufficient CPU headroom

Return a PASS / WARN / FAIL for each check with a brief explanation.
```

### Sprint Retrospective Data Gathering

```
Using all available MCP tools, gather data for our sprint retrospective:

1. Azure DevOps: list all work items completed in the last sprint
   (State = Closed, closed within last 14 days)
2. Azure DevOps: show CI pipeline success rate over the last 14 days
3. Azure DevOps: count how many bugs were opened vs closed in that period
4. AKS: check if there were any pod restart events in production in that period

Summarise the data in a format suitable for a retrospective discussion.
```

---

## Tips for Better MCP Prompts

1. **Be explicit about which tool to use** — saying "Using Azure DevOps MCP tools"
   helps Copilot select the right server when multiple are available.

2. **Specify namespaces and environments** — "in the production namespace" is much
   clearer than "in production".

3. **Ask for a specific output format** — "present as a table" or "summarize in
   bullet points" shapes the response.

4. **Chain queries** — one prompt can ask Copilot to make multiple MCP calls and
   correlate the results.

5. **Iterate** — if the first answer is incomplete, ask a follow-up:
   "Now get the logs for the failing pod and tell me the root cause."
