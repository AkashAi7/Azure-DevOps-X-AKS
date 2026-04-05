#!/usr/bin/env python3
"""
participant-setup.py
Fortis Workshop - Cross-platform participant environment setup

What this script does:
  1. Validates all required tools are installed
  2. Logs in to Azure and sets the workshop subscription
  3. Connects kubectl to the workshop AKS cluster
  4. Validates namespaces and cluster health
  5. Clones the workshop repo from Azure Repos
  6. Installs sample app dependencies and runs tests
  7. Verifies Azure DevOps project access

Usage:
  python scripts/participant-setup.py

Before running, update the CONFIGURATION section below with values
from your workshop facilitator.
"""

import json
import os
import platform
import shutil
import subprocess
import sys

# ---------------------------------------------------------------------------
# CONFIGURATION - Get these values from your workshop facilitator
# Auto-loaded from workshop.env if present (just drop the file in the repo root)
# ---------------------------------------------------------------------------

SUBSCRIPTION_ID = ""                                   # <<< Azure subscription ID
AKS_RESOURCE_GROUP = "rg-workshop-aks"                 # <<< AKS resource group
AKS_CLUSTER_NAME = "aks-workshop-01"                   # <<< AKS cluster name
AZDO_ORG = "https://dev.azure.com/<your-org>"          # <<< Azure DevOps org URL
AZDO_PROJECT = "workshop-project"                      # <<< Azure DevOps project name
CLONE_URL = ""                                         # <<< Azure Repos clone URL (optional)

# --- Auto-load from workshop.env if the file exists ---
def _load_env():
    global SUBSCRIPTION_ID, AKS_RESOURCE_GROUP, AKS_CLUSTER_NAME
    global AZDO_ORG, AZDO_PROJECT, CLONE_URL
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
                        "AKS_CLUSTER_NAME": "AKS_CLUSTER_NAME",
                        "AZDO_ORG": "AZDO_ORG",
                        "AZDO_PROJECT": "AZDO_PROJECT",
                        "AZDO_CLONE_URL": "CLONE_URL",
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


def run(cmd, check=False, capture=False, shell=False):
    kwargs = {"shell": shell}
    if capture:
        kwargs["stdout"] = subprocess.PIPE
        kwargs["stderr"] = subprocess.PIPE
        kwargs["text"] = True
    return subprocess.run(cmd if shell else cmd.split(), check=check, **kwargs)


def run_output(cmd, shell=False):
    try:
        r = subprocess.run(
            cmd if shell else cmd.split(),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            shell=shell,
        )
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:
        return ""


# ---------------------------------------------------------------------------
# Step 1 - Validate prerequisites
# ---------------------------------------------------------------------------
def check_prerequisites():
    print()
    print("============================================")
    print("  Fortis Workshop - Participant Setup")
    print(f"  OS: {platform.system()} ({platform.machine()})")
    print("============================================")

    info("Checking required tools...")

    tools = [
        ("Azure CLI", "az"),
        ("kubectl", "kubectl"),
        ("Docker", "docker"),
        ("Node.js", "node"),
        ("npm", "npm"),
        ("Git", "git"),
    ]

    all_present = True
    for name, cmd in tools:
        if command_exists(cmd):
            ver = run_output(f"{cmd} --version")
            ver = ver.split("\n")[0] if ver else "installed"
            print(f"  {GREEN}[OK]{RESET}   {name}: {ver}")
        else:
            print(f"  {RED}[MISS]{RESET} {name}: NOT FOUND")
            all_present = False

    if not all_present:
        print()
        fail("Some required tools are missing. Run install-dependencies.py first:")
        fail("  python scripts/install-dependencies.py")
        sys.exit(1)

    success("All required tools are available.")


# ---------------------------------------------------------------------------
# Step 2 - Azure login
# ---------------------------------------------------------------------------
def azure_login():
    info("Logging in to Azure...")
    run("az login --output none", shell=True, check=True)

    if SUBSCRIPTION_ID:
        run(f"az account set --subscription {SUBSCRIPTION_ID}", shell=True, check=True)

    run("az account show --query \"{Name:name, ID:id}\" -o table", shell=True)
    success("Azure login complete.")


# ---------------------------------------------------------------------------
# Step 3 - Connect to AKS
# ---------------------------------------------------------------------------
def connect_aks():
    info(f"Connecting kubectl to AKS cluster: {AKS_CLUSTER_NAME}...")
    run(
        f"az aks get-credentials --resource-group {AKS_RESOURCE_GROUP} "
        f"--name {AKS_CLUSTER_NAME} --overwrite-existing",
        shell=True,
        check=True,
    )
    success("kubectl connected to AKS.")


