#!/usr/bin/env python3
"""
provision-infra.py
Fortis Workshop - Cross-platform admin setup for Azure DevOps + AKS

What this script does:
  1.  Logs in to Azure and sets the correct subscription
  2.  Pulls kubeconfig for your existing AKS cluster
  3.  Creates Kubernetes namespaces: dev, staging, production
  4.  Creates the Azure DevOps project (if it doesn't exist)
  5.  Creates variable groups: InventoryAPI-Common and InventoryAPI-Environments
  6.  Seeds Azure Boards - Epic -> Features -> User Stories -> Tasks + Bugs
  7.  Initialises the default Git repo and pushes workshop source code
  8.  Imports CI and CD pipelines from the pipelines/ folder
  9.  Creates an Artifacts feed: inventory-api-packages
  10. Creates a Test Plan with two suites and sample test cases

Usage:
  python scripts/provision-infra.py

Prerequisites:
  - Azure CLI 2.55+
  - Azure DevOps CLI extension  (az extension add --name azure-devops)
  - kubectl 1.28+
  - Python 3.9+
"""

import json
import os
import platform
import shutil
import subprocess
import sys

# ---------------------------------------------------------------------------
# CONFIGURATION - fill in every value marked  <<<  before running
# Or place a filled-in workshop.env in the repo root and values load automatically.
# ---------------------------------------------------------------------------

# --- Azure ---
SUBSCRIPTION_ID = ""                                   # <<< your Azure Subscription ID
AKS_RESOURCE_GROUP = "rg-workshop-aks"                 # <<< resource group containing your AKS cluster
AKS_NAME = "aks-workshop-01"                           # <<< your AKS cluster name
ACR_NAME = "workshopacr01"                             # <<< your ACR name (without .azurecr.io)

# --- Azure DevOps ---
AZDO_ORG = "https://dev.azure.com/<your-org>"          # <<< org URL only
AZDO_PROJECT = "workshop-project"                      # <<< project name to create (or existing)
AZDO_PROJECT_DESC = "Fortis Workshop - AKS DevOps project"

# --- Auto-load from workshop.env if the file exists ---
def _load_env():
    global SUBSCRIPTION_ID, AKS_RESOURCE_GROUP, AKS_NAME, ACR_NAME
    global AZDO_ORG, AZDO_PROJECT
    for envfile in ["workshop.env", os.path.join(os.path.dirname(__file__), "..", "workshop.env")]:
        if os.path.isfile(envfile):
            with open(envfile) as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if "=" not in line:
                        continue
                    key, _, value = line.partition("=")
                    key, value = key.strip(), value.strip()
                    if not value:
                        continue
                    mapping = {
                        "AZURE_SUBSCRIPTION_ID": "SUBSCRIPTION_ID",
                        "AKS_RESOURCE_GROUP": "AKS_RESOURCE_GROUP",
                        "AKS_CLUSTER_NAME": "AKS_NAME",
                        "ACR_NAME": "ACR_NAME",
                        "AZDO_ORG": "AZDO_ORG",
                        "AZDO_PROJECT": "AZDO_PROJECT",
                    }
                    if key in mapping:
                        globals()[mapping[key]] = value
            print(f"\033[1;34m[INFO]\033[0m  Loaded configuration from: {envfile}")
            break

_load_env()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
BLUE = "\033[1;34m"
GREEN = "\033[1;32m"
YELLOW = "\033[1;33m"
RED = "\033[1;31m"
RESET = "\033[0m"


def info(msg):
    print(f"\n{BLUE}[INFO]{RESET}  {msg}")


def success(msg):
    print(f"{GREEN}[DONE]{RESET}  {msg}")


def warn(msg):
    print(f"{YELLOW}[WARN]{RESET}  {msg}")


def fail(msg):
    print(f"{RED}[FAIL]{RESET}  {msg}")


def command_exists(cmd):
    return shutil.which(cmd) is not None


def sh(cmd, check=False, capture=False):
    """Run a shell command."""
    kwargs = {"shell": True, "text": True}
    if capture:
        kwargs["stdout"] = subprocess.PIPE
        kwargs["stderr"] = subprocess.PIPE
    return subprocess.run(cmd, check=check, **kwargs)


