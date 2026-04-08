# Workshop Agenda: Azure DevOps → AKS Deployment
## *4-Hour Instructor-Led Workshop*

---

```
Total: 4 hours (240 minutes)
Format: 60% instruction/demo + 40% hands-on labs
```

---

## Timeline at a Glance

| Time | Module | Topic | Format |
|------|--------|-------|--------|
| 10:00 – 10:20 AM | **Kickoff** | Intro, goals, environment check | Lecture |
| 10:20 – 10:55 AM | **Module 1** | Azure DevOps – Full Feature Tour | Demo |
| 10:55 – 11:30 AM | **Module 2** | CI Pipeline – Build, Test, Publish | Demo + Lab |
| 11:30 – 11:40 AM | ☕ **Break** | | |
| 11:40 AM – 12:30 PM | **Module 3** | CD Pipeline – Deploy to AKS (Multi-Env) | Demo + Lab |
| 12:30 – 1:30 PM | 🍽️ **Lunch Break** | | |
| 1:30 – 2:00 PM | **Module 4** | Advanced Features: Gates, Approvals, Security | Demo + Lab |
| 2:00 – 2:45 PM | **Module 5** | Agentic DevOps with GitHub Copilot *(L100)* | Demo + Lab |
| 2:45 – 3:00 PM | **Wrap-up** | Challenges, Q&A, Resources | Discussion |

---

## Kickoff (10:00 – 10:20 AM IST) — 20 minutes

### Objectives
- Welcome participants and set expectations
- Validate all environments are working
- Confirm the pre-workshop admin setup is already complete
- Walk through what will be built today

### Facilitator Notes
- Do a quick poll: who has used Azure DevOps before? Who has deployed to AKS?
- Screen-share the architecture diagram
- Confirm the environment owner has already completed `labs/lab-00-admin-setup.md`
- Ask participants to use `labs/lab-01-setup.md` for their collaborator onboarding steps
- Confirm everyone can log in to Azure DevOps and VS Code

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Developer Workstation                         │
│  VS Code + GitHub Copilot  →  git push  →  Azure Repos             │
└─────────────────────────────────────┬───────────────────────────────┘
                                      │ trigger
                        ┌─────────────▼──────────────┐
                        │     Azure DevOps Pipelines  │
                        │  ┌──────────┐ ┌──────────┐ │
                        │  │  CI Job  │ │  CD Job  │ │
                        │  │ build    │ │ dev      │ │
                        │  │ test     │ │ staging  │ │
                        │  │ scan     │ │ prod     │ │
                        │  │ publish  │ │          │ │
                        │  └────┬─────┘ └──────────┘ │
                        └───────│────────────────────┘
                                │
                ┌───────────────▼───────────────┐
                │   Azure Container Registry    │
                │   myacr.azurecr.io/inventoryapi│
                └───────────────┬───────────────┘
                                │
        ┌───────────────────────┼────────────────────────┐
        │                       │                        │
