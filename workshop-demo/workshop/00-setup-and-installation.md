# Setup And Installation

This guide is optimized for the easiest workshop setup. The goal is to avoid long provisioning steps during class while still letting participants create the important Azure DevOps pieces themselves.

## Setup Strategy

Use an existing Azure DevOps organization plus a shared instructor-managed Azure environment. Participants will create the project, repo, and pipelines through a bootstrap script and then work through the pipeline flow manually before introducing GitHub Copilot.

## What Participants Need

- A laptop with Windows 11, macOS, or Ubuntu
- Internet access
- An Azure account with access to the workshop subscription or resource group
- An Azure DevOps account with permission to create a project inside an existing organization
- A GitHub Copilot license only for Day 3

## Install These Tools

1. Install Visual Studio Code.
   https://code.visualstudio.com/
2. Install Git.
   https://git-scm.com/downloads
3. Install Docker Desktop.
   https://www.docker.com/products/docker-desktop/
4. Install Azure CLI.
   https://learn.microsoft.com/cli/azure/install-azure-cli
5. Install kubectl.
   https://kubernetes.io/docs/tasks/tools/
6. Install the Azure Account extension for VS Code.
7. Install the Azure DevOps extension for Azure CLI.
8. Install the GitHub Copilot and GitHub Copilot Chat extensions for Day 3 only.

## Sign-In Steps

Run these commands after installation:

```powershell
az login
az extension add --name azure-devops
az account set --subscription "<workshop-subscription>"
az aks get-credentials --resource-group <rg-name> --name <aks-name>
kubectl get nodes
```

## Manual-First Versus GitHub Copilot

### Days 1 And 2

- No GitHub Copilot required
- Participants read the YAML and write or modify it directly
- Focus is on learning Azure DevOps concepts, not AI assistance

### Day 3

- GitHub Copilot and MCP are enabled
- Participants use Copilot to refine YAML, inspect runs, and troubleshoot issues

## Bootstrap Script

The workshop includes [scripts/bootstrap-workshop.ps1](../scripts/bootstrap-workshop.ps1).

This script can:

- Configure Azure DevOps CLI defaults
- Create the Azure DevOps project if it does not exist
- Create the Azure Repos repository if it does not exist
- Copy a sample application into a local working folder
- Initialize Git, push the repo to Azure Repos, and optionally create the workshop YAML pipelines

Important limitation:

- The script assumes the Azure DevOps organization already exists.
- Use the Azure DevOps portal to create the organization once if needed.

Recommended usage for workshop admins:

```powershell
.\scripts\bootstrap-workshop.ps1
```

This opens a guided CLI wizard and asks for:

- Azure DevOps organization URL
- Project name
- Repository name
- Local sample app folder
- Whether starter pipelines should be created
- Whether an existing local folder may be overwritten

Example usage:

```powershell
.\scripts\bootstrap-workshop.ps1 -NonInteractive `
   -OrganizationUrl "https://dev.azure.com/contoso" `
   -ProjectName "ado-workshop" `
   -RepositoryName "workshop-sample-app" `
   -LocalPath ".\out\workshop-sample-app" `
   -CreatePipelines
```

## Azure DevOps Preparation

Instructor should prepare these shared Azure items before class:

- One existing Azure DevOps organization
- Service connection to Azure
- Variable group containing:
  - `acrName`
   - `acrLoginServer`
  - `aksClusterName`
  - `aksResourceGroup`
  - `aksNamespace`
  - `imageRepository`
- Optional environment `aks-dev` with approval enabled for Day 2

Participants or teams can then create these Azure DevOps artifacts by script:

- Project named `ado-workshop`
- Repo containing the sample app and Dockerfile
- Four YAML pipelines for the workshop sequence

## Sample Repo Structure

Use the included sample application template with this structure:

```text
src/
tests/
Dockerfile
azure-pipelines-basic.yml
azure-pipelines-acr.yml
azure-pipelines-aks.yml
k8s/
```

The included app is a small Node.js web app with no external runtime dependencies. It is intentionally simple so the workshop stays focused on DevOps practices.

## Pipeline Sequence Used In The Workshop

### Pipeline 1: Basic Application Pipeline

Purpose:

- Demonstrate trigger, agent, steps, tests, and artifacts
- Explain every line of a simple YAML pipeline

File:

- `azure-pipelines-basic.yml`

### Pipeline 2: Build And Push To ACR

Purpose:

- Build a container image
- Push the image to Azure Container Registry
- Introduce service connection and deployment variables

File:

- `azure-pipelines-acr.yml`

### Optional Pipeline: Build And Push A Simple Nginx Image To ACR

Purpose:

- Demonstrate the easiest possible container build flow
- Push a simple nginx-based image with static content to ACR
- Use this before the app-specific image pipeline if the audience is very new to containers

File:

- `azure-pipelines-acr-nginx.yml`

### Pipeline 3: Deploy From ACR To AKS

Purpose:

- Pull a selected image from ACR
- Deploy the image into AKS
- Verify rollout and service health

File:

- `azure-pipelines-aks.yml`

## Easy Setup Option

If time is limited, use these shortcuts:

- Shared AKS cluster for the full class
- One namespace per team instead of one cluster per team
- Pre-created ACR and service connection
- Existing Azure DevOps organization
- Pre-installed tool image or VM for participants

## MCP Setup

For Day 3, participants need access to three MCP integrations:

- Azure MCP Server for Azure resource inspection and troubleshooting
- Azure DevOps MCP for pipeline and run inspection
- AKS MCP for Kubernetes-focused diagnostics

Because MCP packaging can vary by organization, use the workshop host's standard MCP configuration. The minimal validation checklist is:

1. Open VS Code.
2. Sign in to Azure and Azure DevOps.
3. Confirm the MCP servers are visible to the host client.
4. Run one test prompt per MCP server.

Example validation prompts:

- Azure MCP: `List my workshop resource group resources.`
- Azure DevOps MCP: `Show the last 3 pipeline runs in the workshop project.`
- AKS MCP: `List pods in the workshop namespace and summarize health.`

## Troubleshooting Setup Issues

- If `az login` fails, verify browser pop-up permissions and tenant access.
- If `kubectl get nodes` fails, refresh AKS credentials with `az aks get-credentials --overwrite-existing`.
- If Docker fails to start, verify virtualization is enabled.
- If Azure DevOps access fails, verify organization access and project creation permissions.
- If MCP tools do not appear, restart the editor and confirm the correct host configuration file is in use.

## Pre-Day Checklist

- Tools installed
- Azure sign-in works
- Azure DevOps organization access works
- kubectl can reach AKS
- Docker runs locally
- MCP connections validated