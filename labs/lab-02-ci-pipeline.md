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
- Observe the matrix strategy — two jobs run in parallel for Node 20 and Node 22

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

## Task 9: Publish an npm Package to Azure Artifacts

Azure Artifacts is Azure DevOps' built-in package management service. In this task you will publish the `inventory-api` package to the workshop Artifacts feed and verify it.

### 9.1 Connect to the Artifacts Feed

1. In Azure DevOps, go to **Artifacts**
2. Click on the `inventory-api-packages` feed (created during admin setup)
3. Click **Connect to feed** → **npm**
4. Note the feed URL — you will use it below

### 9.2 Create a `.npmrc` File for the Feed

In your local repo, create a `.npmrc` file in the `sample-app/` directory:

```bash
cd sample-app

cat > .npmrc << 'EOF'
registry=https://pkgs.dev.azure.com/<your-org>/<your-project>/_packaging/inventory-api-packages/npm/registry/
always-auth=true
EOF
```

> Replace `<your-org>` and `<your-project>` with your actual Azure DevOps organization and project names. You can copy the exact URL from the **Connect to feed** page.

### 9.3 Authenticate to the Feed

```bash
# Install the Azure Artifacts credential provider
npx vsts-npm-auth -config .npmrc

# Verify authentication works
npm whoami --registry https://pkgs.dev.azure.com/<your-org>/<your-project>/_packaging/inventory-api-packages/npm/registry/
```

### 9.4 Publish the Package

```bash
# From sample-app/
npm publish
# Expected: + inventory-api@1.0.0
```

### 9.5 Verify in the Azure DevOps Portal

1. Go to **Artifacts** → `inventory-api-packages`
2. You should see `inventory-api` with version `1.0.0`
3. Click on the package to see:
   - **Overview**: description, author, license
   - **Versions**: list of published versions
   - **Dependencies**: express, prom-client, uuid

### 9.6 Understand Pipeline-Based Publishing

The CI pipeline can also publish to Artifacts automatically. Look at this pattern (you do not need to add it now, but understand how it works):

```yaml
# Example: Publish npm package from a pipeline
- task: Npm@1
  displayName: 'Publish to Artifacts feed'
  inputs:
    command: 'publish'
    workingDir: 'sample-app'
    publishRegistry: 'useFeed'
    publishFeed: '<project>/inventory-api-packages'
```

> **Key Point:** Artifacts feeds support **upstream sources** — they can proxy packages from the public npm registry. This means your pipeline can install both public packages and your private packages from a single `.npmrc` config.

---

## Task 10: Explore the Artifacts Feed Features

1. In the `inventory-api-packages` feed, click **Feed settings** (gear icon)
2. Explore these tabs:

| Tab | What it does |
|-----|-------------|
| **Upstream sources** | Proxy public registries (npmjs.com) — packages are cached locally on first download |
| **Permissions** | Control who can read/publish packages — `Reader`, `Collaborator`, `Contributor` |
| **Views** | Promote packages: `@local` → `@prerelease` → `@release` for quality gating |
| **Retention** | Auto-delete old package versions to save storage |

3. Try promoting your package:
   - Click on your `inventory-api@1.0.0` package
   - Click **Promote** → select `@prerelease` view
   - Now the package is accessible via the `@prerelease` view URL

> **Why this matters:** In real teams, you publish every build to `@local`, promote tested builds to `@prerelease`, and promote release-ready builds to `@release`. Downstream consumers can pin to a specific quality level.

---

## ✅ Lab 2 Completion Checklist

- [ ] `ACR-ServiceConnection` service connection exists
- [ ] `InventoryAPI-CI` pipeline imported
- [ ] Pipeline triggered by a git push on `main`
- [ ] Test results visible in the **Tests** tab
- [ ] Docker image visible in ACR with a new tag
- [ ] PR validation pipeline triggered (runs Validate only)
- [ ] Understand why the Build stage is skipped on PRs
- [ ] npm package published to Azure Artifacts feed
- [ ] Package visible in Artifacts portal with version info
- [ ] Understand upstream sources and package promotion

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
| `Npm@1` publish | Publish packages to Artifacts feed |

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

---

## 🔧 Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| Pipeline stuck on "Waiting for agent" | No available hosted agents or free parallelism exhausted | Check **Organization Settings → Parallel jobs** — free tier gets 1 parallel job with limited minutes |
| `npm ci` fails with `ERESOLVE` | Dependency version conflict | Run `npm install` locally first, then commit the updated `package-lock.json` |
| Docker build fails: "unauthorized" | ACR service connection not configured or expired | Re-verify `ACR-ServiceConnection` in **Project Settings → Service connections** |
| Test results tab is empty | Test file not in JUnit XML format or wrong path | Check `testResultsFiles` path — it must match `sample-app/test-results/junit.xml` |
| Cache not restoring | `package-lock.json` changed between runs | Expected behavior — cache key includes the lock file hash |
| `npm publish` fails with 403 | Missing permissions on Artifacts feed | Go to **Artifacts → Feed Settings → Permissions** and add yourself as `Contributor` |
| `npm publish` fails with 409 | Package version already exists | Bump the `version` in `package.json` and try again |
| Pipeline YAML shows red squiggles | Indentation error or unknown task name | Use the Azure DevOps YAML editor's **Validate** button before saving |
