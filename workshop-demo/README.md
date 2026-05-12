# Azure DevOps 3-Day Workshop

This workshop is designed for beginners who need a practical path from DevOps fundamentals to Azure DevOps pipeline creation, ACR image publishing, AKS deployment, and MCP-assisted troubleshooting.

## What This Repository Contains

This repository is a complete workshop pack for learning Azure DevOps in a manual-first way before introducing GitHub Copilot and MCP-assisted workflows.

It includes:

- A 3-day workshop plan with labs
- A guided admin bootstrap script for Azure DevOps setup
- A simple Node.js sample app
- A basic CI pipeline
- A container build pipeline for the sample app
- A beginner-friendly nginx-to-ACR pipeline
- An AKS deployment pipeline
- Kubernetes manifests for the app deployment flow

## Quick Start

### For Workshop Admins

1. Create or use an existing Azure DevOps organization.
2. Prepare an Azure subscription, Azure Container Registry, and AKS cluster.
3. Run the guided setup script:

```powershell
.\scripts\bootstrap-workshop.ps1
```

4. Create pipelines from the YAML files in `templates/sample-app` if you are not using the script to create them automatically.

### For Participants

1. Clone the repository.
2. Review the day-by-day guides under `workshop/`.
3. Start with the basic pipeline.
4. Move to the ACR pipeline.
5. Finish with AKS deployment and MCP-assisted troubleshooting.

## Workshop Flow

The workshop is intentionally split into two modes:

- Days 1 and 2: manual-first, no GitHub Copilot required
- Day 3: GitHub Copilot plus Azure MCP, Azure DevOps MCP, and AKS MCP

## Audience

- Developers new to Azure DevOps
- Build and release engineers who need a structured start
- Platform teams that want a workshop with hands-on labs and light setup

## Learning Outcomes

By the end of Day 3, participants will be able to:

- Explain core DevOps and CI/CD concepts in Azure DevOps
- Create YAML-based Azure Pipelines for build, test, and deployment
- Distinguish between manual-first pipeline authoring and GitHub Copilot-assisted authoring
- Use service connections, environments, approvals, and variable groups
- Publish container images to Azure Container Registry and deploy them to AKS
- Troubleshoot pipeline and AKS issues with Azure MCP, Azure DevOps MCP, and AKS MCP workflows

## Recommended Delivery Model

- Duration: 3 days
- Format: 40 percent lecture, 60 percent lab
- Lab pattern: explain, demo, hands-on, debrief
- Participant profile: basic Git and command-line knowledge is enough

## Workshop Structure

| Day | Theme | Output |
| --- | --- | --- |
| 1 | Manual-first fundamentals and bootstrap | Azure DevOps project, sample repo, and basic CI pipeline |
| 2 | Manual-first container and AKS flow | One pipeline for ACR push and one pipeline for AKS deployment |
| 3 | GitHub Copilot, MCP, and troubleshooting | AI-assisted pipeline authoring and operational debugging |

## Delivery Phases

### Phase 1: No GitHub Copilot

Days 1 and 2 intentionally assume no GitHub Copilot. Participants create the project structure, read the YAML, and understand every stage and step on their own.

### Phase 2: With GitHub Copilot And MCP

Day 3 introduces GitHub Copilot plus Azure MCP, Azure DevOps MCP, and AKS MCP. The goal is not to replace understanding, but to accelerate authoring and troubleshooting after the foundations are clear.

## Files In This Pack