┌───────▼──────┐  ┌─────────────▼────────┐  ┌──────────▼──────────┐
│  AKS: dev    │  │   AKS: staging       │  │  AKS: production    │
│  namespace   │  │   namespace          │  │  namespace          │
│  1 replica   │  │   2 replicas         │  │  3 replicas + HPA   │
└──────────────┘  └──────────────────────┘  └─────────────────────┘
```

---

## Module 1: Azure DevOps – Full Feature Tour (10:20 – 10:55 AM IST) — 35 minutes

### Learning Objectives
- Understand all 5 Azure DevOps services
- Navigate the Azure DevOps portal confidently
- Know where each feature fits in a DevOps workflow

### Content Breakdown

#### 1.1 Azure DevOps Overview (5 min)
- What is Azure DevOps? (SaaS DevOps platform)
- Organizations, Projects, Permissions model
- Integration with Azure, GitHub, third-party tools
- Azure DevOps vs GitHub – when to use what

#### 1.2 Azure Boards (8 min)
**Demo: Create and manage a sprint**

Key concepts:
- Work items: Epics → Features → User Stories → Tasks → Bugs
- Backlogs and Sprint planning
- Kanban boards vs Taskboards
- **Queries**: Save custom work item queries
- **Dashboards**: Real-time team metrics
- Linking work items to commits and PRs

```
Demo Steps:
1. Create an Epic: "InventoryAPI v1.0 Release"
2. Create 3 User Stories under it
3. Assign to sprint, set capacity
4. Show Kanban board
5. Show Dashboard with burndown chart
```

#### 1.3 Azure Repos (8 min)
**Demo: Code repository features**

Key concepts:
- Git repositories (unlimited private repos)
- **Branch policies**: Require PR, min reviewers, build validation
- **Pull Requests**: Code review workflow with comments, suggestions
- Branch strategies: GitFlow, trunk-based (explain both)
- Protected branches and merge strategies
- Semantic versioning tags

```
Demo Steps:
1. Show repository with branch policies configured
2. Create a feature branch
3. Make a small commit
4. Open a Pull Request – show required reviewers, build policy
5. Show "suggest changes" in PR review
```

#### 1.4 Azure Pipelines (8 min — deeper dive in Module 2 & 3)
**Overview only**

Key concepts:
- YAML vs Classic (GUI) pipelines — YAML is the standard
- Agents: Microsoft-hosted vs self-hosted
- Stages, Jobs, Steps, Tasks
- Triggers: CI, PR, scheduled, manual
- Pipeline templates and reuse
- Environments and deployment strategies

#### 1.5 Azure Artifacts (5 min)
**Demo: Package feeds**

Key concepts:
- Universal packages, npm, NuGet, Maven, Python feeds
- Upstream sources (proxy public registries)
- Package promotion between feeds
- Connecting pipelines to Artifacts

```
Demo Steps:
1. Show an Artifacts feed
2. Show a published package
3. Explain how CI pipeline publishes to feed
```

#### 1.6 Azure Test Plans (3 min)
Key concepts:
- Manual test cases and test suites
- Exploratory testing
- Test plans linked to User Stories
- Integration with pipeline test results

---

## Module 2: CI Pipeline – Build, Test, Publish (10:55 – 11:30 AM IST) — 35 minutes

### Learning Objectives
- Write a multi-job CI pipeline in YAML
- Run unit tests and publish test results
- Build and push a Docker image to ACR
- Use pipeline templates for reusability
- Understand agents and agent pools

### Demo (15 min): Live CI Pipeline Build

```
Demo Steps:
1. Open pipelines/ci-pipeline.yml in VS Code
2. Walk through each section explaining YAML structure
3. Show trigger configuration (branch + path filters)
4. Show variables block and variable groups
5. Execute the pipeline live — watch it run
6. Show test results tab, code coverage
7. Show published artifact in ACR
8. Show pipeline run history and logs
```

**Key pipeline concepts to highlight:**
- `pool` — which agent runs this job
- `strategy: matrix` — run tests on multiple Node versions
- `condition:` — conditional steps
- `dependsOn:` — job dependencies
- `publishTestResults` task
- `Docker@2` task with `buildAndPush`
- Pipeline caching with `Cache@2`

### Lab 2 (20 min): **Build Your First CI Pipeline**
> See `labs/lab-02-ci-pipeline.md`

Participants will:
1. Fork the sample app branch
2. Import `ci-pipeline.yml` into their project
3. Configure the ACR service connection
4. Trigger a pipeline run by pushing a commit
5. Observe test results and container image in ACR
6. Publish an npm package to Azure Artifacts feed
7. Explore Artifacts feed features: upstream sources, promotion, permissions

---

## Break ☕ (11:30 – 11:40 AM IST) — 10 minutes

---

## Module 3: CD Pipeline – Deploy to AKS (Multi-Environment) (11:40 AM – 12:30 PM IST) — 50 minutes

### Learning Objectives
- Deploy to AKS using Azure DevOps Environments
- Implement promotion gates between environments
- Use Kubernetes manifests with environment-specific overlays
- Configure deployment strategies: rolling update, blue-green
- Monitor deployments with rollback capability

### Demo (20 min): Multi-Stage Deployment

```
Demo Steps:
1. Show k8s/ folder structure (base + overlays)
2. Walk through multi-env-pipeline.yml
3. Show Environments page in Azure DevOps
   - Resources (Kubernetes namespaces)
   - Deployment history
   - Approvals and checks
