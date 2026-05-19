# MCP Server Configuration for Azure DevOps and AKS

This directory contains reference configurations and example prompts for using
**Model Context Protocol (MCP)** servers with GitHub Copilot in the context of
this workshop.

## What is MCP?

The Model Context Protocol (MCP) is an open standard (originally developed by
Anthropic, now widely adopted) that allows AI assistants to connect to external
tools and live data sources through a consistent interface.

In practice, it means GitHub Copilot can:
- Query your real Azure DevOps work items, pipelines, and repos
- Inspect your live AKS cluster resources, pod logs, and events
- Take actions on your behalf (create work items, apply manifests, etc.)

## MCP Servers in This Workshop

| Server | npm package | Purpose |
|---|---|---|
| Azure DevOps MCP | `@azure-devops/mcp` | Azure Boards, Repos, Pipelines, Artifacts |
| Azure MCP | `@azure/mcp` | Azure resources including AKS clusters |

## Quick Start

### 1. Install the MCP Servers

```bash
npm install -g @azure-devops/mcp @azure/mcp
```

### 2. Log in to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 3. Configure VS Code

Copy `vscode-mcp-config.json` from this directory to `.vscode/mcp.json` in the
repo root, then fill in your values:

```bash
cp mcp/vscode-mcp-config.json .vscode/mcp.json
# Edit .vscode/mcp.json and replace all <placeholder> values
```

> **Important:** `.vscode/mcp.json` is listed in `.gitignore` in this repo.
> Never commit a file that contains a Personal Access Token.

### 4. Open VS Code and Enable Agent Mode

1. Open VS Code: `code .`
2. Press `Ctrl+Shift+I` to open Copilot Chat
3. Click the dropdown → switch to **Agent**
4. The MCP tool panel (plug icon) should list Azure DevOps and Azure tools

## Secure Configuration Pattern

### Option A: Environment Variable References (Recommended)

The `vscode-mcp-config.json` file in this directory uses `${env:VAR_NAME}`
syntax so that no secrets are stored in the file itself:

```json
{
  "servers": {
    "azure-devops": {
      "env": {
        "AZURE_DEVOPS_PAT": "${env:AZURE_DEVOPS_PAT}"
      }
    }
  }
}
```

Before opening VS Code, source your `workshop.env`:

```bash
source workshop.env   # sets AZURE_DEVOPS_PAT and other variables
code .
```

### Option B: Azure CLI Authentication (No PAT Required)

The Azure MCP server supports Azure CLI authentication. If you are already
logged in with `az login`, you do not need to set any additional credentials for
the Azure MCP server — it reuses your active Azure CLI session.

For the Azure DevOps MCP server, Azure CLI authentication is supported via the
`AZURE_DEVOPS_AUTH_TYPE=az` environment variable (check the server docs for the
current supported version).

## Azure DevOps PAT Scopes

Generate a PAT at **Azure DevOps → User Settings → Personal Access Tokens** with
exactly the scopes you need:

| Capability | Required Scope |
|---|---|
| Read work items | Work Items: Read |
| Create / update work items | Work Items: Read & Write |
| Read pipeline runs and logs | Build: Read |
| Trigger a pipeline run | Build: Read & Execute |
| Read repository files | Code: Read |
| Read test results | Test Management: Read |
| Read release / environment history | Release: Read |

**Always use the minimum scope needed for your use case.**

## Rotating Credentials

After the workshop, revoke your PAT:

1. Azure DevOps → User Settings → Personal Access Tokens
2. Find `MCP-Workshop-Token` → click **Revoke**
3. Remove or clear `.vscode/mcp.json` from your local machine

## Files in This Directory

| File | Purpose |
|---|---|
| `README.md` | This file — overview and quick start |
| `vscode-mcp-config.json` | Reference VS Code MCP configuration (no secrets — uses env vars) |
| `example-prompts.md` | Curated example prompts to try with both MCP servers |

## References

- Azure DevOps MCP server: https://github.com/microsoft/azure-devops-mcp
- Azure MCP server: https://github.com/Azure/azure-mcp
- MCP specification: https://spec.modelcontextprotocol.io
- GitHub Copilot MCP docs: https://docs.github.com/en/copilot/using-github-copilot/using-mcp-with-github-copilot
