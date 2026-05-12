# Lab 1: Bootstrap The Project And Create The First Pipeline

## Duration

60 to 75 minutes

## Goal

Run the bootstrap flow, create the sample application repository, and validate a CI pipeline that triggers on `main`, builds the sample application, runs tests, and publishes an artifact.

## Prerequisites

- Azure DevOps organization access
- Working local Git installation

## Lab Tasks

### Task 1: Run The Bootstrap Script

Run [scripts/bootstrap-workshop.ps1](../../scripts/bootstrap-workshop.ps1) with your organization URL, project name, and repository name.

### Task 2: Review The Generated Repo

Open the generated sample repository and verify the sample app runs locally.

### Task 3: Create The Basic Pipeline

In Azure DevOps:

1. Go to Pipelines.
2. Create a new pipeline.
3. Select the sample repository.
4. Choose YAML.
5. Select `azure-pipelines-basic.yml` from the repo.

### Task 4: Review The YAML Line By Line

Explain:

- trigger
- pool
- steps
- test command
- artifact publishing

### Task 5: Run And Observe

Run the pipeline and note:

- Trigger source
- Agent image
- Test output
- Published artifact

## Success Criteria

- Pipeline run succeeds
- Tests execute
- Artifact is published
- Azure DevOps project and repo exist in the target organization

## Stretch Goal

Add a branch filter so only `main` and `feature/*` trigger the pipeline.

## Debrief

- Which step took the most time?
- Where do you inspect errors first?
- What would you change to make the pipeline faster?