4. Trigger full pipeline: build → dev → staging → prod
5. Show gate: "staging must succeed 30 min before prod"
6. Show approval gate for production
7. Demonstrate rollback scenario
```

**Key concepts to cover:**
- `environment:` keyword in YAML
- `deployment:` job type vs `job:` type
- `strategy: runOnce` vs `strategy: rolling` vs `blueGreen`
- Kubernetes Service Connection setup
- `kubectl` task vs `KubernetesManifest@1` task
- Image pull secrets and ACR integration with AKS
- Namespace-based environment separation
- **Pre/post deployment gates**: invocation of Azure Monitor, REST API checks
- **Approval gates**: required human approval before production

### Lab 3 (30 min): **Deploy to AKS Across Dev/Staging/Prod**
> See `labs/lab-03-cd-aks.md`

Participants will:
1. Connect their AKS namespaces as Azure DevOps Environments
2. Configure the multi-stage pipeline
3. Set up an approval for production deployment
4. Deploy and watch the rollout
5. Use `kubectl rollout status` to verify
6. Simulate a bad deploy and perform rollback
7. Explore Ingress resources and understand per-environment routing
8. Create and inspect Kubernetes Secrets
9. Monitor the deployment: pod logs, resource usage, Prometheus metrics
10. Review deployment history and cluster events

---

## Module 4: Advanced Azure DevOps Features (1:30 – 2:00 PM IST) — 30 minutes

### Learning Objectives
- Implement pipeline security best practices
- Use Variable Groups and Key Vault integration
- Configure branch policies with build validation
- Implement quality gates with test thresholds
- Use Pipeline Decorators and Extensions

### Content Breakdown

#### 4.1 Security – Variable Groups & Key Vault (8 min)
**Demo: Secrets management**

- Creating and using Variable Groups
- Linking Variable Groups to Azure Key Vault
- Using `$(VariableName)` syntax in pipelines
- Never hardcode secrets — live demonstration of what NOT to do
- Service connections: types, scopes, security

```yaml
# WRONG - never do this
variables:
  acrPassword: "myS3cr3tP@ssw0rd"  # ← NEVER!

# RIGHT - use variable groups or Key Vault
variables:
  - group: InventoryAPI-Secrets   # linked to Key Vault
