# Azure DevOps Prerequisites For First-Time Customers

This guide is for the most constrained starting point: the customer already has an Azure DevOps project, but may not yet have a repository, pipeline permissions, service connections, Azure resources, or any machine that can run a self-hosted agent.

The workshop sample pipelines in this repository are designed to work best with Microsoft-hosted agents. That is the recommended path for first-time Azure DevOps users because it avoids the need to provision and maintain build machines before the workshop starts.

## Start Here

Before running any pipeline, confirm which of these scenarios applies:

1. The customer only wants to try the basic CI pipeline.
2. The customer wants to build and push images to Azure Container Registry.
3. The customer wants the full flow: CI, ACR image build, and AKS deployment.

The setup effort increases with each scenario. Do not prepare AKS access if the workshop only needs the first pipeline.

## Recommended Default Setup

For a brand-new customer, use this operating model unless there is a clear reason not to:

- Azure DevOps Services, not Azure DevOps Server
- Microsoft-hosted agents, not self-hosted agents
- One Azure Resource Manager service connection for the workshop project
- One shared Azure subscription or one shared resource group prepared by the instructor
- One Azure Container Registry for the class
- One AKS cluster only if the AKS deployment lab is included
- One namespace per team if multiple teams share a cluster

This model removes the need for the customer to manage a build VM, patch an agent, install Docker, or keep Azure CLI sessions alive on a dedicated machine.

## What The Customer Must Already Have

At minimum, the customer needs these platform-level items before trying the sample pipelines:

- An Azure DevOps organization
- An Azure DevOps project
- Access to Azure Repos and Azure Pipelines inside that project
- An Azure subscription where workshop resources can be created or reused
- Permission to create or use service connections in the project

If the customer only has an Azure DevOps project and nothing else, the instructor or platform team must provide the remaining prerequisites below.

## Azure DevOps Requirements

### Organization And Project

The Azure DevOps side should include:

- One Azure DevOps organization already created
- One project already created
- Azure Repos enabled for the project
- Azure Pipelines enabled for the project

### Permissions

For the person setting up the workshop, the minimum useful permissions are:

- Create repositories
- Create and edit pipelines
- Queue pipeline runs
- Create service connections, or at least use an existing approved service connection
- Create variable groups
- Create environments if approvals are part of the workshop

If the customer cannot create service connections, plan for an Azure DevOps project administrator to create them ahead of time.

### Parallel Job Capacity

For Microsoft-hosted agents, verify that the organization has at least one available hosted parallel job. Without hosted parallel job capacity, the pipeline YAML can be correct and still stay queued forever.

Minimum recommendation:

- 1 hosted parallel job for a small pilot or single-team workshop
- 2 or more hosted parallel jobs if several teams will run builds at the same time

### Repository Content

The customer also needs a repository containing:

- The sample application code
- The pipeline YAML files
- The Dockerfile used by the image build pipeline
- The Kubernetes manifests used by the AKS deployment pipeline

This repository can be created manually or by using [scripts/bootstrap-workshop.ps1](../scripts/bootstrap-workshop.ps1).

## Agent Requirements

### Recommended Path: Microsoft-Hosted Agents

Use Microsoft-hosted agents for this workshop if the customer does not already operate build machines.

Benefits:

- No VM or laptop needs to stay online for the pipeline to run
- Node.js, Azure CLI, Git, and common build tooling are already available
- Easier support for first-time users
- Lower workshop setup risk

For this repository, Microsoft-hosted agents are enough for:

- The basic Node.js CI pipeline
- The ACR image build pipeline that uses `az acr build`
- The AKS deployment pipeline, provided it uses an Azure service connection and obtains cluster credentials during the run

### When A Self-Hosted Agent Is Actually Needed

Use a self-hosted agent only if one of these conditions is true:

- The build must access private network resources that hosted agents cannot reach
- The customer requires custom internal tools not present on hosted images
- The build must run in a locked-down environment with private connectivity only
- Security policy forbids Microsoft-hosted agents