def sh_output(cmd):
    """Run a shell command and return stripped stdout, or empty string on failure."""
    try:
        r = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:
        return ""


def sh_json(cmd):
    """Run a shell command and parse JSON output, or return None."""
    raw = sh_output(cmd)
    if raw:
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return None
    return None


# ---------------------------------------------------------------------------
# Step 0 - Verify tooling
# ---------------------------------------------------------------------------
def verify_tools():
    info("Checking required tools...")
    for name, cmd in [("Azure CLI", "az"), ("kubectl", "kubectl")]:
        if not command_exists(cmd):
            fail(f"{name} not found. Install it first (python scripts/install-dependencies.py).")
            sys.exit(1)
        success(f"{name} found.")

    # Ensure Azure DevOps CLI extension
    check = sh("az extension show --name azure-devops", capture=True)
    if check.returncode != 0:
        info("Installing Azure DevOps CLI extension...")
        sh("az extension add --name azure-devops --output none")
    else:
        success("Azure DevOps CLI extension already installed.")


# ---------------------------------------------------------------------------
# Step 1 - Azure login & subscription
# ---------------------------------------------------------------------------
def azure_login():
    info("Logging in to Azure...")
    sh("az login --output none", check=True)

    if SUBSCRIPTION_ID:
        sh(f"az account set --subscription {SUBSCRIPTION_ID}", check=True)

    sub = sh_output('az account show --query "{Name:name, ID:id}" -o tsv')
    success(f"Using subscription: {sub}")

    info("Authenticating Azure DevOps CLI...")
    token = sh_output("az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv")
    os.environ["AZURE_DEVOPS_EXT_PAT"] = token
    success("Azure DevOps CLI authenticated (token set via AZURE_DEVOPS_EXT_PAT).")


# ---------------------------------------------------------------------------
# Step 2 - Connect kubectl
# ---------------------------------------------------------------------------
def connect_kubectl():
    info(f"Fetching credentials for AKS cluster: {AKS_NAME}...")
    sh(
        f"az aks get-credentials --resource-group {AKS_RESOURCE_GROUP} "
        f"--name {AKS_NAME} --overwrite-existing",
        check=True,
    )
    success("kubectl context set.")
    info("Verifying cluster nodes...")
    sh("kubectl get nodes")


# ---------------------------------------------------------------------------
# Step 3 - Kubernetes namespaces
# ---------------------------------------------------------------------------
def create_namespaces():
    info("Applying namespace manifests (dev, staging, production)...")
    sh("kubectl apply -f k8s/base/namespace.yaml", check=True)
    success("Namespaces applied.")
    sh("kubectl get namespaces")


# ---------------------------------------------------------------------------
# Step 4 - Azure DevOps project
# ---------------------------------------------------------------------------
def create_project():
    info("Configuring Azure DevOps CLI defaults...")
    sh(f'az devops configure --defaults organization="{AZDO_ORG}"')

    result = sh(f'az devops project show --project "{AZDO_PROJECT}"', capture=True)
    if result.returncode == 0:
        warn(f"Azure DevOps project '{AZDO_PROJECT}' already exists - skipping creation.")
    else:
        info(f"Creating Azure DevOps project: {AZDO_PROJECT}...")
        sh(
            f'az devops project create --name "{AZDO_PROJECT}" '
            f'--description "{AZDO_PROJECT_DESC}" --visibility private --process Agile --output none',
            check=True,
        )
        success(f"Azure DevOps project created: {AZDO_PROJECT}")

    sh(f'az devops configure --defaults project="{AZDO_PROJECT}"')