```

#### 4.2 Branch Policies & PR Validation (7 min)
**Demo: Enforced quality gates**

- Minimum reviewer count
- Required builds (PR triggers CI)
- Comment resolution policy
- Work item linking requirement
- Auto-complete and squash merge

#### 4.3 Pipeline Templates & YAML Reuse (8 min)
**Demo: Template extraction**

- `extends:` template pattern
- `parameters:` for template inputs
- Centralized pipeline templates in a separate repo
- Template expressions: `${{ if eq(...) }}`
- Step templates, job templates, stage templates

#### 4.4 Azure Test Plans — Hands-On (7 min)
- Creating test plans, suites, and test cases
- Executing manual test cases with pass/fail steps
- Linking test cases to User Stories for traceability
- Viewing test results charts and trends
- Exploratory testing with the Test & Feedback extension

#### 4.5 Azure DevOps Dashboards (5 min)
- Creating a team dashboard
- Adding pipeline status, test trend, and work item chart widgets
- Using dashboards for project health visibility

#### 4.6 Pipeline Notifications (3 min)
- Setting up pipeline failure notifications
- Service hooks for Teams/Slack/webhooks integration

### Lab 4 (integrated): **Configure Branch Policies + Secure a Pipeline + Test Plans + Dashboard**
> Quick exercises embedded within Module 4 demo
> See `labs/lab-04-multi-environment.md`

---

## Module 5: Agentic DevOps with GitHub Copilot *(L100)* (2:00 – 2:45 PM IST) — 45 minutes

### Learning Objectives
*(L100 — No prior Copilot experience assumed)*

- Understand what GitHub Copilot is and how it works
- Use Copilot in VS Code to accelerate DevOps tasks
- Use Copilot to generate pipeline YAML and K8s manifests
- Understand the concept of "Agentic DevOps"
- Use Copilot in Azure DevOps (PR summaries, work item generation)

### Content Breakdown

#### 5.1 What is GitHub Copilot? (8 min)

- AI coding assistant powered by large language models
- Available in: VS Code, Visual Studio, JetBrains IDEs, CLI, GitHub.com
- **Copilot Individual vs Business vs Enterprise**
- How it works: context window, file context, instructions
- What it can do today vs what it cannot (hallucinations, limitations)
- GitHub Copilot = code completion + chat + agent mode

#### 5.2 Copilot in VS Code — Hands-On Introduction (10 min)
**Live Demo + Participants follow along**

```
Demo Tasks:
1. Open VS Code with Copilot installed
2. Show inline completions: start typing a Dockerfile line
3. Open Copilot Chat (Ctrl+Shift+I)
4. Ask: "Explain this Kubernetes deployment YAML"
5. Ask: "Generate a health check probe for Node.js app on port 3000"
6. Show /fix command on a broken YAML
7. Show @workspace agent: "What does this pipeline do?"
```

> **Key tip for L100 participants:** Think of Copilot Chat like a senior colleague 
> who has read all the docs. Ask naturally. It won't judge bad questions.

#### 5.3 Agentic DevOps — The New Paradigm (7 min)

**What is Agentic DevOps?**

Traditional DevOps + AI agents = tasks that used to require manual steps now 
happen automatically with AI orchestration.

```
Traditional DevOps Workflow:
Developer writes code → manually writes YAML pipeline → manually writes K8s YAML 
→ manually reviews PR → manually updates work items

Agentic DevOps Workflow:
Developer writes code → Copilot generates pipeline YAML → Copilot generates K8s YAML 
→ Copilot summarizes PR → Copilot suggests work item updates
```

**Current Agentic Copilot capabilities:**
- **Copilot Autofix** — automatically fixes security vulnerabilities in PRs
- **Copilot PR Summary** — generates PR descriptions from diff
- **Copilot for Azure DevOps** — AI assistance in Boards and Pipelines
- **GitHub Copilot Agent Mode** — multi-step task execution in VS Code
- **Copilot Workspace** (GitHub.com) — AI-driven issue → code → PR workflow

#### 5.4 Copilot for Azure DevOps Integration (10 min)
**Demo: AI in Azure DevOps**

```
Demo Steps:
1. Open an Azure DevOps Pull Request
   → Show "Summarize with Copilot" button
   → Show AI-generated PR description
   
2. Open Azure Boards
   → Create a work item with Copilot assistance
   → Show "Fill in details with Copilot"
   
3. Pipeline Failure Analysis
   → Show a failed pipeline run
   → Ask Copilot: "Why did this pipeline step fail?"
   → Show AI explanation and suggested fix
   
4. YAML Generation in VS Code
   → Open empty pipeline file
   → Ask Copilot: "Create an Azure DevOps pipeline to build a Docker image
      and push to ACR, then deploy to AKS dev namespace"
   → Show the generated YAML
   → Iterate: "Add a staging deployment stage with a manual approval gate"
