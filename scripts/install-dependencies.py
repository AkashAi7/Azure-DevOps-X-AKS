#!/usr/bin/env python3
"""
install-dependencies.py
Fortis Workshop - Cross-platform dependency installer (Windows / macOS / Linux)

What this script does:
  1. Detects the OS
  2. Installs or verifies: Azure CLI, kubectl, Docker, Node.js LTS, Git
  3. Installs the Azure DevOps CLI extension
  4. Prints a validation summary

Usage:
  python scripts/install-dependencies.py

Notes:
  - Windows: uses winget
  - macOS: uses Homebrew (installs it if missing)
  - Linux: uses apt (Ubuntu/Debian)
  - Docker Desktop may require a restart after first install
  - Run with admin/sudo if package installs fail
"""

import os
import platform
import shutil
import subprocess
import sys

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
    """Run a command, optionally capturing output."""
    kwargs = {"shell": shell}
    if capture:
        kwargs["stdout"] = subprocess.PIPE
        kwargs["stderr"] = subprocess.PIPE
        kwargs["text"] = True
    result = subprocess.run(cmd if shell else cmd.split(), check=check, **kwargs)
    return result


def run_output(cmd, shell=False):
    """Run a command and return stripped stdout."""
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


OS = platform.system()  # "Windows", "Darwin", "Linux"

# ---------------------------------------------------------------------------
# Per-tool installers
# ---------------------------------------------------------------------------

def install_azure_cli():
    info("Checking Azure CLI...")
    if command_exists("az"):
        ver = run_output("az version -o tsv --query \"azure-cli\"", shell=True)
        success(f"Azure CLI already installed (v{ver}).")
        return
    if OS == "Windows":
        info("Installing Azure CLI via winget...")
        run("winget install --id Microsoft.AzureCLI --accept-source-agreements --accept-package-agreements --silent", shell=True)
    elif OS == "Darwin":
        info("Installing Azure CLI via Homebrew...")
        run("brew install azure-cli", shell=True)
    else:
        info("Installing Azure CLI via Microsoft install script...")
        run("curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash", shell=True)
    success("Azure CLI installed. You may need to restart your terminal.")


def install_kubectl():
    info("Checking kubectl...")
    if command_exists("kubectl"):
        ver = run_output("kubectl version --client -o json", shell=False)
        success(f"kubectl already installed.")
        return
    if command_exists("az"):
        info("Installing kubectl via az aks install-cli...")
        run("az aks install-cli", shell=True)
    elif OS == "Windows":
        info("Installing kubectl via winget...")
        run("winget install --id Kubernetes.kubectl --accept-source-agreements --accept-package-agreements --silent", shell=True)
    elif OS == "Darwin":
        info("Installing kubectl via Homebrew...")
        run("brew install kubectl", shell=True)
    else:
        info("Installing kubectl via direct download...")
        run("curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl", shell=True)
        run("sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl", shell=True)
    success("kubectl installed.")


def install_docker():
    info("Checking Docker...")
    if command_exists("docker"):
        ver = run_output("docker --version")
        success(f"Docker already installed ({ver}).")
        return
    if OS == "Windows":
        info("Installing Docker Desktop via winget...")
        run("winget install --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements --silent", shell=True)
        warn("Docker Desktop installed. A RESTART may be required.")
    elif OS == "Darwin":
        info("Installing Docker Desktop via Homebrew Cask...")
        run("brew install --cask docker", shell=True)
        warn("Docker Desktop installed. Open it from Applications to complete setup.")
    else:
        info("Installing Docker Engine on Linux...")
        run("curl -fsSL https://get.docker.com | sudo sh", shell=True)
        success("Docker installed. You may need to log out and back in for group changes.")


def install_node():
    info("Checking Node.js...")
    if command_exists("node"):
        ver = run_output("node --version")
        npm_ver = run_output("npm --version")
        success(f"Node.js already installed ({ver}, npm {npm_ver}).")
        return
    if OS == "Windows":
        info("Installing Node.js LTS via winget...")
        run("winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements --silent", shell=True)
    elif OS == "Darwin":
        info("Installing Node.js LTS via Homebrew...")
        run("brew install node@22", shell=True)
        run("brew link node@22 --overwrite --force", shell=True)
    else:
        info("Installing Node.js LTS via NodeSource...")
        run("curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -", shell=True)
        run("sudo apt-get install -y nodejs", shell=True)
    success("Node.js LTS installed.")


def install_git():
    info("Checking Git...")
    if command_exists("git"):
        ver = run_output("git --version")
        success(f"Git already installed ({ver}).")
        return
    if OS == "Windows":
        info("Installing Git via winget...")
        run("winget install --id Git.Git --accept-source-agreements --accept-package-agreements --silent", shell=True)
    elif OS == "Darwin":
        info("Installing Git via Homebrew...")
        run("brew install git", shell=True)
    else:
        info("Installing Git via apt...")
        run("sudo apt-get update && sudo apt-get install -y git", shell=True)
    success("Git installed.")


def install_azdo_extension():
    info("Checking Azure DevOps CLI extension...")
    if not command_exists("az"):
        warn("Azure CLI not available in this session. Restart terminal, then run:")
        warn("  az extension add --name azure-devops")
        return
    check = run("az extension show --name azure-devops", capture=True)
    if check.returncode == 0:
        success("Azure DevOps CLI extension already installed.")
    else:
        info("Installing Azure DevOps CLI extension...")
        run("az extension add --name azure-devops --output none", shell=True)
        success("Azure DevOps CLI extension installed.")


def ensure_homebrew():
    if command_exists("brew"):
        success("Homebrew is available.")
        return
    info("Installing Homebrew...")
    run('/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"', shell=True)
    success("Homebrew installed.")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    print()
    print("============================================")
    print("  Fortis Workshop - Dependency Installer")
    print(f"  OS detected: {OS} ({platform.machine()})")
    print("============================================")

    if OS == "Windows":
        if not command_exists("winget"):
            fail("winget is not available. Install App Installer from the Microsoft Store.")
            fail("https://aka.ms/getwinget")
            sys.exit(1)
    elif OS == "Darwin":
        ensure_homebrew()

    install_azure_cli()
    install_kubectl()
    install_docker()
    install_node()
    install_git()
    install_azdo_extension()

    # Validation summary
    print()
    print("============================================")
    print("  INSTALLATION SUMMARY")
    print("============================================")

    tools = [
        ("Azure CLI", "az"),
        ("kubectl", "kubectl"),
        ("Docker", "docker"),
        ("Node.js", "node"),
        ("npm", "npm"),
        ("Git", "git"),
    ]

    for name, cmd in tools:
        if command_exists(cmd):
            ver = run_output(f"{cmd} --version")
            ver = ver.split("\n")[0] if ver else "installed"
            print(f"  {GREEN}[OK]{RESET}   {name}: {ver}")
        else:
            print(f"  {RED}[MISS]{RESET} {name}: not found - restart terminal or install manually")

    print()
    print("Minimum recommended versions:")
    for name, ver in [("Azure CLI", "2.55"), ("kubectl", "1.28"), ("Node.js", "20"), ("Git", "2.40"), ("Docker", "24")]:
        print(f"  {name} >= {ver}")
    print()

    if not command_exists("docker"):
        warn("Docker Desktop may require a system restart after first install.")

    success("Dependency installation complete. Restart your terminal if any tools are missing.")


if __name__ == "__main__":
    main()
