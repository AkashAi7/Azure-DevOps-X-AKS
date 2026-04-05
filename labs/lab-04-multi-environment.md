# Lab 04: Advanced Azure DevOps — Security, Policies & Templates

**Duration:** 20 minutes (integrated with Module 4)  
**Module:** Module 4  
**Objective:** Secure a pipeline with Key Vault secrets, apply branch policies, and practice extracting pipeline templates for reuse.

---

## Part A: Secure Secrets with Key Vault Integration

### A1: Explore the Key Vault

```bash
# List secrets in the workshop Key Vault
az keyvault secret list \
  --vault-name kv-workshop-01 \
  --query "[].{Name:name}" \
  -o table
```

### A2: Link Variable Group to Key Vault

1. Go to **Pipelines** → **Library** → `InventoryAPI-Secrets`
2. Enable the **Link secrets from Azure Key Vault** toggle
3. Select subscription: your workshop subscription
4. Select Key Vault: `kv-workshop-01`
5. Click **+ Add** to add secrets:
   - `acr-admin-password`
6. Click **Save**

### A3: Add a Step Using the Secret

Add this to the CI pipeline (after Docker login step) to demonstrate a secret in use:

```yaml
# In ci-pipeline.yml, add to the Build stage:
- script: |
    # This prints *** for the password — never revealed in logs
    echo "ACR password is available: $(ACR_ADMIN_PASSWORD)"
    # Verify ACR login works with the secret
    docker login $(ACR_NAME).azurecr.io \
      --username $(ACR_NAME) \
      --password $(ACR_ADMIN_PASSWORD)
  displayName: 'Verify ACR auth with Key Vault secret'
  env:
    ACR_ADMIN_PASSWORD: $(ACR_ADMIN_PASSWORD)  # mapped from variable group
```

> **Key Point:** The `ACR_ADMIN_PASSWORD` will appear as `***` in pipeline logs even in `echo` statements.

---

## Part B: Branch Policies

### B1: Configure Branch Policies for `main`

1. Go to **Repos** → **Branches**
2. Find `main`, click **. . .** → **Branch policies**
3. Configure the following:

| Policy | Setting |
|--------|---------|
| Require a minimum number of reviewers | ✅ Minimum: 1, Allow requestors to approve their own changes: ❌ |
| Check for linked work items | ✅ Required |
| Check for comment resolution | ✅ Required |
| Limit merge types | ✅ Squash merge only |
| Build validation | ✅ Add `InventoryAPI-CI` as required build |

4. Click **Save changes**

### B2: Test the Branch Policy

```bash
# Create a feature branch and push a change
git checkout -b feature/test-branch-policy
echo "// branch policy test" >> sample-app/src/app.js
git add .
git commit -m "test: verify branch policy is enforced"
git push origin feature/test-branch-policy
```

1. Try to create a PR to `main`
2. Observe: the CI pipeline is required before merging
3. Observe: the PR requires at least 1 reviewer
4. Observe: cannot directly push to `main` (try it!)

```bash
# Try to push directly to main — this should be blocked
git checkout main
echo "// direct push test" >> sample-app/src/app.js
git add .
git commit -m "test: direct push"
git push origin main
# Expected: rejected because of branch policy
```

---

## Part C: Pipeline Template Extraction

### C1: Understand the Existing Templates

Open and examine the three template files:
- `pipelines/templates/test-template.yml`
- `pipelines/templates/build-template.yml`
- `pipelines/templates/deploy-template.yml`

Note how they use `parameters:` to accept inputs and how the parent pipeline passes values:

```yaml
# In multi-env-pipeline.yml
- template: templates/test-template.yml
  parameters:
    nodeVersions:
      - '20'
      - '22'
    workingDir: 'sample-app'
```

### C2: Create a New Template Step

Create `pipelines/templates/smoke-test-template.yml`:

```yaml
parameters:
  - name: apiBaseUrl
    type: string
  - name: environment
    type: string

steps:
- script: |
    echo "Running smoke tests against ${{ parameters.environment }}"
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${{ parameters.apiBaseUrl }}/health)
    if [ "${HTTP_STATUS}" != "200" ]; then
      echo "❌ Health check FAILED for ${{ parameters.environment }}: HTTP ${HTTP_STATUS}"
      exit 1
    fi
    echo "✅ Health check PASSED for ${{ parameters.environment }}"
  displayName: 'Smoke test — ${{ parameters.environment }}'
```