```

#### 5.5 Copilot Agent Mode – Live Demo (10 min)
**The most powerful feature for L100 participants to see**

```
Demo Steps:
1. Open VS Code Agent Mode (Ctrl+Shift+I → switch to Agent)
2. Give task: "I need to add a readiness probe and liveness probe to all 
   my Kubernetes deployments in the k8s/ folder. Make sure they hit /health 
   on port 3000 with appropriate timing."
3. Watch Copilot: read files → propose changes → apply changes
4. Review changes in diff view
5. Ask follow-up: "Now create a pipeline step that validates all K8s manifests 
   before deploying"
```

### Lab 5 (15 min): **Your First Agentic DevOps Task**
> See `labs/lab-05-ghcp-agentic.md`

Participants will:
1. Install and verify GitHub Copilot in VS Code
2. Use Chat to explain the sample app pipeline
3. Use Agent mode to add a new environment variable to the K8s manifest
4. Generate a short deployment runbook using Copilot
5. (Stretch) Use Copilot to fix a broken pipeline YAML

---

## Wrap-up & Challenges (2:45 – 3:00 PM IST) — 15 minutes

### Quick Recap (5 min)
- Azure DevOps services recap: Boards → Repos → Pipelines → Artifacts → Test Plans
- CI/CD flow review: commit → build → test → deploy (3 envs)
- GitHub Copilot: code completion, chat, agent mode, Azure DevOps integration
- Key takeaway: DevOps is a culture + toolchain + AI amplification

### Challenge Exercises Introduced (5 min)
> Participants take these home / complete in remaining days of their sprint

- **Challenge 1**: Add a security scanning stage (Trivy/OWASP ZAP) to the CI pipeline
- **Challenge 2**: Implement blue-green deployment for the production environment
- **Challenge 3**: Use Copilot Agent Mode to generate a complete observability stack (Prometheus + Grafana K8s manifests)
- **Challenge 4**: Use MCP servers with Copilot to build an automated incident-response workflow that queries Azure DevOps and AKS in a single prompt (see `labs/lab-06-mcp-devops-aks.md`)

### Resources & Next Steps (5 min)

| Resource | Link Type | Topic |
|----------|-----------|-------|
| Azure DevOps Documentation | Microsoft Docs | Full reference |
| AKS Best Practices | Microsoft Docs | Production hardening |
| GitHub Copilot Docs | GitHub Docs | Features and setup |
| Azure DevOps Labs | labs.azure.com | Additional hands-on labs |
| GitHub Skills | skills.github.com | Copilot learning paths |
| Azure DevOps MCP Server | github.com/microsoft/azure-devops-mcp | MCP server for Azure DevOps |
| Azure MCP Server | github.com/Azure/azure-mcp | MCP server for Azure (AKS) |
| MCP Specification | spec.modelcontextprotocol.io | Open MCP standard |

### Q&A

---

## Facilitator Checklist

### 1 Week Before
- [ ] Provision AKS cluster with dev/staging/production namespaces
- [ ] Create ACR and link to AKS with `AcrPull` role
- [ ] Import pipelines into Azure DevOps
- [ ] Assign GitHub Copilot licenses to participants
- [ ] Send prerequisite email with tool installation links

### 1 Day Before
- [ ] Run through all 5 labs end-to-end
- [ ] Verify all service connections work
- [ ] Test the sample app deploys successfully
- [ ] Pre-warm the pipeline (first run is slower)
- [ ] Verify Key Vault secrets are configured

### Day Of
- [ ] Start with the architecture diagram on screen
- [ ] Keep `demo-setup.md` open in second monitor
- [ ] Have a "golden" backup pipeline run ready if live demos fail
- [ ] Time checks at: 10:55 AM, 11:30 AM, 12:30 PM, 2:00 PM, 2:45 PM (IST)