# ---------------------------------------------------------------------------
# Step 4 - Validate cluster
# ---------------------------------------------------------------------------
def validate_cluster():
    info("Checking cluster nodes...")
    run("kubectl get nodes", shell=True)

    info("Checking workshop namespaces...")
    ns_output = run_output("kubectl get namespaces -o jsonpath={.items[*].metadata.name}")
    namespaces = ns_output.split()
    missing = []

    for ns in ["dev", "staging", "production"]:
        if ns in namespaces:
            print(f"  {GREEN}[OK]{RESET}   Namespace: {ns}")
        else:
            print(f"  {RED}[MISS]{RESET} Namespace: {ns}")
            missing.append(ns)

    if missing:
        warn(f"Missing namespaces: {', '.join(missing)}. Contact your workshop admin.")
    else:
        success("All workshop namespaces are present.")


# ---------------------------------------------------------------------------
# Step 5 - Azure DevOps CLI
# ---------------------------------------------------------------------------
def setup_azdo():
    info("Setting up Azure DevOps CLI...")
    check = run("az extension show --name azure-devops", capture=True)
    if check.returncode != 0:
        run("az extension add --name azure-devops --output none", shell=True)

    run(
        f'az devops configure --defaults organization="{AZDO_ORG}" project="{AZDO_PROJECT}"',
        shell=True,
    )

    info("Verifying Azure DevOps project access...")
    result = run(
        f'az devops project show --project "{AZDO_PROJECT}" --query "{{name:name,state:state}}" -o table',
        shell=True,
        capture=True,
    )
    if result.returncode == 0:
        print(result.stdout)
        success("Azure DevOps project accessible.")
    else:
        warn(f"Could not access project '{AZDO_PROJECT}'. Check your permissions with the facilitator.")


# ---------------------------------------------------------------------------
# Step 6 - Clone repo
# ---------------------------------------------------------------------------
def clone_repo():
    clone_url = CLONE_URL

    if not clone_url:
        clone_url = run_output(
            'az repos show --repository "Fortis-Workshop" --query remoteUrl -o tsv',
            shell=True,
        )
    if not clone_url:
        clone_url = run_output(
            f'az repos show --repository "{AZDO_PROJECT}" --query remoteUrl -o tsv',
            shell=True,
        )

    if clone_url:
        info("Cloning workshop repository...")
        target = "Fortis-Workshop"
        if os.path.isdir(target):
            warn(f"Directory '{target}' already exists. Pulling latest changes...")
            run(f"git -C {target} pull --rebase", shell=True)
        else:
            run(f"git clone {clone_url} {target}", shell=True, check=True)
        success(f"Repository ready at: {target}")
    else:
        warn("Could not determine clone URL. Clone manually using the URL from Azure Repos.")


# ---------------------------------------------------------------------------
# Step 7 - npm install + test
# ---------------------------------------------------------------------------
def setup_sample_app():
    app_dir = None
    for candidate in ["Fortis-Workshop/sample-app", "sample-app"]:
        if os.path.isdir(candidate):
            app_dir = candidate
            break

    if not app_dir:
        warn("sample-app directory not found. Skipping npm install/test.")
        return

    info("Installing sample app dependencies...")
    run(f"npm install --prefix {app_dir}", shell=True)

    info("Running sample app tests...")
    result = run(f"npm test --prefix {app_dir}", shell=True)
    if result.returncode == 0:
        success("All tests passed.")
    else:
        warn("Some tests failed. Review the output above.")


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
def print_summary():
    sub_name = run_output("az account show --query name -o tsv", shell=True)
    print()
    print("============================================")
    print("  SETUP COMPLETE")
    print("============================================")
    print(f"  Subscription : {sub_name}")
    print(f"  AKS Cluster  : {AKS_CLUSTER_NAME}")
    print(f"  AzDo Project : {AZDO_PROJECT}")
    print()
    print("  Next steps:")
    print(f"    1. Open Azure DevOps: {AZDO_ORG}/{AZDO_PROJECT}")
    print("    2. Assign yourself a work item in Boards")
    print("    3. Proceed to Lab 02: CI Pipeline")
    print()
    success("You are ready for the workshop!")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    check_prerequisites()
    azure_login()
    connect_aks()
    validate_cluster()
    setup_azdo()
    clone_repo()
    setup_sample_app()
    print_summary()


if __name__ == "__main__":
    main()
