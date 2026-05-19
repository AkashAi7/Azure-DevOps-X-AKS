# Azure DevOps Installation And Basic Setup

This guide is written for a beginner. It explains the Azure DevOps setup step by step and assumes the reader may be using Azure DevOps for the first time.

This guide covers:

- Creating the Azure DevOps organization
- Creating the Azure DevOps project
- Creating the repository
- Giving repository read access
- Setting up pipeline agents
- Creating Azure service connections

This guide does not cover detailed application deployment steps. It only prepares Azure DevOps so the workshop pipelines can run.

## How To Use Screenshot Placeholders In This Guide

This guide now includes screenshot placeholders.

Each placeholder tells you what screen to capture and what should be visible in the image.

If you are turning this guide into a handout or customer-facing document:

1. Take a screenshot at that exact step.
2. Paste the screenshot below the placeholder.
3. Keep any private subscription IDs, tenant IDs, email addresses, and secrets hidden.

Use a rectangle blur or crop sensitive information before sharing screenshots.

## What You Should Have When You Finish

By the end of this guide, you should have all of the following:

- One Azure DevOps organization
- One Azure DevOps project
- Azure Repos enabled
- Azure Pipelines enabled
- One repository ready for workshop files
- Repository read access granted where needed
- At least one working pipeline agent option
- At least one Azure Resource Manager service connection

## Before You Start

Before you begin, make sure you have:

- A Microsoft account or work account that can sign in to Azure DevOps
- Access to an Azure subscription
- Permission to create resources in Azure, or an Azure administrator who can help
- Permission to create or manage Azure DevOps projects, or an Azure DevOps administrator who can help

If you do not have admin rights, you can still follow the guide, but you may need to stop and ask an administrator to complete some steps for you.

## 1. Create An Azure DevOps Organization

An Azure DevOps organization is the top-level container that holds your projects, repositories, pipelines, and users.

> Screenshot placeholder:
> Capture the Azure DevOps home page before the organization is created.
> The image should show the **Create new organization** option.

Follow these steps:

1. Open https://dev.azure.com/ in your browser.
2. Sign in with your Microsoft account or work account.
3. If this is your first time, Azure DevOps may ask you to confirm basic profile details.
4. Look for a button such as **Create new organization**.
5. Select the button.
6. Choose the country or region closest to your users if Azure DevOps asks for it.
7. Complete the organization creation steps.

When finished, you should land on the home page of the new Azure DevOps organization.

> Screenshot placeholder:
> Capture the organization landing page after creation.
> The image should show the organization name in the top area.

Important:

- Use Azure DevOps Services in the browser.
- Do not install Azure DevOps Server for this workshop unless your company already requires it.

## 2. Create A Project

An Azure DevOps project is where you keep the repo, pipelines, boards, and permissions for one solution or workshop.

> Screenshot placeholder:
> Capture the **New Project** screen.
> The image should show the project name field and visibility selection.

Follow these steps:

1. In your Azure DevOps organization, look for **New Project**.
2. Select **New Project**.
3. Enter a project name, for example `workshop-demo`.
4. Add a short description if you want.
5. Set visibility to `Private` unless you have a reason to make it public.
6. Select **Create**.

When the project opens, you should see the left-side menu with items such as **Overview**, **Repos**, and **Pipelines**.

> Screenshot placeholder:
> Capture the newly created project home page.
> The image should show the left navigation menu.

## 3. Confirm That Repos And Pipelines Are Available

For the workshop, you need both source control and pipelines.

Follow these checks:

1. In the project menu, select **Repos**.
2. Confirm that the repo page opens.
3. Go back to the project menu.
4. Select **Pipelines**.
5. Confirm that the pipelines page opens.

If either menu item is missing or disabled:

1. Ask the Azure DevOps project administrator to confirm the service is enabled.
2. Ask whether organization policy is hiding or disabling that service.

Do not continue until both **Repos** and **Pipelines** are available.

> Screenshot placeholder:
> Capture the left navigation with **Repos** and **Pipelines** visible.
> The image should prove that both services are enabled in the project.

## 4. Install Basic Local Tools

Azure DevOps itself runs in the browser, so there is no local Azure DevOps application that you need to install for this workshop.

You should still install a few tools on your machine so you can work with the repository and sample application.

Required tools:

- Git
- Visual Studio Code
- Node.js 20 or later

Optional but strongly recommended:

- Azure CLI
- Docker Desktop

Why these tools matter:

- Git lets you clone and push code.
- Visual Studio Code lets you edit files.
- Node.js is needed for the sample app.
- Azure CLI helps with Azure login and troubleshooting.
- Docker Desktop helps if you want to test containers locally.

After installation, sign out and sign back in if your machine requires it before terminal commands are recognized.

> Screenshot placeholder:
> Capture a local terminal window showing version checks such as `git --version`, `node --version`, and `az version` if Azure CLI is installed.
> The image should show that the tools are available on the machine.

## 5. Create The Repository

The repository is where your application code and pipeline YAML files will live.

Follow these steps:

1. In Azure DevOps, open your project.
2. Select **Repos**.
3. If no repo exists yet, Azure DevOps usually shows a repo creation screen.
4. Enter a repo name such as `workshop-demo`.
5. Select **Create**.

If a repository already exists and you want to use that one instead:

1. Confirm it is the correct repository.
2. Confirm it will contain the workshop application and pipeline files.

At this point, the repository exists, but it may still be empty.

> Screenshot placeholder:
> Capture the Azure Repos page after the repository is created.
> The image should show the repository name in the repo selector.

## 6. Give Repository Read Access

This section is important. People and pipelines both need access to the repository.

There are two common cases:

- A human user needs read access so they can clone or view the repo.
- A pipeline identity needs read access so it can check out the source code during a build.

### 6.1 Give A Human User Read Access To The Repository

> Screenshot placeholder:
> Capture the repository security page before permissions are changed.
> The image should show the user or group picker and the permission list.

Follow these steps:

1. Open your Azure DevOps project.
2. In the lower-left area, select **Project settings**.
3. Under the **Repos** section, select **Repositories**.
4. Select the repository you created for the workshop.
5. Open the **Security** tab or security page for that repository.
6. In the user or group selection box, search for the user or group that needs access.
7. Select the user or group.
8. Find the permission named **Read**.
9. Set **Read** to **Allow**.
10. Leave other permissions unchanged unless you know they are also needed.

If the user also needs to push changes:

1. Find the permission named **Contribute**.
2. Set **Contribute** to **Allow**.

Use the simplest permission set possible:

- `Read` if the user only needs to view or clone
- `Read` and `Contribute` if the user needs to push code

> Screenshot placeholder:
> Capture the repository security page after **Read** is set to **Allow** for the user.
> The image should show the selected user and the permission setting.

### 6.2 Give The Pipeline Identity Read Access To The Repository

> Screenshot placeholder:
> Capture the same repository security page while searching for the build identity.
> The image should show the build service identity selected.

Most Azure DevOps pipelines automatically get repo access if project permissions are left at their defaults. However, if the project or repo has been locked down, the pipeline may fail to check out code unless you grant explicit access.

The identity usually looks like one of these:

- `<Project Name> Build Service (<Organization Name>)`
- `Project Collection Build Service Accounts`

Follow these steps:

1. Open **Project settings**.
2. Select **Repositories** under the **Repos** area.
3. Select your workshop repository.
4. Open the **Security** page.
5. Search for `<Project Name> Build Service (<Organization Name>)`.
6. If you cannot find it, search for `Project Collection Build Service Accounts`.
7. Select the correct build identity.
8. Find the permission named **Read**.
9. Set **Read** to **Allow**.
10. Save or leave the page after the change is applied.

If your pipeline only needs to read source code, `Read` is enough.

If your pipeline will write back to the repo, create tags, or push generated files, you may also need:

- `Contribute`
- `Create tag`
- `Read and manage`

Do not grant extra permissions unless the pipeline actually needs them.

> Screenshot placeholder:
> Capture the build identity permission screen after **Read** is set to **Allow**.
> The image should show that the pipeline identity can read the repo.

### 6.3 Quick Repo Access Test

After granting repo access, test it.

For a human user:

1. Open **Repos**.
2. Confirm the repository is visible.
3. Try to clone the repository.

For a pipeline:

1. Create or run a simple pipeline.
2. Check whether the `Checkout` step succeeds.
3. If checkout fails with an authorization error, go back to repository security and recheck the build identity permissions.

