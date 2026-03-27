# Challenge 03: Agentic DevOps — Build an Observability Stack

**Difficulty:** ⭐⭐ (Intermediate) with GitHub Copilot assistance  
**Estimated time:** 45-60 minutes  
**Level:** L100 Copilot — use Agent Mode for the heavy lifting!

---

## Scenario

Your InventoryAPI is deployed to AKS across 3 environments — but you have no visibility into what's happening inside the cluster. Your task is to use **GitHub Copilot Agent Mode** to generate a complete observability stack (Prometheus + Grafana) on AKS.

You do NOT need to know Kubernetes or Prometheus deeply. **Let Copilot guide you through it.** This challenge demonstrates the power of Agentic DevOps.

---

## Your Mission

Use Copilot Agent Mode to:
1. Generate Prometheus Kubernetes manifests to scrape metrics from InventoryAPI
2. Generate a Grafana deployment with a pre-built dashboard
3. Create an Azure DevOps pipeline stage that deploys the observability stack
4. Create a runbook that explains the observability setup

---

## Task 1: Use Copilot to Generate Prometheus Manifests

Open VS Code, switch to Agent Mode in Copilot Chat, and type:

```
I need to add observability to my InventoryAPI application running on AKS.
The app exposes Prometheus metrics at GET /metrics on port 3000.

Please create Kubernetes manifests in k8s/observability/ for:
1. A Prometheus deployment in a new "monitoring" namespace
   - ConfigMap with prometheus.yml that scrapes all pods with label app=inventory-api
   - Deployment with 1 replica, using prom/prometheus:latest
   - ClusterRole and ClusterRoleBinding so Prometheus can discover pods
   - Service on port 9090

2. A Grafana deployment
   - Deployment with 1 replica, grafana/grafana:latest
   - ConfigMap with a datasource pointing to Prometheus service
   - Service on port 3000 (Grafana runs on 3000 by default)
   - Ingress to expose at monitoring.workshop.local

Use the same namespace style as the existing k8s/base/namespace.yaml in this project.
```

Review the generated manifests. Ask follow-up questions if anything is unclear.

---

## Task 2: Verify the Manifests are Valid

After Copilot generates the files, run:

```bash
# Validate all generated manifests syntactically
kubectl apply --dry-run=client -f k8s/observability/

# If there are errors, paste them back into Copilot Chat:
# "I got this error: [paste error]. Fix the manifest."
```

---

## Task 3: Create the Monitoring Namespace and Deploy

```bash
# Apply the manifests
kubectl apply -f k8s/observability/

# Watch Prometheus and Grafana start
kubectl get pods -n monitoring -w

# Port-forward to access Grafana locally
kubectl port-forward service/grafana 3001:3000 -n monitoring
# Open http://localhost:3001 (admin/admin by default)
```

In Grafana, add the Prometheus data source and create a simple panel showing:
- HTTP request rate for InventoryAPI
- Pod CPU usage

---

## Task 4: Create a Pipeline Stage for Observability Deployment

Ask Copilot:

```
Create an Azure DevOps pipeline YAML file at 
pipelines/deploy-observability.yml that:
1. Triggers manually (trigger: none)
2. Has a single stage "DeployObservability"
3. Uses the same AzureRM-ServiceConnection as in the other pipeline files 
   in this project
4. Deploys all manifests in k8s/observability/ to the AKS cluster
5. Waits for Prometheus and Grafana deployments to be ready
6. Outputs the Grafana service URL at the end

Look at the existing cd-pipeline.yml for the service connection pattern to use.
```

---

## Task 5: Ask Copilot to Generate a Grafana Dashboard

```
Generate a Grafana dashboard JSON definition as a ConfigMap 
in k8s/observability/grafana-dashboard-configmap.yaml.

The dashboard should have panels for:
- Total HTTP requests per minute (using http_requests_total metric from InventoryAPI)
- HTTP requests by status code (split by status_code label)
- Node.js heap memory usage
- Pod restart count

The inventory-api app labels in Prometheus are:
- app: inventory-api
- environment: dev/staging/production

Include time series panels with 5-minute rate windows.
```

---

## Task 6: Generate a Monitoring Runbook

```
Create a file docs/runbook-monitoring.md that documents 
the observability stack we just set up. Include:

1. Architecture diagram (ASCII)
2. How metrics flow from InventoryAPI → Prometheus → Grafana  
3. How to access Grafana in each environment
4. The top 5 alerts to configure for a production Node.js API
5. How to add a new metric to the InventoryAPI app
6. Troubleshooting steps if metrics are missing

Base your answers on the actual manifest files in k8s/observability/ 
in this project.
```

---

## Acceptance Criteria

- [ ] `k8s/observability/` folder exists with Prometheus and Grafana manifests
- [ ] `kubectl apply --dry-run` succeeds with no errors
- [ ] Prometheus and Grafana pods run in the `monitoring` namespace
- [ ] Grafana accessible via port-forward, data from InventoryAPI visible
- [ ] `pipelines/deploy-observability.yml` pipeline file created
- [ ] `docs/runbook-monitoring.md` created with relevant content

---

## What You Learned

This challenge demonstrates the Agentic DevOps loop:

```
Human: describe the goal in plain language
   ↓
Copilot Agent: reads existing repo context
   ↓
Copilot Agent: generates multiple files in the right places
   ↓
Human: reviews, corrects, iterates
   ↓
Human: applies changes
   ↓
System: deployed, observability live
```

The same task traditionally would require:
- Learning Prometheus configuration syntax
- Reading Kubernetes RBAC documentation
- Writing YAML by hand for ~200 lines
- Debugging mount and selector issues

With Agentic DevOps, you direct the outcome — the AI handles the boilerplate.

---

## Reflection Questions

Discuss with your team:

1. What parts of the generated manifests did you NOT understand? Did you ask Copilot to explain them?
2. Did Copilot make any mistakes? What kind?
3. How much time did this take vs. if you had written it all from scratch?
4. What are the risks of using AI-generated Kubernetes manifests in production?
5. What should you ALWAYS do before `kubectl apply`-ing AI-generated manifests?
