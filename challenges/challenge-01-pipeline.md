# Challenge 01: Add Security Scanning to the CI Pipeline

**Difficulty:** ⭐⭐ (Intermediate)  
**Estimated time:** 45-60 minutes  
**Take-home challenge**

---

## Scenario

Your security team has mandated that all container images must be scanned for vulnerabilities before being deployed to any environment. Additionally, the OWASP Top 10 security risks must be addressed in the running application.

Your task is to add two security scanning stages to the CI pipeline:

1. **Container image scanning** using Trivy
2. **Dependency vulnerability scanning** using npm audit

---

## Tasks

### Task 1: Add npm Audit to the Validate Stage

Add a step to the Validate stage of `ci-pipeline.yml` that:
1. Runs `npm audit` on the sample-app
2. Fails the pipeline if any **critical** or **high** severity vulnerabilities are found
3. Publishes the audit report as a pipeline artifact

**Hint:**
```bash
npm audit --audit-level=high --json > audit-report.json
```

---

### Task 2: Add Container Image Scanning with Trivy

Add a new stage called `SecurityScan` to the CI pipeline that:
1. Runs **after** the Build stage
2. Uses Trivy to scan the newly built Docker image
3. Fails if any **CRITICAL** severity CVEs are found
4. Publishes a scan report as a pipeline artifact

**Trivy in an Azure DevOps pipeline:**
```yaml
- stage: SecurityScan
  displayName: '🔒 Security Scan'
  dependsOn: Build
  jobs:
  - job: TrivyScan
    steps:
    - script: |
        # Install Trivy
        wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
        echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | \
          sudo tee -a /etc/apt/sources.list.d/trivy.list
        sudo apt-get update && sudo apt-get install trivy -y
      displayName: 'Install Trivy'
    
    # YOUR CODE HERE: add steps to:
    # 1. Pull the image from ACR
    # 2. Run trivy image scan
    # 3. Fail pipeline on CRITICAL CVEs
    # 4. Publish the JSON report as an artifact
```

---

### Task 3: Block Deployment if Scan Fails

Modify the CD pipeline so that:
1. The `DeployDev` stage **requires** the `SecurityScan` stage to have passed
2. Add a `condition:` expression to `DeployDev` that checks for security scan passage

---

### Task 4: Add a Security Gate to Production

In the Azure DevOps `InventoryAPI-Production` environment:
1. Add a **REST API gate** that calls a hypothetical security dashboard endpoint
2. The gate should query: `GET https://security-dashboard/api/scans/{imageTag}/passed`
3. Configure it to succeed only if the response contains `"status": "passed"`

> **Note:** Since we don't have a real security dashboard, you can simulate this by creating an Azure Function that always returns `{"status": "passed"}` — or discuss with your team what the real endpoint would be.

---

## Acceptance Criteria

- [ ] `npm audit --audit-level=high` fails the Validate stage if vulnerable packages exist
- [ ] A `SecurityScan` stage exists after `Build` in the CI pipeline
- [ ] Trivy scan runs successfully against the ACR image
- [ ] Pipeline fails with a clear message if CRITICAL CVEs are found
- [ ] `DeployDev` only runs if `SecurityScan` passed
- [ ] Trivy report is published as a downloadable artifact

---

## Useful Resources

- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Azure DevOps — Add a check](https://docs.microsoft.com/azure/devops/pipelines/process/checks)
- [npm audit documentation](https://docs.npmjs.com/cli/v9/commands/npm-audit)

---

## Solution Reference

A complete solution is available in the branch `solutions/challenge-01`. 
Try to solve it yourself before looking — the challenge is where the learning happens!
