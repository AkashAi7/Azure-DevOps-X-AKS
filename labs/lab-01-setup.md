# Lab 01: Collaborator Setup and Azure DevOps Orientation

**Audience:** Workshop participants and collaborators  
**Duration:** 20 minutes  
**Module:** Kickoff  
**Objective:** Validate your local tools, confirm access to Azure DevOps and AKS, clone the workshop repo, and verify you are ready for the remaining labs.

---

## Before You Start

This lab assumes the workshop admin has already completed the environment bootstrap in `labs/lab-00-admin-setup.md`.

Before you begin, make sure you have these values from the admin or facilitator:

- Azure subscription ID for the workshop
- Azure DevOps organization URL
- Azure DevOps project URL
- Azure Repos clone URL for `Fortis-Workshop`
- AKS resource group name
- AKS cluster name
- ACR name if you want to inspect published images later

If any of these are missing, stop here and ask the admin before moving forward.

---

## Task 1: Verify Your Local Tooling

Run these commands in your terminal:

```bash
# 1. Azure CLI
az --version
# Expected: azure-cli 2.55+

# 2. kubectl
kubectl version --client
# Expected: Client Version: v1.28+

# 3. Docker
docker --version
docker run hello-world
# Expected: "Hello from Docker!"

# 4. Node.js
node --version
npm --version
# Expected: v18+ or v20+

# 5. Git
git --version
# Expected: git version 2.40+
```

If any tool is missing, refer to the [prerequisites install guide](../demos/demo-setup.md).

---

## Task 2: Log in to Azure

```bash
# Log in to Azure CLI
az login

# Set the subscription for this workshop
az account set --subscription "<subscription-id-provided-by-facilitator>"

# Verify
az account show --query "{Name:name, ID:id}" -o table
```

---

## Task 3: Connect to the AKS Cluster

```bash
# Get AKS credentials (ask facilitator for values)
az aks get-credentials \
  --resource-group <aks-resource-group> \
  --name <aks-cluster-name> \
  --overwrite-existing

# Verify connection
kubectl get nodes
# Expected: 3 nodes in Ready state

# Check the pre-created namespaces
kubectl get namespaces
# Expected: dev, staging, production namespaces exist
```

---

## Task 4: Confirm Azure DevOps Access and Explore the Project

1. Open your browser and navigate to the workshop Azure DevOps project URL provided by the admin
2. Click through each section in the left navigation:

| Section | What to look for |
|---------|-----------------|
| **Boards** | Open work items, active sprint |
| **Repos** | `Fortis-Workshop` repository with all files |
| **Pipelines** | Pre-imported CI and CD pipelines |
| **Artifacts** | `inventory-api-packages` feed |
| **Test Plans** | Existing test plan for InventoryAPI |

3. Navigate to **Pipelines -> Library** and confirm you can see the shared variable groups.
4. Navigate to **Project Settings -> Service connections** only if your facilitator wants you to verify access. Most participants only need to confirm the connections exist; they do not need to edit them.

---

## Task 5: Azure Boards — Orient and Assign Yourself

The admin has already seeded the board with work items. This task gets you oriented and sets you up as an active collaborator before the coding labs begin.

### 5.1 Understand the work item hierarchy

Navigate to **Boards -> Backlogs** and expand the backlog tree. You should see:

```
Epic
└── Feature: CI Pipeline - Build, Test & Publish
│   └── User Story: As a developer, I can trigger an automated build on every commit
│       ├── Task: Create ci-pipeline.yml in Azure DevOps
│       ├── Task: Add ESLint lint stage
│       ├── Task: Add Jest unit-test stage with coverage threshold
│       └── Task: Build Docker image and push to ACR
└── Feature: CD Pipeline - Multi-Environment Deployment
│   └── User Story: As an ops engineer, I can promote a release through dev -> staging -> production
│       ├── Task: Deploy to dev namespace on every successful CI run
│       ├── Task: Add manual approval gate before staging deployment
│       ├── Task: Add production gate with rollback strategy
│       └── Task: Configure HPA and resource limits per environment
└── Feature: Observability - Health, Metrics & Alerts
└── Feature: GitHub Copilot Agentic DevOps
```

If the backlog looks empty, check the **Area** and **Iteration** filters at the top — make sure they are set to show all items.