### C3: Use the New Template in the CD Pipeline

Add a smoke test after the dev deployment in `multi-env-pipeline.yml`:

```yaml
# After the DeployDev stage, add:
- stage: SmokeTestDev
  displayName: '🧪 Smoke Test DEV'
  dependsOn: DeployDev
  jobs:
  - job: SmokeTest
    steps:
    - template: templates/smoke-test-template.yml
      parameters:
        apiBaseUrl: 'http://dev.inventory-api.workshop.local'
        environment: 'dev'
```

Commit and push — watch the new stage appear in the pipeline!

---

## Part D: Azure Test Plans — Hands-On

Azure Test Plans let you create, manage, and execute manual and exploratory test cases linked to your work items.

### D1: Navigate to Test Plans

1. In Azure DevOps, click **Test Plans** in the left navigation
2. You should see a pre-created test plan: **InventoryAPI Smoke Tests** (created during admin setup)
3. If no test plan exists, create one:
   - Click **+ New Test Plan**
   - Name: `InventoryAPI Smoke Tests`
   - Area Path: select the project root
   - Iteration: select the current sprint
   - Click **Create**

### D2: Create a Test Suite and Test Cases

1. In the test plan, click **+ New Suite** → **Static suite**
2. Name: `Health Endpoint Tests`
3. Inside the new suite, click **+ New Test Case** and create two test cases:

**Test Case 1: Health Endpoint Returns 200**

| # | Step | Expected Result |
|---|------|----------------|
| 1 | Open a terminal and run `curl http://<dev-url>/health` | HTTP 200 response |
| 2 | Verify the JSON response body | Contains `"status": "healthy"` and `"environment": "dev"` |
| 3 | Check that `version` field is present | Version string matches the deployed image tag |

**Test Case 2: Products API Returns Data**

| # | Step | Expected Result |
|---|------|----------------|
| 1 | Run `curl http://<dev-url>/api/products` | HTTP 200 response |
| 2 | Verify the response is a JSON array | Array contains at least 1 product object |
| 3 | Check each product has `id`, `name`, `price` fields | All required fields present |

4. Click **Save & Close** after each test case

### D3: Run a Test Case

1. Select **Test Case 1** in the test suite
2. Click **Run** (play button in the toolbar)
3. The Test Runner opens in a new window
4. For each step:
   - Perform the action described
   - Click **Pass** ✅ or **Fail** ❌
   - Add a comment if the step fails
5. After all steps, click **Save and close**

### D4: Link a Test Case to a Work Item

1. Open **Test Case 1**
2. Click **Links** tab
3. Click **+ Add link** → **Existing item**
4. Link type: **Tests** (or **Tested By**)
5. Search for the User Story: *"As a developer, I can trigger an automated build on every commit"*
6. Click **OK** → **Save**

> **Why this matters:** Linking test cases to User Stories gives you traceability — you can see which stories have been tested and which have not.

### D5: View Test Results and Charts

1. Go to **Test Plans** → **Charts** tab
2. Click **+ New** → **Test case readiness**
   - This shows how many test cases are Ready vs In Progress vs Design
3. Click **+ New** → **Test results trend**
   - This shows pass/fail trends over time
4. Go to **Runs** tab to see all test run history

### D6: Exploratory Testing (Optional)

1. Install the **Test & Feedback** browser extension from the Azure DevOps Marketplace
2. Click the extension icon in your browser toolbar
3. Connect it to your Azure DevOps project
4. Click **Start session** → navigate your app in the browser
5. Take screenshots, annotate bugs, and file work items directly from the browser
6. End the session — all findings are saved as work items

---

## Part E: Create an Azure DevOps Dashboard

Dashboards give your team a single-pane view of project health: pipeline status, test results, work item progress, and deployment metrics.

### E1: Create a New Dashboard

1. In Azure DevOps, click **Overview** → **Dashboards**
2. Click **+ New Dashboard**
3. Name: `InventoryAPI — Team Dashboard`
4. Click **Create**

### E2: Add Pipeline Status Widget

1. Click **Edit** (pencil icon)
2. Click **+ Add widget**
3. Search for **Build History** → click **Add**
4. Configure:
   - Pipeline: `InventoryAPI-CI`
   - Show last: 10 builds
5. Click **Save**

### E3: Add Test Results Trend Widget

1. Click **+ Add widget**
2. Search for **Test Results Trend** → click **Add**
3. Configure:
   - Pipeline: `InventoryAPI-CI`
   - Period: Last 14 days