# ---------------------------------------------------------------------------
# Step 5 - Variable groups
# ---------------------------------------------------------------------------
def create_variable_groups():
    acr_login_server = sh_output(f"az acr show --name {ACR_NAME} --query loginServer -o tsv")
    sub_id = sh_output("az account show --query id -o tsv")

    # InventoryAPI-Common
    info("Creating variable group: InventoryAPI-Common...")
    result = sh(
        f'az pipelines variable-group create --name "InventoryAPI-Common" '
        f"--variables "
        f"ACR_NAME={ACR_NAME} "
        f"AKS_RESOURCE_GROUP={AKS_RESOURCE_GROUP} "
        f"AKS_CLUSTER_NAME={AKS_NAME} "
        f"AZURE_SUBSCRIPTION_ID={sub_id} "
        f"ACR_LOGIN_SERVER={acr_login_server} "
        f"--output none",
        capture=True,
    )
    if result.returncode == 0:
        success("Variable group 'InventoryAPI-Common' created.")
    else:
        warn("Could not create 'InventoryAPI-Common' (may already exist).")

    # InventoryAPI-Environments
    info("Creating variable group: InventoryAPI-Environments...")
    result = sh(
        'az pipelines variable-group create --name "InventoryAPI-Environments" '
        "--variables "
        "K8S_REPLICAS_DEV=1 K8S_REPLICAS_STAGING=2 K8S_REPLICAS_PROD=3 "
        "LOG_LEVEL_DEV=debug LOG_LEVEL_STAGING=info LOG_LEVEL_PROD=warn "
        "--output none",
        capture=True,
    )
    if result.returncode == 0:
        success("Variable group 'InventoryAPI-Environments' created.")
    else:
        warn("Could not create 'InventoryAPI-Environments' (may already exist).")


# ---------------------------------------------------------------------------
# Step 6 - Seed Azure Boards
# ---------------------------------------------------------------------------
def create_work_item(wi_type, title, parent_id=None, description=None):
    """Create a work item and optionally link to a parent. Returns the item ID."""
    cmd = f'az boards work-item create --type "{wi_type}" --title "{title}" --output json'
    if description:
        cmd += f' --description "{description}"'
    data = sh_json(cmd)
    wi_id = data.get("id") if data else None

    if wi_id and parent_id:
        sh(
            f"az boards work-item relation add --id {wi_id} "
            f'--relation-type "System.LinkTypes.Hierarchy-Reverse" '
            f"--target-id {parent_id} --output none"
        )
    return wi_id


def seed_boards():
    info("Seeding Azure Boards (Epic -> Features -> Stories -> Tasks + Bugs)...")

    epic_id = create_work_item(
        "Epic",
        "Containerize & Deploy InventoryAPI to AKS",
        description="End-to-end DevOps pipeline for the InventoryAPI microservice covering CI, CD, and multi-environment promotion on AKS.",
    )
    success(f"Created Epic #{epic_id}")

    # Feature 1 - CI Pipeline
    f1 = create_work_item("Feature", "CI Pipeline - Build, Test & Publish", epic_id)
    s1 = create_work_item("User Story", "As a developer, I can trigger an automated build on every commit", f1)
    for t in [
        "Create ci-pipeline.yml in Azure DevOps",
        "Add ESLint lint stage",
        "Add Jest unit-test stage with coverage threshold",
        "Build Docker image and push to ACR",
    ]:
        create_work_item("Task", t, s1)
    success("Created Feature 1 (CI Pipeline) and child items.")

    # Feature 2 - CD Pipeline
    f2 = create_work_item("Feature", "CD Pipeline - Multi-Environment Deployment", epic_id)
    s2 = create_work_item("User Story", "As an ops engineer, I can promote a release through dev -> staging -> production", f2)
    for t in [
        "Deploy to dev namespace on every successful CI run",
        "Add manual approval gate before staging deployment",
        "Add production gate with rollback strategy",
        "Configure HPA and resource limits per environment",
    ]:
        create_work_item("Task", t, s2)
    success("Created Feature 2 (CD Pipeline) and child items.")

    # Feature 3 - Observability
    f3 = create_work_item("Feature", "Observability - Health, Metrics & Alerts", epic_id)
    s3 = create_work_item("User Story", "As an SRE, I can monitor the API via Prometheus metrics and liveness probes", f3)
    for t in [
        "Verify /health and /ready endpoints respond correctly",
        "Scrape /metrics with Prometheus",
        "Set up Azure Monitor alert for pod restarts",
    ]:
        create_work_item("Task", t, s3)
    success("Created Feature 3 (Observability) and child items.")

    # Feature 4 - GitHub Copilot
    f4 = create_work_item("Feature", "GitHub Copilot Agentic DevOps", epic_id)
    s4 = create_work_item("User Story", "As a developer, I can use GitHub Copilot to generate and explain pipeline YAML", f4)
    for t in [
        "Use Copilot to generate a Kubernetes deployment manifest",
        "Use Copilot to explain the HPA configuration",
        "Use Copilot to write unit tests for the products route",
    ]:
        create_work_item("Task", t, s4)
    success("Created Feature 4 (Copilot) and child items.")

    # Bugs
    b1 = create_work_item(
        "Bug",
        "Health endpoint returns hardcoded version string",
        epic_id,
        "APP_VERSION env var is not injected at deploy time so /health always returns 1.0.0 regardless of the image tag.",
    )
    b2 = create_work_item(
        "Bug",
        "POST /api/products accepts empty product name",
        epic_id,
        "Validation is missing on the name field - an empty string is accepted and stored in the in-memory array.",
    )
    success(f"Created 2 sample Bugs (#{b1}, #{b2}).")


