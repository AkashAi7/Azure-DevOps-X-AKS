# Day 2: Manual-First ACR And AKS Pipeline Creation

## Theme

Move from a single CI pipeline to a delivery flow with two separate pipelines: one that builds and pushes to ACR and one that deploys the chosen image from ACR to AKS.

## Day Objectives

- Build a dedicated container build pipeline
- Build a dedicated AKS deployment pipeline
- Use service connections, variable groups, and environments
- Build and push a container image to ACR
- Deploy an image from ACR to AKS with Kubernetes manifests
- Understand approvals and release safety controls

## Session Plan

### Module 1: Pipeline Decomposition

- Why use separate pipelines in a beginner workshop
- CI pipeline versus image pipeline versus deployment pipeline
- When to split versus combine stages
- Traceability across pipelines

### Module 2: Secure Pipeline Design

- Service connections
- Variable groups and secrets
- Azure Key Vault integration overview
- Least-privilege access for pipeline identities

### Module 3: Containers And ACR

- Docker build basics
- Tagging strategy
- Push to ACR
- Traceability with build IDs

### Module 4: AKS Deployment

- Namespaces and environments
- Kubernetes manifests
- Rolling updates
- Deployment verification with `kubectl`

## Demo Flow

1. Start from `azure-pipelines-acr.yml` and explain the ACR build flow.
2. Optionally start with `azure-pipelines-acr-nginx.yml` to push a simple nginx image to ACR.
3. Build and push an image to ACR.
4. Use `azure-pipelines-aks.yml` to deploy the selected image to AKS.
5. Verify the rollout and inspect the running service.

## Design Guidance

- Keep one clear responsibility per pipeline in the early workshop
- Use Microsoft-hosted agents unless there is a real self-hosted requirement
- Prefer a shared AKS cluster with isolated namespaces for workshop speed
- Store sensitive values outside the YAML whenever possible

## Hands-On Lab

Use [workshop/labs/lab-2-multi-stage-aks.md](labs/lab-2-multi-stage-aks.md).

## End-Of-Day Deliverable

Every participant should finish with:

- A container build pipeline in YAML
- An optional beginner-friendly nginx image pipeline in YAML
- An AKS deployment pipeline in YAML
- An image published to ACR
- A deployment running in AKS

## Instructor Debrief Questions

- Why separate validate, build, and deploy stages?
- Which parts of the pipeline should require approvals?
- What is the fastest way to confirm whether a deployment actually succeeded?