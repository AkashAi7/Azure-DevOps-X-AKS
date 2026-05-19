# Lab 2: Build To ACR And Deploy From ACR To AKS

## Duration

90 to 120 minutes

## Goal

Create two separate pipelines: one to build and push a container image to ACR and another to deploy a selected image from ACR to AKS.

## Prerequisites

- Completed Lab 1
- Azure service connection is ready
- ACR and AKS details are available in the variable group
- Access to the workshop AKS namespace
- Review [workshop/azure-devops-prerequisites.md](../azure-devops-prerequisites.md) before this lab if the customer is new to Azure service connections, ACR permissions, or AKS access setup

## Lab Tasks

### Task 1: Review The Starter Assets

Open these files:

- `azure-pipelines-acr.yml`
- `azure-pipelines-acr-nginx.yml`
- `azure-pipelines-aks.yml`
- `k8s/namespace.yaml`
- `k8s/deployment.yaml`
- `k8s/service.yaml`

### Task 2: Configure Variables

Update these values in the pipeline or variable group:

- `azureSubscription`
- `acrName`
- `acrLoginServer`
- `imageRepository`
- `aksNamespace`
- `aksClusterName`
- `aksResourceGroup`

Optional beginner track:

- Run `azure-pipelines-acr-nginx.yml` first to build and push the nginx sample image before using the app image pipeline.

### Task 3: Create The ACR Pipeline

Create a pipeline from `azure-pipelines-acr.yml` and run it.

### Task 4: Create The AKS Pipeline

Create a second pipeline from `azure-pipelines-aks.yml`.

### Task 5: Build And Push

Run the build stage and confirm the image appears in ACR.

### Task 6: Deploy To AKS

Run the deployment stage and verify:

```powershell
kubectl get pods -n <namespace>
kubectl get svc -n <namespace>
kubectl rollout status deployment/workshop-demo -n <namespace>
```

## Success Criteria

- Container image is pushed to ACR
- AKS deployment succeeds
- Service is reachable inside the cluster or through the configured endpoint

## Suggested Break-Fix Variations

- Use a wrong image tag
- Use the wrong namespace
- Change the service selector so it does not match the pod labels

## Debrief

- Which stage failed first when configuration was wrong?
- What did the logs tell you that the YAML did not?
- What checks would you automate next?