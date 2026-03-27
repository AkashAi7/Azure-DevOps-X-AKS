# Azure DevOps Variable Groups Setup

## Overview
Variable groups securely store values and secrets that are passed to pipelines.
This guide explains how to configure the variable groups used in this workshop.

---

## Group 1: `InventoryAPI-Common`
**Purpose:** Non-secret configuration values  
**Access:** All pipelines in this project

| Variable Name | Example Value | Description |
|---|---|---|
| `ACR_NAME` | `workshopacr01` | Azure Container Registry name (without .azurecr.io) |
| `AKS_RESOURCE_GROUP` | `rg-workshop-aks` | Resource group containing the AKS cluster |
| `AKS_CLUSTER_NAME` | `aks-workshop-01` | AKS cluster name |
| `AZURE_SUBSCRIPTION_ID` | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` | Azure Subscription ID |

### How to create:
1. Navigate to **Pipelines** → **Library** in Azure DevOps
2. Click **+ Variable group**
3. Name it `InventoryAPI-Common`
4. Add each variable above
5. Click **Save**

---

## Group 2: `InventoryAPI-Secrets`
**Purpose:** Sensitive secrets linked to Azure Key Vault  
**Access:** Only authorized pipelines (use authorization restrictions)

| Secret Name (Key Vault) | Used As Variable | Description |
|---|---|---|
| `acr-admin-password` | `ACR_ADMIN_PASSWORD` | ACR admin password |
| `aks-service-principal-secret` | `AKS_SP_SECRET` | AKS service principal secret (if using SP auth) |

### How to link to Key Vault:
1. Navigate to **Pipelines** → **Library**
2. Click **+ Variable group**
3. Name it `InventoryAPI-Secrets`
4. Toggle **Link secrets from Azure Key Vault**
5. Select your service connection and Key Vault
6. Add the secrets by name
7. Click **Save**

---

## Group 3: `InventoryAPI-Environments`
**Purpose:** Environment-specific overrides

| Variable Name | Dev Value | Staging Value | Prod Value |
|---|---|---|---|
| `K8S_REPLICAS` | `1` | `2` | `3` |
| `LOG_LEVEL` | `debug` | `info` | `warn` |
| `API_BASE_URL` | `http://dev.inventory-api.workshop.local` | `http://staging.inventory-api.workshop.local` | `https://api.inventory.workshop.io` |

---

## Using Variables in Pipelines

```yaml
# Reference a group
variables:
  - group: InventoryAPI-Common
  - group: InventoryAPI-Secrets

# Use a variable
steps:
  - script: echo "ACR Name is $(ACR_NAME)"
  
# Secret variables are masked in logs
  - script: echo "$(ACR_ADMIN_PASSWORD)"   # Will print *** in logs
```

---

## Security Best Practices

1. **Never store secrets inline in YAML** — always use variable groups or Key Vault
2. **Restrict variable group access** — only allow specific pipelines to use production secrets
3. **Use secret variables** — mark sensitive variables as secret so they are masked in logs
4. **Rotate secrets regularly** — update Key Vault secrets on a schedule
5. **Audit access** — periodically review who has access to variable groups
