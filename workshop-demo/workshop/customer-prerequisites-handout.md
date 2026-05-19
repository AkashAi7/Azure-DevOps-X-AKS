# Customer Handout: Azure DevOps Workshop Prerequisites

Use this handout before the workshop if your starting point is only an Azure DevOps project and you want to know what must be ready before the sample pipelines can run.

## Recommended Starting Model

For first-time Azure DevOps users, the recommended workshop setup is:

- Azure DevOps Services
- Microsoft-hosted agents
- One Azure Repos repository for the sample app
- One Azure Resource Manager service connection
- One shared Azure Container Registry if the ACR lab is included
- One shared AKS cluster only if the AKS lab is included

This is the fastest and lowest-risk setup. It avoids the need to provision and manage your own build machine.

## What You Need Before The Workshop

Minimum Azure DevOps requirements:

- An Azure DevOps organization
- An Azure DevOps project
- Access to Azure Repos and Azure Pipelines
- Permission to create or use pipelines
- At least one available Microsoft-hosted parallel job

Minimum Azure requirements:

- An Azure subscription
- Permission to create or use Azure resources for the workshop

## If You Do Not Have Build Machines

That is fine. You do not need to provide a machine for the workshop pipelines if Microsoft-hosted agents are available in your Azure DevOps organization.

Use self-hosted agents only if your security or network rules require them.

## What Is Needed For Each Pipeline

### Basic CI Pipeline

Required:

- Azure DevOps project
- Repository with the sample app and YAML pipeline
- Microsoft-hosted agent capacity

Not required:

- Azure service connection
- ACR
- AKS

### ACR Image Build Pipeline

Required:

- Azure Container Registry already created
- Azure Resource Manager service connection in Azure DevOps
- Permission for that service connection to access the ACR resource

Recommended:

- Scope the service connection to the workshop resource group if possible
- Use a service principal or workload identity created for Azure DevOps, not a personal user account

### AKS Deployment Pipeline

Required:

- AKS cluster already created
- Workshop namespace already created, or permission to create it
- Azure Resource Manager service connection that can access the AKS resource
- Permission for the pipeline identity to deploy into the workshop namespace

## Service Connection Requirement

To run the ACR and AKS pipelines, Azure DevOps needs an Azure Resource Manager service connection.

That service connection should be ready before the workshop starts.

Confirm:

- It points to the correct subscription or resource group
- It is authorized for the pipelines
- Its identity has the required Azure RBAC access

## Information You Should Have Ready

Please have these values available before the session:

- Azure service connection name
- ACR name
- ACR login server
- Image repository name
- AKS cluster name, if AKS is included
- AKS resource group, if AKS is included
- AKS namespace, if AKS is included

## What Usually Causes Delays

The most common blockers are:

- No hosted parallel job available
- No repository has been created yet
- No Azure service connection exists
- The service connection exists but is not authorized for the pipeline
- The ACR or AKS names are not known before the session
- The workshop YAML assumes a self-hosted agent pool that does not exist

## Best Practice For A Smooth Workshop

Before the workshop day, ask the instructor or platform owner to confirm:

1. The repository exists.
2. A Microsoft-hosted pipeline can start.
3. The Azure service connection is working.
4. The ACR pipeline has been tested once if ACR is included.
5. The AKS deployment has been tested once if AKS is included.

## Where To Find The Full Version

For the complete setup and permission guide, see [workshop/azure-devops-prerequisites.md](azure-devops-prerequisites.md).