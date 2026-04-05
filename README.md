# Azure DevOps → AKS Deployment Workshop
### *End-to-End DevOps with GitHub Copilot Agentic DevOps*

---

## Workshop Overview

| | |
|---|---|
| **Duration** | 4 Hours |
| **Format** | Instructor-Led + Hands-On Labs |
| **Level** | L200 (Azure DevOps + AKS) · L100 (GitHub Copilot) |
| **Audience** | Developers, DevOps Engineers, Platform Engineers |

---

## What You Will Build

A complete end-to-end DevOps pipeline that:

1. **Builds** a containerized Node.js microservice application
2. **Tests** it automatically on every commit
3. **Publishes** a Docker image to Azure Container Registry (ACR) and npm packages to Azure Artifacts
4. **Deploys** to three environments: `dev` → `staging` → `production` on AKS
5. **Secures** the pipeline with Key Vault, branch policies, and approval gates
6. **Monitors** deployments with logs, Prometheus metrics, and Azure Monitor
7. **Tests** with Azure Test Plans and tracks progress with Dashboards
8. **Uses GitHub Copilot** as an AI-powered DevOps co-pilot

---

## Repository Structure

```
Fortis-Workshop/
├── README.md                        ← You are here
├── AGENDA.md                        ← 4-hour detailed agenda
│
├── sample-app/                      ← Sample Node.js microservice
│   ├── src/
│   │   ├── app.js
│   │   ├── routes/
│   │   └── tests/
│   ├── Dockerfile
│   ├── package.json
│   └── .dockerignore
│
├── k8s/                             ← Kubernetes manifests
│   ├── base/
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── hpa.yaml
│   │   └── configmap.yaml
│   └── overlays/
│       ├── dev/
│       ├── staging/
│       └── production/
│
├── pipelines/                       ← Azure DevOps YAML pipelines
│   ├── ci-pipeline.yml              ← Continuous Integration
│   ├── cd-pipeline.yml              ← Continuous Deployment
│   ├── multi-env-pipeline.yml       ← Full multi-env pipeline
│   ├── templates/
│   │   ├── build-template.yml
│   │   ├── deploy-template.yml
│   │   └── test-template.yml
│   └── variable-groups/
│       └── README-variable-groups.md
│
├── labs/                            ← Hands-on lab guides
│   ├── lab-00-admin-setup.md
│   ├── lab-01-setup.md
│   ├── lab-02-ci-pipeline.md
│   ├── lab-03-cd-aks.md
│   ├── lab-04-multi-environment.md
│   └── lab-05-ghcp-agentic.md
│
├── challenges/                      ← Challenge exercises
│   ├── challenge-01-pipeline.md
│   ├── challenge-02-security.md
│   └── challenge-03-agentic.md
│
├── demos/                           ← Facilitator demo scripts
│   ├── demo-setup.md
│   ├── demo-01-azure-devops-tour.md
│   ├── demo-02-pipeline-build.md
│   └── demo-03-ghcp-devops.md
│
└── ghcp-agentic/                    ← GitHub Copilot Agentic DevOps
    ├── 00-introduction.md
    ├── 01-copilot-in-vscode.md
    ├── 02-copilot-in-azure-devops.md
    ├── 03-agentic-pipeline-generation.md
    └── lab-ghcp-agentic.md
```

---

## Prerequisites

### For Participants

| Tool | Version | Notes |
|------|---------|-------|
| VS Code | Latest | With GitHub Copilot extension |
| Azure CLI | 2.55+ | `az --version` |
| kubectl | 1.28+ | `kubectl version` |
| Docker Desktop | Latest | Running locally |
| Node.js | 20+ | LTS recommended |
| Git | Latest | |

### Azure Resources (Pre-Provisioned)

- Azure DevOps Organization + Project
- Azure Kubernetes Service (AKS) cluster with 3 namespaces (`dev`, `staging`, `production`)
- Azure Container Registry (ACR) linked to AKS
- Azure Key Vault for secrets
- GitHub Copilot license (Business or Enterprise)

---

## Quick Start for Facilitators

```bash
# 1. Clone this repository into your Azure DevOps project
git clone <this-repo-url>

# 2. Complete labs/lab-00-admin-setup.md for greenfield or brownfield bootstrap
# 3. Use demo-setup.md as supporting facilitator pre-work if needed
# 4. Ask participants to begin with labs/lab-01-setup.md during kickoff
# 5. Walk through AGENDA.md module by module
```

### Recommended Lab Flow

- `labs/lab-00-admin-setup.md` -> admin-only pre-work before workshop day
- `labs/lab-01-setup.md` -> participant onboarding and access validation during kickoff
- `labs/lab-02-ci-pipeline.md` onward -> shared hands-on participant labs

---

## Sample Application: "InventoryAPI"

A Node.js REST API simulating an inventory management system with:
- `GET /api/products` — list products
- `GET /api/products/:id` — get product by ID
- `POST /api/products` — create product
- `GET /health` — health check endpoint
- `GET /metrics` — prometheus-compatible metrics

This app is intentionally simple so focus stays on the DevOps pipeline, not the code logic.

---

## Key Learning Outcomes

After this workshop, participants will be able to:

- [ ] Explain all core Azure DevOps components (Boards, Repos, Pipelines, Artifacts, Test Plans)
- [ ] Build a multi-stage CI/CD pipeline with approvals and gates
- [ ] Deploy containerized apps to AKS across dev/staging/production
- [ ] Implement pipeline security: service connections, variable groups, Key Vault integration
- [ ] Use GitHub Copilot to generate and explain pipeline YAML and K8s manifests
- [ ] Understand the concept of Agentic DevOps and AI-assisted workflows
