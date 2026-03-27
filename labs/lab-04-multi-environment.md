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
      - '18'
      - '20'
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

## Part D: Pipeline Decorators (Concept only — demo by facilitator)

Pipeline Decorators let org administrators inject steps into ALL pipelines automatically — without individual pipeline authors needing to add them.

**Use cases:**
- Inject security scanning into every build automatically
- Add corporate logging/telemetry to all pipelines
- Enforce compliance checks organization-wide

**How they work:**
1. An extension is installed in the Azure DevOps organization
2. The extension defines `preBuildSteps` or `postBuildSteps`
3. These steps are automatically added to every pipeline run

> This is an advanced topic — ask the facilitator for a live demo.

---

## ✅ Lab 4 Completion Checklist

- [ ] `InventoryAPI-Secrets` variable group linked to Key Vault
- [ ] Secret (`ACR_ADMIN_PASSWORD`) shown as `***` in pipeline logs
- [ ] Branch policies applied to `main`: reviewer required + build validation
- [ ] Direct push to `main` is blocked
- [ ] Existing pipeline templates reviewed and understood
- [ ] (Stretch) New `smoke-test-template.yml` created and used

---

## Quiz Questions (discuss with your neighbor)

1. What is the difference between a **variable group** and a **Key Vault reference** in Azure DevOps?
2. Why is `squash merge only` a good merge strategy for `main`?
3. What happens if a step using a secret variable is `echo`ed in a pipeline log?
4. When would you extract a pipeline step into a template vs keeping it inline?
5. Can branch policies be bypassed? If yes, by whom?
