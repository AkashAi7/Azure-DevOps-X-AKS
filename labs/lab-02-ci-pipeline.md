# Lab 02: Building Your First CI Pipeline

**Duration:** 20 minutes  
**Module:** Module 2  
**Objective:** Import and run the CI pipeline. Understand each stage, view test results and the published Docker image.

---

## Background

The CI pipeline you will work with (`pipelines/ci-pipeline.yml`) does the following:

```
git push → trigger → [Validate Stage] → [Build Stage]
                          │                    │
                    Install deps         Docker build
                    Lint code            Docker push → ACR
                    Unit tests           Save artifact
                    Publish results
```

---

## Task 1: Verify the Service Connection

Before the pipeline can run, a **Service Connection** must exist to allow Azure DevOps to authenticate to ACR.

1. In Azure DevOps, go to **Project Settings** → **Service connections**
2. Look for `ACR-ServiceConnection` of type **Docker Registry**
3. If it's not there, create it:
   - Click **New service connection** → **Docker Registry**
   - Registry type: **Azure Container Registry**
   - Subscription: select your workshop subscription
   - Azure Container Registry: select the workshop ACR
   - Service connection name: `ACR-ServiceConnection`
   - Check ✅ "Grant access permission to all pipelines"
   - Click **Save**

---

## Task 2: Import the CI Pipeline

1. In Azure DevOps, go to **Pipelines** → **Pipelines**
2. Click **New pipeline**
3. Select **Azure Repos Git**
4. Select the `Fortis-Workshop` repository
5. Select **Existing Azure Pipelines YAML file**
6. Branch: `main`, Path: `/pipelines/ci-pipeline.yml`
7. Click **Continue** — review the YAML
8. Click **Save** (do not run yet)
9. Rename the pipeline to `InventoryAPI-CI`

---

## Task 3: Trigger a Pipeline Run

```bash
# Make a small change to trigger the pipeline
cd sample-app/src
echo "// workshop trigger" >> app.js

git add .
git commit -m "feat: trigger CI pipeline - lab 02"
git push origin main
```

In Azure DevOps, go to **Pipelines** and watch your pipeline run.

---

## Task 4: Explore the Pipeline Run

While (or after) the pipeline runs, explore each part:

### 4.1 Pipeline Overview
- Click on the running pipeline
- Note the two stages: **Validate** and **Build**
- Observe the matrix strategy — two jobs run in parallel for Node 18 and Node 20

### 4.2 Validate Stage — Test Results
1. After the Validate stage completes, click on the **Tests** tab at the top
2. You should see test results published from both Node versions
3. Note: test count, pass rate, duration

### 4.3 Validate Stage — Code Coverage
1. Click on the **Code Coverage** tab
2. Review which files have coverage and which do not

### 4.4 Build Stage — Logs
1. Click into the Build stage
2. Click **Build and push Docker image** step
3. Observe the Docker build layers being cached/rebuilt
4. Note the image tag generated (e.g., `abc12345-42`)

---

## Task 5: Verify the Image in ACR

```bash
# List images in the workshop ACR
az acr repository list --name <acr-name> -o table

# See tags for inventory-api
az acr repository show-tags \
  --name <acr-name> \
  --repository inventory-api \
  --orderby time_desc \
  -o table
# Expected: you should see your new tag at the top
```

---

## Task 6: Download and Test the Artifact

1. In your pipeline run, click the **Artifacts** button (top right)
2. Download the `image-info` artifact
3. Open `image-tag.txt` — this is the tag that will be used during deployment

---

## Task 7: Trigger a PR Validation Build

```bash
# Create a new branch
git checkout -b feature/lab02-pr-test

# Make a change
echo "// PR test change" >> sample-app/src/app.js
git add .
git commit -m "test: PR validation check"
git push origin feature/lab02-pr-test
```

1. In Azure DevOps, go to **Repos** → **Pull requests**
2. Create a PR from `feature/lab02-pr-test` → `main`
3. Observe: a pipeline run starts automatically as a PR validation build
4. Note: this run runs `Validate` only (no `Build` on PRs)

---

## Task 8: Understand Pipeline Caching

Look at the **Cache npm packages** step in the logs:
- First run: "Cache not found" — takes ~30 seconds to install
- Second run with same `package-lock.json`: "Cache restored" — near instant

This is the `Cache@2` task in action, saving ~20-30 seconds per run.

---

## ✅ Lab 2 Completion Checklist

- [ ] `ACR-ServiceConnection` service connection exists
- [ ] `InventoryAPI-CI` pipeline imported
- [ ] Pipeline triggered by a git push on `main`
- [ ] Test results visible in the **Tests** tab
- [ ] Docker image visible in ACR with a new tag
- [ ] PR validation pipeline triggered (runs Validate only)
- [ ] Understand why the Build stage is skipped on PRs

---

## Key YAML Concepts Covered

| Concept | Where Used |
|---------|-----------|
| `trigger:` + `pr:` | Lines 1-20 — when does pipeline run |
| `strategy: matrix` | UnitTest job — run on multiple Node versions |
| `Cache@2` | npm caching — faster pipeline runs |
| `condition:` | Build stage only runs on non-PR pushes |
| `PublishTestResults@2` | Makes test results visible in UI |
| `Docker@2 buildAndPush` | Build image + push to ACR in one step |
| `PublishPipelineArtifact@1` | Pass data (image tag) between stages |

---

## Bonus: Add a Breaking Test

Try this to see what happens when tests fail:

```bash
# In sample-app/src/tests/app.test.js, change this:
# expect(res.body.status).toBe('healthy');
# To this:
# expect(res.body.status).toBe('broken');

git add . && git commit -m "test: intentional failure"
git push origin feature/lab02-pr-test
```

Observe: the PR pipeline run fails. The PR cannot be merged because of the branch policy requiring a passing build.