> Screenshot placeholder:
> Capture a successful pipeline run showing the `Checkout` step completed.
> The image should show a green or successful status for source checkout.

## 7. Set Up Pipeline Agents

Pipeline agents are the machines that actually run your pipeline jobs.

You have two main choices:

- Microsoft-hosted agents
- Self-hosted agents

For this workshop, Microsoft-hosted agents are the recommended default because they are much easier for beginners.

## 7.1 Recommended Option: Microsoft-Hosted Agents

Microsoft-hosted agents are managed by Microsoft. You do not install or maintain the build machine yourself.

### What You Need To Do

There is no software to install on your own machine for hosted agents. Instead, you must confirm that your Azure DevOps organization is allowed to use them.

> Screenshot placeholder:
> Capture **Organization settings** with the **Parallel jobs** menu visible.
> The image should help the reader find the hosted agent capacity page.

Follow these steps:

1. Open Azure DevOps.
2. In the lower-left corner, select **Organization settings**.
3. Look for **Parallel jobs**.
4. Open the parallel jobs page.
5. Check whether your organization has at least one Microsoft-hosted parallel job.

If you cannot see **Organization settings** or **Parallel jobs**, ask an Azure DevOps organization administrator to check this for you. Project-level users often cannot see organization-level billing or capacity settings.

What this means:

- If you have at least one hosted parallel job, a hosted pipeline can run.
- If you have zero hosted parallel jobs, your pipeline may stay queued and never start.

Minimum recommendation:

- 1 hosted parallel job for one team
- 2 or more if multiple teams run pipelines at the same time

> Screenshot placeholder:
> Capture the **Parallel jobs** page.
> The image should show whether Microsoft-hosted jobs are available.

### How To Tell A Pipeline To Use A Hosted Agent

In YAML pipelines, hosted agents are selected by setting a Microsoft image, for example `ubuntu-latest`.

Example:

```yaml
pool:
	vmImage: ubuntu-latest
```

> Screenshot placeholder:
> Capture the pipeline editor or YAML editor where the hosted image is configured.
> The image should show the `vmImage` line.

For beginners, this is the easiest path.

### Hosted Agent Checklist

Before moving on, confirm all of the following:

- The organization has hosted parallel job capacity
- Your pipeline YAML uses a Microsoft-hosted image
- The pipeline is not pointing to a missing self-hosted pool such as `Default`

## 7.2 Optional Option: Self-Hosted Agents

Choose a self-hosted agent only if you actually need it.

Examples of when you may need a self-hosted agent:

- Your build must access internal network resources
- Your company does not allow Microsoft-hosted agents
- Your build needs special internal tools

If none of those apply, use Microsoft-hosted agents instead.

### What You Need Before You Begin

Prepare one machine that will act as the agent.

That machine should have:

- Windows or Linux
- Stable internet access
- The ability to stay powered on while pipelines run
- Git installed
- Node.js installed if your build uses Node.js
- Azure CLI installed if your pipeline uses Azure CLI tasks

For a Windows setup, a dedicated VM is usually better than using a developer laptop.

### Create Or Confirm The Agent Pool

> Screenshot placeholder:
> Capture **Organization settings** and the **Agent pools** page.
> The image should show where to create or select a self-hosted pool.

Follow these steps:

1. Open Azure DevOps.
2. Select **Organization settings**.
3. Select **Agent pools**.
4. Check whether a pool already exists that you are allowed to use.
5. If not, create a new pool.
6. Give the pool a simple name such as `Workshop-SelfHosted`.

If you do not have permission to create agent pools, ask an Azure DevOps administrator to create the pool for you.

> Screenshot placeholder:
> Capture the agent pool list after the pool is created.
> The image should show the pool name such as `Workshop-SelfHosted`.

### Download The Agent Software

> Screenshot placeholder:
> Capture the **New agent** dialog.
> The image should show the operating system choices and download area.

Follow these steps:

1. Open **Organization settings**.
2. Open **Agent pools**.
3. Select the pool you want to use.
4. Select **New agent**.
5. Choose the correct operating system for the machine.
6. Download the agent package.

### Prepare The Folder On The Agent Machine

> Screenshot placeholder:
> Capture the extracted agent folder on the machine.
> The image should show the agent files after extraction.

On the machine that will run the agent:

1. Create a folder such as `C:\agents\workshop-agent`.
2. Extract the downloaded agent package into that folder.
3. Open Command Prompt or PowerShell as an administrator.
4. Go to the agent folder.

### Register The Agent

Inside the extracted folder, run the configuration script.

On Windows:

```powershell
.\config.cmd
```

> Screenshot placeholder:
> Capture the terminal window before running `config.cmd`.
> The image should show the command prompt located inside the agent folder.

During configuration, you will be asked several questions. Use these answers:

1. **Server URL**: Enter your Azure DevOps organization URL, for example `https://dev.azure.com/<organization-name>`.
2. **Authentication type**: Choose the option your organization allows. In many cases this is `PAT`.
3. **PAT**: Paste a Personal Access Token if the setup asks for one.
4. **Agent pool**: Enter the pool name you created or selected earlier.
5. **Agent name**: Use a simple name such as `workshop-agent-01`.
6. **Work folder**: Accept `_work` unless you have a reason to change it.
7. **Run as service**: Choose `Y` so the agent runs as a Windows service.
8. **Service account**: Use the default if you are not instructed otherwise.

> Screenshot placeholder:
> Capture the configuration wizard output during setup.
> The image should show the server URL, pool name, and agent name prompts.

If you do not have a PAT and Azure DevOps asks for one, create it from your profile security settings with the minimum rights needed to register the agent, or ask an administrator to provide the right setup path.

If you create a PAT only for agent registration, treat it as temporary setup credentials. Store it safely, do not share it in chat or email, and delete or rotate it after the agent is configured if your organization policy requires that.

### Start The Agent Service

If the agent registration succeeds:

1. The setup script may ask whether it should start the service.
2. Choose `Y` if prompted.
3. If needed, run the service start command shown by the setup tool.

### Confirm The Agent Is Online

Go back to Azure DevOps and check:

1. Open **Organization settings**.
2. Open **Agent pools**.
3. Select your pool.
4. Confirm the new agent appears.
5. Confirm the status shows as online.

> Screenshot placeholder:
> Capture the agent pool details page after registration.
> The image should show the agent listed as online.

If the agent appears offline:

1. Check whether the service is running on the machine.
2. Check whether the machine has internet access.
3. Check whether a firewall or proxy is blocking Azure DevOps.
4. Re-run the configuration if necessary.

### How To Use A Self-Hosted Pool In YAML

If you want a pipeline to use a self-hosted pool, the YAML will usually look like this:

```yaml
pool:
	name: Workshop-SelfHosted
```

> Screenshot placeholder:
> Capture the YAML editor where the self-hosted pool name is configured.
> The image should show the `pool.name` setting.

Only use this if the pool really exists and the agent is online.

## 8. Create The Azure Service Connection

The service connection allows Azure DevOps pipelines to sign in to Azure and use Azure resources.

For this workshop, the normal choice is an **Azure Resource Manager** service connection.

This is required for pipelines that need to talk to Azure resources such as:

- Azure Container Registry
- Azure Kubernetes Service
- Resource groups in your Azure subscription

> Screenshot placeholder:
> Capture **Project settings** with **Service connections** visible under the **Pipelines** section.
> The image should help the reader find the correct page.

## 8.1 Decide The Scope Before You Create The Service Connection

Before you click through the wizard, decide how wide the access should be.

You usually choose one of these scopes:

- `Resource group` scope
- `Subscription` scope

Recommended beginner choice:

- Use `Resource group` scope if all workshop resources are inside one resource group

Why this is better for beginners:

- Easier to understand
- Smaller blast radius
- Safer than granting access to the entire subscription

Use `Subscription` scope only if you really need the pipeline to work across multiple resource groups.

> Screenshot placeholder:
> Capture a note, diagram, or wizard screen that shows the scope choice between `Resource group` and `Subscription`.
> The image should help the reader understand which option to choose.

## 8.2 Recommended Method: Create An Azure Resource Manager Service Connection With The Wizard

This is the easiest path for a beginner.

Follow these steps:

1. Open your Azure DevOps project.
2. In the lower-left corner, select **Project settings**.
3. Under the **Pipelines** section, select **Service connections**.
4. Select **Create service connection** or **New service connection**.
5. In the list of connection types, select **Azure Resource Manager**.
6. Select **Next**.

> Screenshot placeholder:
> Capture the **Create service connection** screen.
> The image should show **Azure Resource Manager** selected.