4. Click **Save**

### E4: Add Work Item Chart Widget

1. First create a shared query:
   - Go to **Boards** → **Queries** → **+ New query**
   - Set: Type = Task, State = Active OR New
   - **Save as**: `Active Workshop Tasks` (save to Shared Queries)
2. Back on the Dashboard, click **+ Add widget**
3. Search for **Chart for Work Items** → click **Add**
4. Configure:
   - Query: `Active Workshop Tasks`
   - Chart type: **Pie chart** by Assigned To
5. Click **Save**

### E5: Add a Deployment Status Widget

1. Click **+ Add widget**
2. Search for **Deployment Status** → click **Add**
3. Configure:
   - Pipeline: `InventoryAPI-CD`
   - Environments: Dev, Staging, Production
4. Click **Save**

### E6: Review Your Dashboard

Your dashboard should now show:

```
┌─────────────────────────┬──────────────────────────┐
│  CI Build History       │  Test Results Trend      │
│  (last 10 runs)         │  (pass/fail over time)   │
├─────────────────────────┼──────────────────────────┤
│  Active Tasks (Pie)     │  Deployment Status       │
│  (by assigned person)   │  (dev/staging/prod)      │
└─────────────────────────┴──────────────────────────┘
```

> **Tip:** Pin this dashboard as a tab in your Teams channel for real-time project visibility.

---

## Part F: Pipeline Notifications (Quick Setup)

### F1: Set Up Pipeline Failure Notifications

1. Go to **Project Settings** → **Notifications**
2. Click **+ New subscription**
3. Category: **Build**
4. Template: **A build fails**
5. Deliver to: your email address
6. Filter: Pipeline = `InventoryAPI-CI`
7. Click **Save**

### F2: Service Hooks (Concept)

For integrating with Microsoft Teams, Slack, or webhooks:

1. Go to **Project Settings** → **Service hooks**
2. Click **+ Create subscription**
3. Select a target: **Microsoft Teams**, **Slack**, **Web Hooks**, etc.
4. Select an event: **Build completed**, **Release deployment completed**, etc.
5. Configure the target (e.g., Teams webhook URL)

> You don't need to set this up now — just know it exists for when your team needs automated notifications.

---

## ✅ Lab 4 Completion Checklist

- [ ] `InventoryAPI-Secrets` variable group linked to Key Vault
- [ ] Secret (`ACR_ADMIN_PASSWORD`) shown as `***` in pipeline logs
- [ ] Branch policies applied to `main`: reviewer required + build validation
- [ ] Direct push to `main` is blocked
- [ ] Existing pipeline templates reviewed and understood
- [ ] (Stretch) New `smoke-test-template.yml` created and used
- [ ] Test plan created with test suite and test cases
- [ ] At least one test case executed with pass/fail results
- [ ] Test case linked to a User Story
- [ ] Dashboard created with pipeline, test, and work item widgets
- [ ] Pipeline failure notification configured

---

## Quiz Questions (discuss with your neighbor)

1. What is the difference between a **variable group** and a **Key Vault reference** in Azure DevOps?
2. Why is `squash merge only` a good merge strategy for `main`?
3. What happens if a step using a secret variable is `echo`ed in a pipeline log?
4. When would you extract a pipeline step into a template vs keeping it inline?
5. Can branch policies be bypassed? If yes, by whom?
6. What is the difference between a **static test suite** and a **requirement-based test suite**?
7. Why should dashboards include both pipeline metrics and work item charts?

---

## 🔧 Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| Key Vault secrets not showing in variable group | Service connection lacks `Get` permission on Key Vault | Add the pipeline's service principal to Key Vault **Access policies** with `Get` and `List` secret permissions |
| Branch policy not blocking direct pushes | Policy not saved, or you have "Bypass policies" permission | Re-save the policy. Check **Repo Settings → Security** for bypass permissions |
| Template file not found | Wrong relative path in `template:` reference | Path must be relative to the repo root: `templates/smoke-test-template.yml` |
| Test Plans menu is greyed out | You need a Basic + Test Plans license | Ask the admin to assign a **Basic + Test Plans** access level to your account in **Organization Settings → Users** |
| Dashboard widget shows "No data" | Pipeline hasn't run yet or query returns 0 results | Run the pipeline first, or verify the saved query returns work items |
| Notification not received | Email is in spam folder or notification filter is too narrow | Check spam; broaden the notification filter (remove pipeline-specific filter) |