- [workshop/00-setup-and-installation.md](workshop/00-setup-and-installation.md)
- [workshop/day-1-fundamentals.md](workshop/day-1-fundamentals.md)
- [workshop/day-2-pipeline-creation.md](workshop/day-2-pipeline-creation.md)
- [workshop/day-3-aks-mcp-troubleshooting.md](workshop/day-3-aks-mcp-troubleshooting.md)
- [workshop/labs/lab-1-first-pipeline.md](workshop/labs/lab-1-first-pipeline.md)
- [workshop/labs/lab-2-multi-stage-aks.md](workshop/labs/lab-2-multi-stage-aks.md)
- [workshop/labs/lab-3-mcp-troubleshooting.md](workshop/labs/lab-3-mcp-troubleshooting.md)
- [scripts/bootstrap-workshop.ps1](scripts/bootstrap-workshop.ps1)
- [templates/sample-app/package.json](templates/sample-app/package.json)
- [templates/sample-app/azure-pipelines-basic.yml](templates/sample-app/azure-pipelines-basic.yml)
- [templates/sample-app/azure-pipelines-acr.yml](templates/sample-app/azure-pipelines-acr.yml)
- [templates/sample-app/azure-pipelines-acr-nginx.yml](templates/sample-app/azure-pipelines-acr-nginx.yml)
- [templates/sample-app/azure-pipelines-aks.yml](templates/sample-app/azure-pipelines-aks.yml)
- [assets/azure-pipelines.yml](assets/azure-pipelines.yml)
- [assets/manifests/namespace.yaml](assets/manifests/namespace.yaml)
- [assets/manifests/deployment.yaml](assets/manifests/deployment.yaml)
- [assets/manifests/service.yaml](assets/manifests/service.yaml)

## Pipeline Map

Use these sample pipelines in order:

1. [templates/sample-app/azure-pipelines-basic.yml](templates/sample-app/azure-pipelines-basic.yml)
	End result: tested app artifact
2. [templates/sample-app/azure-pipelines-acr-nginx.yml](templates/sample-app/azure-pipelines-acr-nginx.yml)
	End result: simple nginx image pushed to ACR
3. [templates/sample-app/azure-pipelines-acr.yml](templates/sample-app/azure-pipelines-acr.yml)
	End result: app container image pushed to ACR
4. [templates/sample-app/azure-pipelines-aks.yml](templates/sample-app/azure-pipelines-aks.yml)
	End result: selected image deployed to AKS

## Instructor Notes

To keep setup easy, the workshop uses a mixed setup approach:

- One existing Azure DevOps organization
- The project, repository, and starter pipelines can be created with the bootstrap script
- One Azure subscription or shared resource group
- One Azure Container Registry
- One AKS cluster with namespace-level access for participants
- One Azure Resource Manager service connection in Azure DevOps
- One VS Code environment with GitHub Copilot access only for Day 3

This keeps Days 1 and 2 easy to run while still giving participants a real setup experience.

## Admin Setup Experience

The admin setup script is designed as a guided CLI wizard. The instructor can run [scripts/bootstrap-workshop.ps1](scripts/bootstrap-workshop.ps1) and answer a few plain-language prompts instead of remembering technical parameters.

Example:

```powershell
.\scripts\bootstrap-workshop.ps1
```

For automation, the same script still supports non-interactive parameter-based usage.

## Sample Pipelines

The sample repo includes two ACR-focused build examples:

- [templates/sample-app/azure-pipelines-acr.yml](templates/sample-app/azure-pipelines-acr.yml) builds the workshop Node.js app image.
- [templates/sample-app/azure-pipelines-acr-nginx.yml](templates/sample-app/azure-pipelines-acr-nginx.yml) builds a very simple nginx image with a static workshop page.

Use the nginx pipeline when you want the easiest possible container demo before moving to the app-specific image and AKS deployment flow.

## Suggested Pre-Workshop Validation

- Confirm participants can sign in to Azure and Azure DevOps
- Confirm Docker Desktop is running on all lab machines
- Confirm the sample repo builds locally before Day 1
- Confirm the service connection can reach Azure resources
- Confirm the MCP servers are visible from the host editor before Day 3

## Suggested Repository Name

If you publish this sample to GitHub, a clean name is `azure-devops-sample`.

## References

- Azure Pipelines docs: https://learn.microsoft.com/azure/devops/pipelines/?view=azure-devops
- AKS docs: https://learn.microsoft.com/azure/aks/
- Azure MCP Server overview: https://learn.microsoft.com/azure/developer/azure-mcp-server/overview