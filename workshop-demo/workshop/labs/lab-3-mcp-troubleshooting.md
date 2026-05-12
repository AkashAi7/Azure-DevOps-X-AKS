# Lab 3: MCP-Based Pipeline And AKS Troubleshooting

## Duration

90 minutes

## Goal

Use GitHub Copilot, Azure DevOps MCP, AKS MCP, and Azure MCP Server to find and fix a broken pipeline or deployment faster than with manual inspection alone.

## Prerequisites

- Completed Lab 2
- GitHub Copilot is enabled in the host environment
- MCP integrations are visible in the host environment
- A known broken scenario is prepared by the instructor

## Lab Tasks

### Scenario A: Pipeline Failure

Suggested injected issues:

- Broken service connection name
- Wrong container registry login server
- Bad branch trigger
- Missing variable

Prompt sequence:

1. `List the most recent failed pipeline run and identify the first failing task.`
2. `Summarize the error and suggest the most likely root cause.`
3. `Show which variable or service connection is referenced by the failing step.`
4. Apply the fix and rerun.

### Scenario B: AKS Deployment Failure

Suggested injected issues:

- Wrong image name
- Wrong namespace
- Service selector mismatch
- Container port mismatch

Prompt sequence:

1. `List unhealthy workloads in namespace <team-namespace>.`
2. `Show pod events and logs for the failing deployment.`
3. `Check whether the service matches any pod labels.`
4. `Summarize the minimum fix required.`

### Scenario C: Azure Dependency Failure

Suggested injected issues:

- Missing role assignment
- ACR access denied
- Wrong resource group reference

Prompt sequence:

1. `Check the Azure resources involved in this deployment path.`
2. `List role assignments relevant to the pipeline identity.`
3. `Identify the dependency blocking deployment.`
4. Apply the fix and rerun.

## Success Criteria

- Participants identify the root cause with MCP help
- Participants fix the issue and rerun successfully
- Participants document the prompt flow that helped most

## Debrief

- Which MCP server gave the fastest signal?
- What information still required manual verification?
- How would you turn today’s prompt flow into an operational runbook?