If a self-hosted agent is required, the customer must prepare:

- A Windows or Linux machine that stays online during workshop hours
- Outbound internet access to Azure DevOps and Azure
- Git, Node.js 20, Azure CLI, and optionally Docker installed
- The Azure Pipelines agent software installed and registered
- Enough local permissions for the agent account to run the required tools

Do not choose this path for beginners unless there is a hard dependency.

## Azure Requirements By Pipeline

### Pipeline 1: Basic CI Pipeline

This is the easiest starting point.

Required:

- Azure DevOps project
- Azure Repos repository with the sample app
- Microsoft-hosted agent capacity

Not required:

- Azure service connection
- ACR
- AKS
- Service principal for Azure resource access

The file used is [templates/sample-app/azure-pipelines-basic.yml](../templates/sample-app/azure-pipelines-basic.yml).

### Pipeline 2: ACR Build Pipeline

This pipeline builds the container image by calling `az acr build`, which runs the image build in Azure Container Registry. That means the pipeline agent does not need Docker installed locally.

Required:

- Azure subscription access
- One Azure Container Registry already created
- One Azure Resource Manager service connection in Azure DevOps
- Permission for that service connection to use the ACR resource

Recommended workshop setup:

- Put the ACR in a shared workshop resource group
- Create one Azure Resource Manager service connection scoped to that resource group or subscription
- For workshop simplicity, grant the service principal Contributor on the resource group that contains the registry

Why Contributor is the simplest beginner choice:

- It is usually enough for `az acr build` workflows
- It avoids class time spent troubleshooting narrowly-scoped permissions
- It can be tightened later after the workshop

If the customer wants least privilege after the workshop, review and reduce permissions before production use.

The file used is [templates/sample-app/azure-pipelines-acr.yml](../templates/sample-app/azure-pipelines-acr.yml).

### Optional Beginner Pipeline: Nginx To ACR

This pipeline is a simpler ACR example that is useful before moving to the application image.

Required:

- The same prerequisites as the main ACR pipeline

The file used is [templates/sample-app/azure-pipelines-acr-nginx.yml](../templates/sample-app/azure-pipelines-acr-nginx.yml).

### Pipeline 3: AKS Deployment Pipeline

This is the most demanding setup.

Required:

- One AKS cluster already created
- One namespace created for the team, or permission to create one
- One Azure Resource Manager service connection that can access the AKS resource
- Kubernetes access for the identity used by the pipeline after credentials are obtained

Recommended workshop setup:

- Instructor pre-creates the AKS cluster
- Instructor pre-creates one namespace per team
- Instructor tests deployment once before class
- Participants reuse the prepared cluster and namespace instead of creating infrastructure during the lab

Minimum Azure permissions for the Azure-side identity:

- Ability to read the AKS cluster
- Ability to call `az aks get-credentials`

Cluster-side permissions:

- Permission to create or update deployments and services in the workshop namespace

For workshop simplicity, many teams use elevated access during class and then replace it with tighter namespace-scoped access later. If the customer wants a production-like setup, plan extra preparation time for Kubernetes RBAC and namespace scoping.

The file used is [templates/sample-app/azure-pipelines-aks.yml](../templates/sample-app/azure-pipelines-aks.yml).

## Service Connection And Service Principal Requirements

### What Azure DevOps Needs

For the ACR and AKS pipelines, Azure DevOps needs an Azure Resource Manager service connection.

That service connection is backed by an Azure identity, usually one of these:

1. A service principal created for Azure DevOps
2. A workload identity federation setup created from Azure DevOps

For a beginner workshop, use whichever method the customer already supports operationally. If there is no existing standard, an Azure Resource Manager service connection created by the Azure DevOps wizard is usually the fastest option.

### Recommended Service Connection Scope

Use one of these scopes:

1. Resource group scope if the workshop resources all live in one resource group
2. Subscription scope if the workshop spans multiple resource groups

Resource group scope is usually the safer workshop default.

### Service Principal Guidance

If the customer uses a service principal, confirm all of the following:

- The app registration or service principal exists in Microsoft Entra ID
- The service principal is assigned the needed Azure RBAC roles
- The secret or certificate is valid for the full workshop duration if secret-based auth is used
- Ownership of the service principal is clear so it can be renewed later

For a workshop environment, avoid using a personal user account as the pipeline identity.

### ACR Access Guidance

For the image build pipeline, validate:

- The service connection targets the correct subscription or resource group
- The service connection can see the ACR resource
- The registry name and login server values are correct
- The service connection identity has permission to run the chosen ACR workflow

### AKS Access Guidance

For the deployment pipeline, validate:

- The service connection can access the AKS resource group
- The cluster name is correct
- The namespace exists, or the pipeline has permission to create it
- The identity used by the pipeline can deploy resources to the namespace

## Variable And Secret Requirements

Do not leave workshop-specific values hardcoded in YAML unless the goal is only to explain the file structure.

Recommended variable group values:

- `azureSubscription`
- `acrName`
- `acrLoginServer`
- `imageRepository`
- `aksClusterName`
- `aksResourceGroup`
- `aksNamespace`

Keep secrets out of the repository. If secrets are needed, use:

- Azure DevOps secret variables
- Azure Key Vault-backed variable groups

## Network And Endpoint Checks

Before class, validate access to:

- `dev.azure.com`
- `login.microsoftonline.com`
- Azure management endpoints used by Azure CLI
- The ACR and AKS resources in the target subscription

If the customer runs behind a corporate proxy or firewall, test sign-in and one pipeline run before the workshop day.

## Pre-Workshop Validation Checklist

Run this checklist in order.

### Minimum Validation For The Basic Pipeline

1. Confirm the repository exists in Azure Repos.
2. Confirm the project can create YAML pipelines.
3. Confirm a Microsoft-hosted agent job can start.
4. Run [templates/sample-app/azure-pipelines-basic.yml](../templates/sample-app/azure-pipelines-basic.yml) once.

### Additional Validation For The ACR Pipeline

1. Confirm the ACR resource exists.
2. Confirm the Azure service connection is authorized for the pipeline.
3. Confirm `acrName` and `acrLoginServer` are correct.
4. Run [templates/sample-app/azure-pipelines-acr.yml](../templates/sample-app/azure-pipelines-acr.yml) once.
5. Confirm the image appears in the registry.

### Additional Validation For The AKS Pipeline

1. Confirm the AKS cluster exists.
2. Confirm the namespace exists or can be created.
3. Confirm the service connection can obtain cluster credentials.
4. Run [templates/sample-app/azure-pipelines-aks.yml](../templates/sample-app/azure-pipelines-aks.yml) once.
5. Confirm the deployment rollout succeeds.

## What Usually Breaks For New Customers

These are the most common blockers when the customer says, "we only have a project":

- No hosted parallel job available
- No repository has been created yet
- Pipeline YAML exists locally but has not been pushed to Azure Repos
- No Azure service connection exists
- The service connection exists but is not authorized for the pipeline
- The ACR name in the YAML does not match the actual registry
- The AKS cluster exists but the pipeline identity cannot deploy to the namespace
- The pipeline expects a self-hosted `Default` agent pool that the customer never created

## Strong Recommendation

For the first workshop run, do not require the customer to build all of this from scratch during the session.

Prepare these items ahead of time:

- Azure DevOps organization and project
- One sample repository
- Hosted parallel job availability
- One Azure service connection
- One ACR instance
- One AKS cluster and namespace only if the AKS lab is included
- One successful test run of each pipeline you intend to teach

That keeps the workshop focused on learning Azure DevOps instead of spending most of the session on platform provisioning.