Azure DevOps may show more than one authentication method. The available options depend on your tenant and policy.

Pick the simplest approved option that your organization allows, usually one of these:

- Automatic app registration or automatic setup
- Workload identity federation with automatic setup
- Service principal with automatic setup

> Screenshot placeholder:
> Capture the authentication method selection page.
> The image should show the available Azure authentication options.

If you are not sure which one to choose, ask your Azure administrator which option is approved in your environment.

### Sign In And Select The Azure Target

After choosing the connection method:

1. Select **Sign in** if Azure DevOps asks you to sign in to Azure.
2. Complete the sign-in process.
3. Select the correct Azure subscription.
4. Select the scope level.
5. If you chose `Resource group` scope, select the workshop resource group.
6. Enter a service connection name.

Recommended name for this workshop:

- `azureSubscription`

> Screenshot placeholder:
> Capture the form where subscription, scope, resource group, and connection name are selected.
> The image should show the chosen Azure subscription and service connection name.

That name matches the convention used by the workshop material.

If your YAML pipeline already refers to a different service connection name, use that exact name instead. The name in Azure DevOps and the name referenced in the pipeline must match.

### Recommended Settings During Creation

When the wizard shows extra options, use these guidelines:

1. Turn on **Grant access permission to all pipelines** if this is a shared workshop environment and you want to avoid per-pipeline authorization prompts.
2. Leave the description blank unless your team wants one.
3. Review the chosen subscription and scope carefully before saving.
4. Select **Save**.

> Screenshot placeholder:
> Capture the final review page before saving the service connection.
> The image should show the grant-access setting and target scope.

If the wizard fails:

1. Confirm you have permission in Azure to create or use the underlying identity.
2. Confirm you have permission in Azure DevOps to create service connections.
3. Ask an Azure administrator or Azure DevOps administrator to complete the creation if needed.

## 8.3 If Your Organization Requires Manual Help

In many companies, a regular user cannot create a service connection alone.

You may need one of these people:

- An Azure administrator
- An Azure DevOps project administrator
- A security administrator

Ask them for:

1. An Azure Resource Manager service connection for the workshop project
2. Scope set to the workshop resource group if possible
3. A clear service connection name such as `azureSubscription`
4. Authorization for the workshop pipelines to use it

> Screenshot placeholder:
> Capture the service connection list after an administrator creates the connection.
> The image should show the final connection name in the project.

## 8.4 Test The Service Connection

After creation, always test it.

Follow these steps:

1. Open **Project settings**.
2. Open **Service connections**.
3. Select the new service connection.
4. Open the details page.
5. Look for a **Verify**, **Check**, or similar validation option if it exists.
6. If there is no explicit verify button, use the service connection in a test pipeline.

What success looks like:

- Azure DevOps can see the subscription or resource group
- The pipeline can log in to Azure without credential errors

> Screenshot placeholder:
> Capture the service connection details page or a successful validation result.
> The image should show that the connection is working.

## 8.5 Authorize The Service Connection For Pipelines

Sometimes a service connection exists but a pipeline still cannot use it.

This usually happens because the pipeline has not been authorized yet.

Follow these checks:

1. Open the service connection.
2. Confirm **Grant access permission to all pipelines** is enabled if that is acceptable in your environment.
3. If it is not enabled, run the pipeline once.
4. Azure DevOps may show an authorization prompt.
5. Approve the pipeline to use the connection.

If the pipeline fails with an authorization error, go back and recheck this step.

> Screenshot placeholder:
> Capture the authorization prompt or the service connection settings showing pipeline access is enabled.
> The image should show how the user confirms pipeline authorization.

## 8.6 Minimum Practical Permissions For The Service Connection

The service connection needs enough Azure permission to do its job.

Examples:

- For ACR build scenarios, it must be able to access the registry resource and run the required build operation.
- For AKS deployment scenarios, it must be able to access the cluster and obtain credentials.

Recommended beginner approach:

- Scope the connection to the workshop resource group
- Use a built-in role that is broad enough for the workshop to work
- Tighten permissions later after the workshop if needed

For a workshop or lab environment, teams often start with broader access at the resource group level so the first pipeline run succeeds. After the workshop, reduce permissions to the minimum needed before using the same setup in a long-lived environment.