# ---------------------------------------------------------------------------
# Step 7 - Git repo push
# ---------------------------------------------------------------------------
def push_repo():
    info("Initialising the default Azure DevOps Git repository...")
    repo_url = sh_output(f'az repos show --repository "{AZDO_PROJECT}" --query remoteUrl -o tsv')

    if not repo_url:
        warn(f"Could not resolve repo URL for '{AZDO_PROJECT}'. Push to Azure Repos manually.")
        return

    if not os.path.isdir(".git"):
        info("Initialising local git repository...")
        sh("git init -b main")
        sh("git add -A")
        sh('git commit -m "chore: initial workshop scaffold" --allow-empty')
    else:
        count = sh_output("git rev-list --count HEAD") or "0"
        if count == "0":
            sh("git add -A")
            sh('git commit -m "chore: initial workshop scaffold" --allow-empty')

    existing = sh_output("git remote get-url azdo")
    if existing:
        sh(f"git remote set-url azdo {repo_url}")
    else:
        sh(f"git remote add azdo {repo_url}")

    result = sh("git push azdo HEAD:main --force", capture=True)
    if result.returncode == 0:
        success(f"Workshop source pushed to Azure DevOps repo: {repo_url}")
    else:
        warn("Git push failed. Authenticate and push manually: git push azdo HEAD:main")


# ---------------------------------------------------------------------------
# Step 8 - Import pipelines
# ---------------------------------------------------------------------------
def import_pipelines():
    pipelines = [
        ("InventoryAPI-CI", "pipelines/ci-pipeline.yml"),
        ("InventoryAPI-CD", "pipelines/cd-pipeline.yml"),
        ("InventoryAPI-MultiEnv", "pipelines/multi-env-pipeline.yml"),
    ]
    for name, yml_path in pipelines:
        info(f"Importing pipeline: {name}...")
        result = sh(
            f'az pipelines create --name "{name}" '
            f'--yml-path "{yml_path}" '
            f'--repository "{AZDO_PROJECT}" '
            f"--repository-type tfsgit --branch main "
            f"--skip-first-run true --output none",
            capture=True,
        )
        if result.returncode == 0:
            success(f"{name} pipeline imported.")
        else:
            warn(f"{name} pipeline import failed or already exists.")


# ---------------------------------------------------------------------------
# Step 9 - Artifacts feed
# ---------------------------------------------------------------------------
def create_artifacts_feed():
    info("Creating Artifacts feed: inventory-api-packages...")
    check = sh('az artifacts feed show --feed "inventory-api-packages"', capture=True)
    if check.returncode == 0:
        warn("Artifacts feed 'inventory-api-packages' already exists - skipping.")
        return
    result = sh('az artifacts feed create --name "inventory-api-packages" --output none', capture=True)
    if result.returncode == 0:
        success("Artifacts feed 'inventory-api-packages' created.")
    else:
        warn("Could not create Artifacts feed - create it manually in Azure Artifacts.")


