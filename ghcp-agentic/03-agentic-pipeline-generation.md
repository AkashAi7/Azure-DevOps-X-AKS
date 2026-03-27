# Agentic DevOps — Pipeline Generation with GitHub Copilot
## *How to Generate Full CI/CD Pipelines with AI*

---

## What is "Agentic DevOps"?

Traditional DevOps + AI assistance = **Agentic DevOps**

```
Traditional DevOps:
Every YAML line, every K8s manifest, every script
→ written manually by a DevOps engineer
→ hours of work, high expertise required

Agentic DevOps:
Developer describes WHAT they need
→ AI agent generates the implementation
→ Developer reviews and approves
→ Minutes instead of hours
```

The DevOps engineer's role shifts from **writing boilerplate** to **directing and validating outcomes**.

---

## The Agentic Loop

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  Human: "I need a CI pipeline for my Node.js app..."   │
│          ↓                                              │
│  Copilot Agent: reads existing code + manifests         │
│          ↓                                              │
│  Copilot Agent: proposes pipeline YAML                  │
│          ↓                                              │
│  Human: reviews, asks for changes                       │
│          ↓                                              │
│  Copilot Agent: refines                                 │
│          ↓                                              │
│  Human: accepts, applies                                │
│          ↓                                              │
│  Pipeline runs in Azure DevOps ✅                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Generating a CI Pipeline from Scratch

### Step 1: Open a New File

Create `pipelines/my-new-pipeline.yml` (empty file)

### Step 2: Give Copilot Full Context

In Agent Mode, type:

```
Look at the sample-app/ folder and the existing ci-pipeline.yml 
in this repository, then create a new CI pipeline for the same 
application with these changes:

1. Trigger on push to main AND release/* branches
2. Only run the matrix test on Node 20 (not 18 and 20)
3. Add a new step after tests: run "npm run lint" and 
   publish the results as a warning (not blocking)
4. Add a step to publish the npm package to the Azure Artifacts 
   feed named "workshop-packages" (universal package)
5. Use the same variable group structure as ci-pipeline.yml

Save it to pipelines/my-new-pipeline.yml
```

### Step 3: Review the Output

Copilot will generate a YAML file. Check:
- Does the trigger syntax look right?
- Are the variable group references correct?
- Does the Artifacts publish step have the right feed name?
- Are there any obvious mistakes?

### Step 4: Validate and Iterate

```bash
# Validate YAML syntax locally
# Install azure-pipelines-yaml-validator OR
# Just check basic YAML structure
python -c "import yaml; yaml.safe_load(open('pipelines/my-new-pipeline.yml'))"
echo "YAML syntax: OK"
```

If there's an issue, paste the error back to Copilot:
```
I got this YAML syntax error: [paste error]
Fix the pipeline file.
```

---

## Generating K8s Manifests for a New Microservice

Imagine you need to deploy a second microservice (`catalog-api`) alongside `inventory-api`:

### Agent Mode Prompt:

```
Based on the existing Kubernetes manifests in k8s/ for the inventory-api 
application, create equivalent manifests for a new microservice called 
"catalog-api" with these differences:

- Container image: myacr.azurecr.io/catalog-api
- Port: 8080 (not 3000)
- Health endpoint: /actuator/health (it's a Spring Boot app)
- Dev  namespace: 1 replica
- Staging: 2 replicas  
- Production: 3 replicas with HPA min=3 max=8
- No liveness probe needed for the first iteration
- The ConfigMap should have SPRING_PROFILES_ACTIVE set per environment
  (dev, staging, production)

Create in:
- k8s/catalog-api/base/
- k8s/catalog-api/overlays/dev/
- k8s/catalog-api/overlays/staging/
- k8s/catalog-api/overlays/production/
```

**The agent will:**
1. Read all existing k8s files for structure reference
2. Create multiple new files in the right directories
3. Adapt the configuration for the new service
4. Use consistent patterns from your existing manifests

