#!/usr/bin/env bash
# =============================================================================
# install-dependencies.sh
# Fortis Workshop - Install all required tools on macOS / Linux
#
# What this script does:
#   1. Detects the OS (macOS or Linux)
#   2. Installs or updates: Azure CLI, kubectl, Docker, Node.js LTS, Git
#   3. Installs the Azure DevOps CLI extension
#   4. Validates all tool versions after installation
#
# Usage:
#   chmod +x scripts/install-dependencies.sh
#   ./scripts/install-dependencies.sh
#
# Notes:
#   - On macOS, Homebrew is required (script will install it if missing)
#   - Docker Desktop on macOS requires manual download for Apple Silicon
#   - On Linux, the script supports apt-based distros (Ubuntu/Debian)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { echo -e "\n\033[1;34m[INFO]\033[0m  $*"; }
success() { echo -e "\033[1;32m[DONE]\033[0m  $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
fail()    { echo -e "\033[1;31m[FAIL]\033[0m  $*"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

OS="$(uname -s)"

# ---------------------------------------------------------------------------
# macOS: Ensure Homebrew is available
# ---------------------------------------------------------------------------
ensure_homebrew() {
    if command_exists brew; then
        success "Homebrew is available."
        return
    fi
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for Apple Silicon Macs
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    success "Homebrew installed."
}

# ---------------------------------------------------------------------------
# Step 1 - Azure CLI
# ---------------------------------------------------------------------------
install_azure_cli() {
    info "Checking Azure CLI..."
    if command_exists az; then
        local ver
        ver=$(az version -o tsv --query '"azure-cli"' 2>/dev/null || echo "unknown")
        success "Azure CLI already installed (v${ver})."
        return
    fi

    if [[ "$OS" == "Darwin" ]]; then
        info "Installing Azure CLI via Homebrew..."
        brew install azure-cli
    else
        info "Installing Azure CLI via Microsoft install script..."
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    fi
    success "Azure CLI installed."
}

# ---------------------------------------------------------------------------
# Step 2 - kubectl
# ---------------------------------------------------------------------------
install_kubectl() {
    info "Checking kubectl..."
    if command_exists kubectl; then
        local ver
        ver=$(kubectl version --client -o json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['clientVersion']['gitVersion'])" 2>/dev/null || echo "unknown")
        success "kubectl already installed (${ver})."
        return
    fi

    if command_exists az; then
        info "Installing kubectl via az aks install-cli..."
        sudo az aks install-cli
    elif [[ "$OS" == "Darwin" ]]; then
        info "Installing kubectl via Homebrew..."
        brew install kubectl
    else
        info "Installing kubectl via apt..."
        sudo apt-get update && sudo apt-get install -y kubectl 2>/dev/null || {
            info "Falling back to direct download..."
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            rm -f kubectl
        }
    fi
    success "kubectl installed."
}

# ---------------------------------------------------------------------------
# Step 3 - Docker
# ---------------------------------------------------------------------------
install_docker() {
    info "Checking Docker..."
    if command_exists docker; then
        local ver
        ver=$(docker --version 2>/dev/null || echo "unknown")
        success "Docker already installed (${ver})."
        return
    fi

    if [[ "$OS" == "Darwin" ]]; then
        info "Installing Docker Desktop via Homebrew Cask..."
        brew install --cask docker
        warn "Docker Desktop installed. Open it from Applications to complete setup."
        warn "After first launch, Docker needs a few minutes to start the daemon."
    else
        info "Installing Docker Engine on Linux..."
        curl -fsSL https://get.docker.com | sudo sh
        sudo usermod -aG docker "$USER" 2>/dev/null || true
        success "Docker installed. You may need to log out and back in for group changes."
    fi
}

# ---------------------------------------------------------------------------
# Step 4 - Node.js LTS
# ---------------------------------------------------------------------------
install_node() {
    info "Checking Node.js..."
    if command_exists node; then
        local ver npm_ver
        ver=$(node --version 2>/dev/null || echo "unknown")
        npm_ver=$(npm --version 2>/dev/null || echo "unknown")
        success "Node.js already installed (${ver}, npm ${npm_ver})."
        return
    fi

    if [[ "$OS" == "Darwin" ]]; then
        info "Installing Node.js LTS via Homebrew..."
        brew install node@22
        brew link node@22 --overwrite --force 2>/dev/null || true
    else
        info "Installing Node.js LTS via NodeSource..."
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
    success "Node.js LTS installed."
}

# ---------------------------------------------------------------------------
# Step 5 - Git
# ---------------------------------------------------------------------------
install_git() {
    info "Checking Git..."
    if command_exists git; then
        local ver
        ver=$(git --version 2>/dev/null || echo "unknown")
        success "Git already installed (${ver})."
        return
    fi

    if [[ "$OS" == "Darwin" ]]; then
        info "Installing Git via Homebrew..."
        brew install git
    else
        info "Installing Git via apt..."
        sudo apt-get update && sudo apt-get install -y git
    fi
    success "Git installed."
}

# ---------------------------------------------------------------------------
# Step 6 - Azure DevOps CLI extension
# ---------------------------------------------------------------------------
install_azdo_extension() {
    info "Checking Azure DevOps CLI extension..."
    if command_exists az; then
        if az extension show --name azure-devops &>/dev/null; then
            success "Azure DevOps CLI extension already installed."
        else
            info "Installing Azure DevOps CLI extension..."
            az extension add --name azure-devops --output none
            success "Azure DevOps CLI extension installed."
        fi
    else
        warn "Azure CLI not yet available in this session. Run later:"
        warn "  az extension add --name azure-devops"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
echo "  Fortis Workshop - Dependency Installer"
echo "  OS detected: $OS"
echo "============================================"

if [[ "$OS" == "Darwin" ]]; then
    ensure_homebrew
fi

install_azure_cli
install_kubectl
install_docker
install_node
install_git
install_azdo_extension

# ---------------------------------------------------------------------------
# Final validation
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
echo "  INSTALLATION SUMMARY"
echo "============================================"

check_tool() {
    local name="$1" cmd="$2"
    if command_exists "$cmd"; then
        local ver
        ver=$("$cmd" --version 2>/dev/null | head -1 || echo "installed")
        echo -e "  \033[1;32m[OK]\033[0m   ${name}: ${ver}"
    else
        echo -e "  \033[1;31m[MISS]\033[0m ${name}: not found - restart terminal or install manually"
    fi
}

check_tool "Azure CLI" "az"
check_tool "kubectl"   "kubectl"
check_tool "Docker"    "docker"
check_tool "Node.js"   "node"
check_tool "npm"       "npm"
check_tool "Git"       "git"

echo ""
echo "Minimum recommended versions:"
echo "  Azure CLI >= 2.55"
echo "  kubectl   >= 1.28"
echo "  Node.js   >= 20"
echo "  Git       >= 2.40"
echo "  Docker    >= 24"
echo ""

if ! command_exists docker; then
    warn "Docker may require a restart or manual setup."
    if [[ "$OS" == "Darwin" ]]; then
        warn "Open Docker Desktop from Applications after install."
    fi
fi

success "Dependency installation complete. Restart your terminal if any tools are missing."