### 5.2 Assign yourself to a task

1. In the backlog, expand the CI Pipeline feature tree
2. Click on any Task that is currently **unassigned**
3. In the work item detail panel that opens on the right:
   - Set **Assigned To** to your name
   - Set **State** to **Active**
   - Click **Save**

> Pick one task that matches the lab you will work on first. Each participant should own a distinct task to avoid conflicts.

### 5.3 View your sprint board

1. Go to **Boards -> Boards** (the Kanban view)
2. Confirm your assigned task appears in the **Active** column
3. Familiarise yourself with the three default columns: **New**, **Active**, **Closed**

### 5.4 Create a personal task (optional)

If you want to track your own setup work:

1. Click **+ New Work Item** at the top of any backlog column
2. Type a title such as `Set up local dev environment — <your name>`
3. Set Type to **Task**
4. Assign it to yourself and set State to **Active**
5. Link it to the CI Pipeline User Story using **Add link -> Parent**

### 5.5 Link a commit to a work item (preview — you will do this again in Lab 02)

Azure DevOps automatically detects work item IDs in commit messages when you use the `#<id>` syntax.

Note the ID of one of your assigned tasks (visible in the backlog list and in the URL of the work item detail panel). You will reference it when you make your first commit in Lab 02:

```bash
git commit -m "feat: add CI trigger - fixes #<work-item-id>"
```

---

## Task 6: Clone the Repository

```bash
# Clone using the Azure Repos URL provided by the admin or from Repos -> Clone
git clone <azure-repos-clone-url>

cd Fortis-Workshop

# Install sample app dependencies
cd sample-app
npm install
npm test
# Expected: All tests pass
```

---

## Task 7: Run the App Locally

```bash
cd sample-app
npm start
# Expected: "InventoryAPI v1.0.0 running on port 3000 [local]"

# In a new terminal, test the endpoints:
curl http://localhost:3000/health
# Expected: {"status":"healthy","version":"1.0.0","environment":"local",...}

curl http://localhost:3000/api/products
# Expected: {"count":4,"products":[...]}

curl -X POST http://localhost:3000/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Product","category":"Test","quantity":5,"price":9.99}'
# Expected: 201 Created with the new product

# Stop the server with Ctrl+C
```

---

## Task 8: Run the App with Docker

```bash
cd sample-app

# Build the image
docker build -t inventory-api:local .

# Run the container
docker run -p 3000:3000 \
  -e ENVIRONMENT=local-docker \
  -e APP_VERSION=dev \
  inventory-api:local

# Test it (in another terminal)
curl http://localhost:3000/health
# Verify ENVIRONMENT field shows "local-docker"

# Stop with Ctrl+C
```

---

## Collaboration Expectations for the Remaining Labs

From this point onward, participants are expected to work inside the shared Azure DevOps project and shared AKS environment.

During the next labs, you will typically:

- Move work items from **Active** to **Closed** as you complete tasks
- Reference work item IDs in commit messages using `#<id>` syntax
- Create commits and push changes to Azure Repos
- Trigger or inspect Azure DevOps pipelines
- Review deployment history in Azure DevOps environments
- Validate workloads running in the `dev`, `staging`, and `production` namespaces
- Collaborate without reconfiguring the underlying Azure platform

If you need admin-only changes such as new service connections, namespace creation, or project-level security changes, ask the workshop admin instead of changing the environment yourself.

---

## ✅ Lab 01 Completion Checklist

- [ ] Azure CLI logged in and subscription set
- [ ] kubectl connected to AKS cluster, can see 3 nodes
- [ ] Explored all 5 Azure DevOps sections
- [ ] Boards backlog loaded and work item hierarchy visible
- [ ] Assigned yourself to at least one task and set it to Active
- [ ] Noted the work item ID you will reference in Lab 02
- [ ] Repository cloned and npm tests pass
- [ ] App runs locally (npm start)
- [ ] App runs in Docker container

**Raise your hand if you're stuck — do not skip ahead without completing this lab!**

---

## Bonus (If You Finish Early)
Explore the AKS cluster more:
```bash
# See what's already running on the cluster
kubectl get pods --all-namespaces

# Look at the dev namespace
kubectl describe namespace dev

# Check ACR images (ask facilitator for ACR name)
az acr repository list --name <acr-name> -o table
```
