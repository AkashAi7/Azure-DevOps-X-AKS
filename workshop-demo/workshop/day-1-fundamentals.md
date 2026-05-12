# Day 1: Manual-First Azure DevOps Fundamentals

## Theme

Build the mental model first without GitHub Copilot: DevOps flow, Azure DevOps services, repo creation, and the first CI pipeline.

## Day Objectives

- Understand DevOps, CI, CD, and pipeline terminology
- Create the workshop project and repository from the bootstrap flow
- Navigate Azure DevOps organizations, projects, repos, and pipelines
- Understand agents, jobs, stages, steps, triggers, and artifacts
- Create and run a first YAML pipeline

## Session Plan

### Module 1: DevOps Foundations

- What DevOps means in practice
- Why CI/CD matters
- Shift-left testing and fast feedback
- Common pipeline failure patterns

### Module 2: Azure DevOps Core Services

- Organization versus project
- Azure Boards
- Azure Repos
- Azure Pipelines
- Azure Test Plans
- Azure Artifacts

### Module 3: Azure Pipelines YAML Basics

- Triggers
- Hosted agents
- Tasks and scripts
- Variables and secret handling
- Pipeline artifacts

### Module 4: Bootstrap And First Pipeline Walkthrough

- Run the bootstrap script
- Review the sample app structure
- Connect repo to pipeline
- Run build and unit tests
- Publish build output
- Review logs and rerun failed jobs

## Demo Flow

1. Run the bootstrap script against the workshop organization.
2. Inspect the generated Azure DevOps project and repository.
3. Create or review the basic YAML pipeline from the sample repository.
4. Explain each step in `azure-pipelines-basic.yml`.
5. Run the pipeline and inspect logs.

## Key Concepts To Emphasize

- A pipeline is versioned with the source code
- YAML is easier to review than click-based configuration
- Understanding the pipeline manually comes before AI-assisted generation
- Fast feedback matters more than complex automation on Day 1
- Pipeline failures are normal and should be debugged from logs and task boundaries

## Hands-On Lab

Use [workshop/labs/lab-1-first-pipeline.md](labs/lab-1-first-pipeline.md).

## End-Of-Day Deliverable

Every participant should finish with:

- A working CI pipeline
- A working Azure DevOps project and repo
- A successful build artifact
- A clear understanding of the pipeline execution model

## Instructor Debrief Questions

- What is the difference between CI and CD?
- Why use YAML instead of only classic pipelines?
- Which logs helped you most when something failed?