# ---------------------------------------------------------------------------
# Step 10 - Test Plans
# ---------------------------------------------------------------------------
def create_test_plans():
    info("Creating Test Plan with sample test cases...")

    plan_data = sh_json('az testplan create --name "InventoryAPI - Workshop Test Plan" --output json')
    if not plan_data:
        warn("Could not create Test Plan - create it manually in Azure Test Plans.")
        return

    plan_id = plan_data.get("id")
    success(f"Test Plan created (ID: {plan_id})")

    root_suite_id = sh_output(f'az testplan suite list --plan-id {plan_id} --query "[0].id" -o tsv')

    suites = [
        (
            "API Smoke Tests",
            [
                "GET /health returns 200 with status=healthy",
                "GET /ready returns 200 with status=ready",
                "GET /api/products returns an array",
                "POST /api/products creates a new product",
                "GET /api/products/:id returns 404 for unknown id",
            ],
        ),
        (
            "Pipeline Validation",
            [
                "CI pipeline completes in under 5 minutes",
                "Docker image is tagged with the build number",
                "Image is visible in ACR after successful CI run",
                "CD deploys to dev namespace after CI succeeds",
                "Manual approval gate blocks staging deployment",
            ],
        ),
    ]

    for suite_name, test_cases in suites:
        suite_data = sh_json(
            f'az testplan suite create --plan-id {plan_id} '
            f'--parent-suite-id {root_suite_id} '
            f'--name "{suite_name}" --suite-type StaticTestSuite --output json'
        )
        suite_id = suite_data.get("id") if suite_data else None
        if not suite_id:
            warn(f"Could not create suite '{suite_name}'.")
            continue

        for tc_title in test_cases:
            tc_data = sh_json(f'az boards work-item create --type "Test Case" --title "{tc_title}" --output json')
            tc_id = tc_data.get("id") if tc_data else None
            if tc_id and suite_id:
                sh(f"az testplan case add --plan-id {plan_id} --suite-id {suite_id} --test-case-id {tc_id} --output none")

        success(f"Suite '{suite_name}' created with {len(test_cases)} test cases.")


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
def print_summary():
    acr_login_server = sh_output(f"az acr show --name {ACR_NAME} --query loginServer -o tsv")
    print()
    print("============================================================")
    print(f"  {GREEN}SETUP COMPLETE{RESET}")
    print("============================================================")
    print(f"  AKS Cluster      : {AKS_NAME}")
    print(f"  ACR              : {ACR_NAME}  ({acr_login_server})")
    print(f"  Namespaces       : dev | staging | production")
    print(f"  Azure DevOps Org : {AZDO_ORG}")
    print(f"  ADO Project      : {AZDO_PROJECT}")
    print(f"  Variable Groups  : InventoryAPI-Common, InventoryAPI-Environments")
    print(f"  Boards           : 1 Epic | 4 Features | 4 Stories | 14 Tasks | 2 Bugs")
    print(f"  Pipelines        : InventoryAPI-CI | InventoryAPI-CD | InventoryAPI-MultiEnv")
    print(f"  Artifacts Feed   : inventory-api-packages")
    print(f"  Test Plan        : InventoryAPI Workshop Test Plan (2 suites, 10 cases)")
    print("============================================================")
    print()
    print("  NEXT STEPS:")
    print(f"  1. Go to {AZDO_ORG}/{AZDO_PROJECT}/_library")
    print("     and manually add 'InventoryAPI-Secrets' linked to Key Vault")
    print("     (see pipelines/variable-groups/README-variable-groups.md)")
    print("  2. Create an Azure DevOps service connection to your AKS cluster")
    print("     (Project Settings -> Service connections -> New -> Kubernetes)")
    print("  3. Continue with labs/lab-02-ci-pipeline.md")
    print("============================================================")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    verify_tools()
    azure_login()
    connect_kubectl()
    create_namespaces()
    create_project()
    create_variable_groups()
    seed_boards()
    push_repo()
    import_pipelines()
    create_artifacts_feed()
    create_test_plans()
    print_summary()


if __name__ == "__main__":
    main()