---

## Generating Pipeline Templates

### Extracting Repetition

If you have copy-pasted the same 20 lines of pipeline YAML 3 times, use Copilot to extract it:

```
In the cd-pipeline.yml file, I notice the smoke test logic is 
repeated in both the DeployStaging and DeployProduction stages.

1. Extract the smoke test logic into a new template file at 
   pipelines/templates/smoke-test-template.yml
2. Update cd-pipeline.yml to use that template with parameters 
   for the API URL and environment name
3. Make sure the template accepts:
   - apiUrl (the base URL to test)
   - environment (string, for display name)
   - expectedVersion (optional, to validate /health response)
```

---

## Real-World Agentic DevOps Scenarios

### Scenario 1: "Add monitoring to all environments"

```
All three of our environments (dev, staging, production) 
are missing Kubernetes resource quotas. Our ops team says we need:
- dev: 1 CPU core, 2Gi memory total
- staging: 2 CPU cores, 4Gi memory total  
- production: 4 CPU cores, 8Gi memory total

Also add LimitRange objects so individual pods can't hog resources.

Update the overlay files in k8s/overlays/ for each environment.
```

### Scenario 2: "Our security team requires these changes"

```
Our security team has flagged these issues in our K8s manifests:

1. Pods are running as root — add securityContext with runAsNonRoot: true
2. We have no NetworkPolicies — add one that only allows ingress from 
   the ingress-nginx namespace
3. The container has allowPrivilegeEscalation not set — set it to false
4. No readOnlyRootFilesystem — set it to true (but add a writable /tmp volume)

Apply these security hardening changes to all deployment manifests 
in k8s/base/ and preserve the environment-specific overlays.
```

### Scenario 3: "Migrate from classic pipeline to YAML"

If you have a classic (GUI) pipeline, you can describe what it does to Copilot:

```
I have an Azure DevOps classic pipeline that does the following tasks:
1. Run npm install
2. Run npm test with JUnit output
3. Build Docker image with tag $(Build.BuildId)
4. Push to ACR at myacr.azurecr.io
5. Deploy to AKS using kubectl apply

Convert this to a modern YAML pipeline. Use the same patterns 
as ci-pipeline.yml already in this repo. The ACR is connected 
via service connection 'ACR-ServiceConnection' and AKS via 
'AzureRM-ServiceConnection'.
```

---

## When Copilot Gets it Wrong

Copilot is helpful but makes mistakes. Common DevOps errors:

| Error Type | Example | How to catch it |
|-----------|---------|----------------|
| Wrong API version | `autoscaling/v1` (deprecated) | Check `kubectl api-versions` |
| Off-by-one indent | YAML block under wrong parent | `kubectl apply --dry-run` |
| Missing required field | Forgot `selector` in Service | `kubectl apply --dry-run` |
| Wrong task version | `Docker@1` instead of `Docker@2` | Test run the pipeline |
| Wrong variable syntax | `${{ variables.ACR_NAME }}` vs `$(ACR_NAME)` | Context matters in YAML pipelines |

**Always run:**
```bash
# For Kubernetes:
kubectl apply --dry-run=client -f <file>

# For Azure DevOps YAML:
# Use the "Validate" button in Azure DevOps Pipelines editor
# Or: az pipelines validate (az extension add --name azure-devops)
```

---

## The Future of Agentic DevOps

As of 2026, the tools are still evolving:

| Current (Today) | Near Future |
|----------------|-------------|
| Copilot generates YAML from text | AI directly configures Azure DevOps settings |
| Agent reads/writes local files | Agent creates PRs, runs pipelines, reads results |
| Human approves each file change | Human approves multi-step automated workflows |
| AI assists with runbooks | AI writes and executes runbooks autonomously |
| Manual deployment approval | AI-assisted approval with risk scoring |

The key is: **AI handles the repetitive, the human handles the judgment**.
