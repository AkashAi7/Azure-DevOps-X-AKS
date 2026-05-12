# Day 3: GitHub Copilot, MCP, And Troubleshooting

## Theme

Use GitHub Copilot plus MCP-enabled workflows to accelerate pipeline authoring, AKS diagnostics, and Azure troubleshooting after the manual foundations are already understood.

## Day Objectives

- Use MCP tools to inspect Azure, Azure DevOps, and AKS state
- Use GitHub Copilot to explain, improve, and troubleshoot existing pipeline YAML
- Generate or refine pipeline steps using MCP-assisted prompts
- Troubleshoot failed pipeline runs and broken AKS deployments
- Create a repeatable troubleshooting playbook

## MCP Scope For This Workshop

### Azure MCP Server

Use for:

- Inspecting resource groups, identities, clusters, registries, and configuration
- Verifying whether Azure-side dependencies are healthy
- Checking deployment prerequisites and permissions

### Azure DevOps MCP

Use for:

- Listing pipeline runs
- Inspecting failed stages and logs
- Reviewing pipeline definitions and variables
- Comparing failed and successful runs

### AKS MCP

Use for:

- Listing workloads in a namespace
- Inspecting pods, services, events, and rollout status
- Pulling logs from failed containers
- Checking common Kubernetes issues quickly

## Session Plan

### Module 1: MCP Workflow Basics

- What MCP is
- Host, client, server, and tool concepts
- Safe use of MCP for operational work
- When to use MCP versus CLI directly

### Module 2: MCP For Pipeline Authoring

- Ask Copilot to explain the existing manual-first pipelines
- Prompting for a starter pipeline
- Asking for a stage-by-stage explanation
- Generating a troubleshooting checklist from an existing YAML file

### Module 3: Troubleshooting Pipeline Failures

- Failure to trigger
- Service connection issues
- ACR push failures
- Deployment job failures
- Approval and environment issues

### Module 4: Troubleshooting AKS Issues

- Image pull errors
- CrashLoopBackOff
- Service selector mismatch
- Readiness and liveness failures
- Namespace targeting errors

## Sample MCP Prompts

### Azure DevOps MCP

- `List the last 5 failed pipeline runs in the ado-workshop project and summarize the failure points.`
- `Compare the latest failed run with the latest successful run and show what changed.`
- `Read the current pipeline definition and suggest one improvement to make it safer.`

### AKS MCP

- `List pods in namespace workshop-team1 and explain why any pod is not ready.`
- `Show rollout status, warning events, and logs for deployment workshop-demo.`
- `Find services that do not match any running pods in this namespace.`

### Azure MCP Server

- `Check whether the ACR, AKS cluster, and managed identity dependencies for this deployment are healthy.`
- `List role assignments relevant to the pipeline identity on the workshop resource group.`
- `Summarize the resources involved in the application deployment path.`

## Troubleshooting Playbook

1. Check pipeline trigger and source branch.
2. Check the failed stage and task logs.
3. Check service connection and Azure permissions.
4. Check image build and push result.
5. Check AKS rollout status.
6. Check pod events and container logs.
7. Check service exposure and selectors.
8. Fix one issue at a time and rerun.

## Hands-On Lab

Use [workshop/labs/lab-3-mcp-troubleshooting.md](labs/lab-3-mcp-troubleshooting.md).

## End-Of-Day Deliverable

Every participant should finish with:

- A working MCP troubleshooting workflow
- A corrected failing pipeline or AKS deployment
- A reusable prompt set for operational debugging