Avoid using a personal user account as the long-term pipeline identity.

## 8.7 What Azure DevOps Needs For ACR Connectivity

This section explains the Azure DevOps side of connecting to Azure Container Registry.

For this repository, the ACR pipelines use `AzureCLI@2` and run `az acr build`. That means the pipeline does not need Docker installed on the agent, but it does need the right Azure DevOps setup and the right Azure access.

### What Must Exist Before The Pipeline Can Reach ACR

Before Azure DevOps can work with ACR, all of the following should be true:

1. An Azure DevOps organization exists.
2. An Azure DevOps project exists.
3. The repository containing the pipeline YAML exists.
4. The pipeline can read the repository.
5. A pipeline agent is available.
6. An Azure Resource Manager service connection exists.
7. The service connection points to the correct subscription or resource group.
8. The ACR resource already exists in Azure.
9. The service connection identity has permission to use that ACR.

If any one of these is missing, the ACR pipeline usually fails before the image is pushed.

### Step 1: Confirm The ACR Resource Already Exists

From the Azure side, confirm that the registry already exists.

The easiest check is:

1. Open the Azure portal.
2. Search for **Container registries**.
3. Open the target registry.
4. Confirm the registry name is correct.
5. Confirm the subscription is correct.
6. Confirm the resource group is correct.

Write down these values because the pipeline will need them:

- ACR name, for example `myregistry`
- ACR login server, for example `myregistry.azurecr.io`
- Subscription name
- Resource group name

> Screenshot placeholder:
> Capture the Azure portal ACR overview page.
> The image should show the registry name, resource group, and subscription.

### Step 2: Make Sure Azure DevOps Can Use The Correct Azure Scope

The Azure DevOps service connection must point to the Azure location where the ACR lives.

Recommended setup:

1. If the workshop ACR is in one resource group, create the service connection at `Resource group` scope.
2. Select the same resource group that contains the ACR.
3. Use a clear service connection name such as `azureSubscription`.

If your ACR is in a different resource group than the selected service connection scope, the pipeline may authenticate successfully but still fail to find or use the registry.

### Step 3: Give The Service Connection Identity Permission On The ACR

This is the most important Azure-side access step.

The identity behind the service connection must have permission that is strong enough to run the ACR workflow.

For this workshop, the practical beginner choice is one of these:

1. `Contributor` on the resource group that contains the ACR.
2. `Contributor` on the ACR resource itself.

Why this is the easiest workshop option:

- It is simple to explain.
- It usually works for `az acr build` without role troubleshooting.
- It avoids losing class time on RBAC edge cases.

For a tighter post-workshop setup, your Azure team can reduce the permissions later.

If an Azure administrator is granting access, ask them to:

1. Find the service principal or workload identity behind the Azure DevOps service connection.
2. Open the ACR resource or its resource group in Azure.
3. Open **Access control (IAM)**.
4. Select **Add role assignment**.
5. Choose the required role.
6. Assign it to the service connection identity.
7. Save the role assignment.

> Screenshot placeholder:
> Capture the Azure portal role assignment page for the ACR resource or resource group.
> The image should show the chosen role and the selected service connection identity.

### Step 4: Authorize The Service Connection Inside Azure DevOps

Even if Azure access is correct, the pipeline still fails if Azure DevOps does not allow the pipeline to use the service connection.

Follow these checks:

1. Open the Azure DevOps project.
2. Go to **Project settings**.
3. Open **Service connections**.
4. Select the Azure Resource Manager service connection.
5. Confirm it points to the correct subscription and scope.
6. Confirm **Grant access permission to all pipelines** is enabled, or explicitly authorize the pipeline when prompted.

### Step 5: Match The Pipeline Variables To The Real ACR Values

This repository expects the pipeline YAML to contain the ACR values.

In [templates/sample-app/azure-pipelines-acr.yml](c:/Users/akashdwivedi/OneDrive%20-%20Microsoft/Desktop/GHCP%20repros/Fortis-Workshop/workshop-demo/templates/sample-app/azure-pipelines-acr.yml) and [templates/sample-app/azure-pipelines-acr-nginx.yml](c:/Users/akashdwivedi/OneDrive%20-%20Microsoft/Desktop/GHCP%20repros/Fortis-Workshop/workshop-demo/templates/sample-app/azure-pipelines-acr-nginx.yml), confirm these values are correct:

1. `azureSubscription` must match the service connection name in Azure DevOps.
2. `acrName` must match the Azure Container Registry resource name.
3. `acrLoginServer` must match the login server shown in the Azure portal.

If any of these values are wrong, the pipeline may log in to Azure successfully but still fail when it tries to build or push the image.

### Step 6: Confirm The Agent Strategy Matches The Registry Network Setup

This is where many teams get stuck.

If your ACR allows standard public Azure access and the service connection has permission, Microsoft-hosted agents are usually fine for this workshop.

If your ACR uses restricted networking, the plan may need to change.

Examples:

- If the registry only allows private endpoint access, a Microsoft-hosted agent usually cannot reach it directly.
- If the registry is behind strict firewall rules, the pipeline may fail even though the service connection is valid.

In that case, use one of these approaches:

1. Use a self-hosted agent inside the allowed network.
2. Ask the Azure team whether the current ACR firewall and network rules permit the intended pipeline flow.

### Step 7: Run A Small ACR Validation Pipeline

Before the workshop, run the ACR pipeline once.

Use this checklist:

1. Queue the ACR pipeline.
2. Confirm the pipeline starts on an available agent.
3. Confirm the `AzureCLI@2` step starts.
4. Confirm `az account show` succeeds.
5. Confirm `az acr build` succeeds.
6. Open the ACR in Azure and confirm the image appears in the repository list.

If the image appears in ACR, Azure DevOps connectivity to ACR is working.

> Screenshot placeholder:
> Capture the pipeline log showing the `Build and push image to ACR` step succeeded.
> The image should show the Azure CLI step completed successfully.

### Common ACR Connectivity Failures From The Azure DevOps Side

If the pipeline cannot connect to ACR, the cause is usually one of these:

- The service connection name in YAML does not match the real Azure DevOps service connection name.
- The service connection points to the wrong subscription.
- The service connection is scoped to the wrong resource group.
- The service connection is not authorized for the pipeline.
- The service connection identity does not have enough Azure RBAC permission on the ACR or resource group.
- The `acrName` value is wrong.
- The registry networking rules do not allow the chosen agent path.

For this repository, start troubleshooting in this order:

1. Check the service connection name.
2. Check the ACR name and login server values.
3. Check the Azure RBAC role assignment.
4. Check whether the registry network rules require a self-hosted agent.

## 9. Run A Simple Validation

Before the workshop starts, perform one simple validation run.

Minimum validation checklist:

1. Confirm the repository exists.
2. Confirm the user can open the repository.
3. Confirm the pipeline identity has repository read access.
4. Confirm at least one pipeline agent option is ready.
5. Confirm the service connection exists.
6. Confirm the service connection is authorized for the pipeline.
7. Run one simple pipeline.

If the pipeline starts, checks out the repo, and reaches the build steps, your Azure DevOps base setup is in a good state.

> Screenshot placeholder:
> Capture one successful validation pipeline run.
> The image should show a completed run with checkout and at least one build step succeeding.

## 10. Common Problems And What They Usually Mean

### The Pipeline Stays Queued Forever

Usually means:

- No Microsoft-hosted parallel job is available
- The pipeline points to a self-hosted agent pool that has no online agent

### The Pipeline Cannot Read The Repository

Usually means:

- The build identity does not have `Read` permission on the repo
- The pipeline is trying to access a different repo than expected

### The Pipeline Cannot Use Azure

Usually means:

- The service connection was not created
- The service connection is not authorized for the pipeline
- The service connection points to the wrong subscription or resource group
- The Azure-side identity does not have enough permission

### The Self-Hosted Agent Shows Offline

Usually means:

- The service is stopped
- The machine is off
- Network or proxy access is blocked
- The agent was registered incorrectly

## 11. Recommended Beginner Baseline

If you want the simplest possible workshop setup, use this baseline:

- One Azure DevOps project
- One repository
- Microsoft-hosted agents
- One Azure Resource Manager service connection
- Resource group scoped permissions where possible
- Repository `Read` permission for the build identity

This is usually enough to get started without unnecessary complexity.

## 12. What To Read Next

After the Azure DevOps platform setup is complete, continue with the broader workshop prerequisites document:

- [workshop/azure-devops-prerequisites.md](../workshop/azure-devops-prerequisites.md)