[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OrganizationUrl,

    [Parameter(Mandatory = $false)]
    [string]$ProjectName = "ado-workshop",

    [Parameter(Mandatory = $false)]
    [string]$RepositoryName = "workshop-sample-app",

    [Parameter(Mandatory = $false)]
    [string]$LocalPath = ".\out\workshop-sample-app",

    [Parameter(Mandatory = $false)]
    [switch]$CreatePipelines,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Title)

    Write-Host ""
    Write-Host ("=" * 72)
    Write-Host $Title
    Write-Host ("=" * 72)
}

function Read-TextValue {
    param(
        [string]$Prompt,
        [string]$DefaultValue
    )

    $suffix = ""
    if (-not [string]::IsNullOrWhiteSpace($DefaultValue)) {
        $suffix = " [$DefaultValue]"
    }

    $value = Read-Host "$Prompt$suffix"
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $DefaultValue
    }

    return $value.Trim()
}

function Read-YesNoValue {
    param(
        [string]$Prompt,
        [bool]$DefaultValue
    )

    $defaultText = if ($DefaultValue) { "Y" } else { "N" }

    while ($true) {
        $answer = Read-Host "$Prompt [Y/N] (default: $defaultText)"
        if ([string]::IsNullOrWhiteSpace($answer)) {
            return $DefaultValue
        }

        switch ($answer.Trim().ToLowerInvariant()) {
            "y" { return $true }
            "yes" { return $true }
            "n" { return $false }
            "no" { return $false }
            default { Write-Host "Please enter Y or N." }
        }
    }
}

function Show-Plan {
    Write-Section "Azure DevOps Workshop Admin Setup"
    Write-Host "This guided setup will:"
    Write-Host "1. Check Azure CLI and Git"
    Write-Host "2. Make sure the Azure DevOps CLI extension is installed"
    Write-Host "3. Create the Azure DevOps project if needed"
    Write-Host "4. Create the repository if needed"
    Write-Host "5. Copy the sample app locally"
    Write-Host "6. Push the sample app to Azure DevOps"
    Write-Host "7. Optionally create the three workshop pipelines"
    Write-Host ""
    Write-Host "You must already have an Azure DevOps organization."
}

function Initialize-InteractiveInputs {
    Show-Plan

    if ([string]::IsNullOrWhiteSpace($script:OrganizationUrl)) {
        $script:OrganizationUrl = Read-TextValue -Prompt "Azure DevOps organization URL" -DefaultValue "https://dev.azure.com/contoso"
    }

    $script:ProjectName = Read-TextValue -Prompt "Project name" -DefaultValue $script:ProjectName
    $script:RepositoryName = Read-TextValue -Prompt "Repository name" -DefaultValue $script:RepositoryName
    $script:LocalPath = Read-TextValue -Prompt "Local folder for the sample app" -DefaultValue $script:LocalPath

    if (-not $PSBoundParameters.ContainsKey("CreatePipelines")) {
        $script:CreatePipelines = Read-YesNoValue -Prompt "Create the three starter pipelines now" -DefaultValue $true
    }

    if ((Test-Path $script:LocalPath) -and -not $PSBoundParameters.ContainsKey("Force")) {
        $script:Force = Read-YesNoValue -Prompt "The local folder already exists. Replace it if needed" -DefaultValue $false
    }

    Write-Section "Setup Summary"
    Write-Host "Organization URL : $script:OrganizationUrl"
    Write-Host "Project name     : $script:ProjectName"
    Write-Host "Repository name  : $script:RepositoryName"
    Write-Host "Local path       : $script:LocalPath"
    Write-Host "Create pipelines : $script:CreatePipelines"
    Write-Host "Force overwrite  : $script:Force"
    Write-Host ""

    $shouldContinue = Read-YesNoValue -Prompt "Continue with this setup" -DefaultValue $true
    if (-not $shouldContinue) {
        throw "Setup cancelled by user."
    }
}

function Assert-CommandExists {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found. Install it before running this script."
    }
}

function Invoke-NativeCommand {
    param([string[]]$Arguments)

    $output = & $Arguments[0] $Arguments[1..($Arguments.Length - 1)] 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $message = ($output | ForEach-Object { "$_" }) -join [Environment]::NewLine
        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = "Command failed with exit code $exitCode."
        }

        throw $message
    }

    return $output
}

function Invoke-AzJson {
    param([string[]]$Arguments)

    $output = Invoke-NativeCommand -Arguments (@("az") + $Arguments + @("--output", "json"))
    $output = ($output | ForEach-Object { "$_" }) -join [Environment]::NewLine

    if ([string]::IsNullOrWhiteSpace($output)) {
        return $null
    }

    return $output | ConvertFrom-Json
}

function Invoke-AzNoOutput {
    param([string[]]$Arguments)

    Invoke-NativeCommand -Arguments (@("az") + $Arguments) | Out-Null
}

function Invoke-GitNoOutput {
    param([string[]]$Arguments)

    Invoke-NativeCommand -Arguments (@("git") + $Arguments) | Out-Null
}

function Install-AzureDevOpsExtensionIfNeeded {
    $extension = az extension show --name azure-devops --output json 2>$null
    if (($LASTEXITCODE -ne 0) -or (-not $extension)) {
        Write-Host "Installing the Azure DevOps Azure CLI extension..."
        Invoke-AzNoOutput -Arguments @("extension", "add", "--name", "azure-devops")
    }
}

function Assert-AzureSignIn {
    try {
        Invoke-AzNoOutput -Arguments @("account", "show", "--output", "none")
    }
    catch {
        throw "Azure CLI is not signed in. Run 'az login' first, then start this setup again."
    }
}

function Assert-AzureDevOpsAccess {
    try {
        Invoke-AzNoOutput -Arguments @("devops", "project", "list", "--org", $OrganizationUrl, "--top", "1")
    }
    catch {
        throw "Azure DevOps access check failed. Sign in for Azure DevOps CLI access and verify you can access '$OrganizationUrl'. Original error: $($_.Exception.Message)"
    }
}

function New-WorkshopProjectIfNeeded {
    $projects = Invoke-AzJson -Arguments @("devops", "project", "list", "--org", $OrganizationUrl)
    $existingProject = $projects.value | Where-Object { $_.name -eq $ProjectName } | Select-Object -First 1

    if ($existingProject) {
        Write-Host "Project '$ProjectName' already exists."
        return
    }

    Write-Host "Creating project '$ProjectName'..."
    $arguments = @(
        "devops", "project", "create",
        "--name", $ProjectName,
        "--description", "Azure DevOps workshop project",
        "--org", $OrganizationUrl,
        "--source-control", "git",
        "--visibility", "private"
    )

    Invoke-AzNoOutput -Arguments $arguments
}

function New-WorkshopRepositoryIfNeeded {
    $repositories = Invoke-AzJson -Arguments @(
        "repos", "list",
        "--org", $OrganizationUrl,
        "--project", $ProjectName
    )
    $existingRepo = $repositories | Where-Object { $_.name -eq $RepositoryName } | Select-Object -First 1

    if ($existingRepo) {
        Write-Host "Repository '$RepositoryName' already exists."
        return
    }

    Write-Host "Creating repository '$RepositoryName'..."
    $arguments = @(
        "repos", "create",
        "--name", $RepositoryName,
        "--org", $OrganizationUrl,
        "--project", $ProjectName
    )

    Invoke-AzNoOutput -Arguments $arguments
}

function Copy-TemplateRepo {
    $templatePath = Join-Path $PSScriptRoot "..\templates\sample-app"

    if (-not (Test-Path $templatePath)) {
        throw "Sample app template was not found at '$templatePath'."
    }

    $resolvedLocalPath = Resolve-Path -Path $LocalPath -ErrorAction SilentlyContinue

    if ($resolvedLocalPath -and (Get-ChildItem -Path $resolvedLocalPath -Force | Measure-Object).Count -gt 0 -and -not $Force) {
        throw "Local path '$LocalPath' is not empty. Use -Force or choose another location."
    }

    if ((Test-Path $LocalPath) -and $Force) {
        Remove-Item -Path $LocalPath -Recurse -Force
    }

    New-Item -ItemType Directory -Path $LocalPath -Force | Out-Null
    Copy-Item -Path (Join-Path $templatePath "*") -Destination $LocalPath -Recurse -Force
}

function Push-RepositoryContent {
    $repoRemoteUrl = "{0}/{1}/_git/{2}" -f $OrganizationUrl.TrimEnd('/'), $ProjectName, $RepositoryName

    Push-Location $LocalPath
    try {
        if (-not (Test-Path ".git")) {
            Invoke-GitNoOutput -Arguments @("init")
        }

        $currentUserName = git config user.name 2>$null
        $currentUserEmail = git config user.email 2>$null
        if (-not $currentUserName) {
            Invoke-GitNoOutput -Arguments @("config", "user.name", "Workshop Bootstrap")
        }
        if (-not $currentUserEmail) {
            Invoke-GitNoOutput -Arguments @("config", "user.email", "workshop-bootstrap@example.invalid")
        }

        Invoke-GitNoOutput -Arguments @("add", ".")

        $hasChanges = git status --porcelain
        if ($hasChanges) {
            Invoke-GitNoOutput -Arguments @("commit", "-m", "Initial workshop sample app")
        }

        Invoke-GitNoOutput -Arguments @("branch", "-M", "main")

        $remoteExists = git remote | Select-String -SimpleMatch "origin"
        if (-not $remoteExists) {
            Invoke-GitNoOutput -Arguments @("remote", "add", "origin", $repoRemoteUrl)
        }
        else {
            Invoke-GitNoOutput -Arguments @("remote", "set-url", "origin", $repoRemoteUrl)
        }

        Invoke-GitNoOutput -Arguments @("push", "-u", "origin", "main", "--force")
    }
    finally {
        Pop-Location
    }
}

function New-WorkshopPipelineIfNeeded {
    param(
        [string]$PipelineName,
        [string]$YamlPath
    )

    $pipelines = Invoke-AzJson -Arguments @(
        "pipelines", "list",
        "--org", $OrganizationUrl,
        "--project", $ProjectName
    )
    $existingPipeline = $pipelines | Where-Object { $_.name -eq $PipelineName } | Select-Object -First 1

    if ($existingPipeline) {
        Write-Host "Pipeline '$PipelineName' already exists."
        return
    }

    Write-Host "Creating pipeline '$PipelineName'..."
    $arguments = @(
        "pipelines", "create",
        "--name", $PipelineName,
        "--description", $PipelineName,
        "--org", $OrganizationUrl,
        "--project", $ProjectName,
        "--repository", $RepositoryName,
        "--repository-type", "tfsgit",
        "--branch", "main",
        "--yml-path", $YamlPath,
        "--skip-run", "true"
    )

    Invoke-AzNoOutput -Arguments $arguments
}

Assert-CommandExists -Name "az"
Assert-CommandExists -Name "git"

if (-not $NonInteractive) {
    Initialize-InteractiveInputs
}
elseif ([string]::IsNullOrWhiteSpace($OrganizationUrl)) {
    throw "OrganizationUrl is required when using -NonInteractive."
}

Write-Section "Checking Tools"
Install-AzureDevOpsExtensionIfNeeded

Write-Section "Checking Azure Sign-In"
Assert-AzureSignIn

Write-Section "Configuring Azure DevOps Defaults"
Invoke-AzNoOutput -Arguments @("devops", "configure", "--defaults", "organization=$OrganizationUrl", "project=$ProjectName")

Write-Section "Checking Azure DevOps Access"
Assert-AzureDevOpsAccess

Write-Section "Creating Or Reusing Azure DevOps Assets"
New-WorkshopProjectIfNeeded
New-WorkshopRepositoryIfNeeded

Write-Section "Preparing Sample Repository"
Copy-TemplateRepo
Push-RepositoryContent

if ($CreatePipelines) {
    Write-Section "Creating Starter Pipelines"
    New-WorkshopPipelineIfNeeded -PipelineName "Workshop Basic CI" -YamlPath "azure-pipelines-basic.yml"
    New-WorkshopPipelineIfNeeded -PipelineName "Workshop ACR Build" -YamlPath "azure-pipelines-acr.yml"
    New-WorkshopPipelineIfNeeded -PipelineName "Workshop ACR Nginx Build" -YamlPath "azure-pipelines-acr-nginx.yml"
    New-WorkshopPipelineIfNeeded -PipelineName "Workshop AKS Deploy" -YamlPath "azure-pipelines-aks.yml"
}

Write-Section "Setup Complete"
Write-Host "Workshop bootstrap completed successfully."
Write-Host ""
Write-Host "Next steps:"
Write-Host "- Open Azure DevOps and confirm the project and repo are visible"
Write-Host "- If you created pipelines, open each one and confirm variables and service connections"
Write-Host "- Share the repo and pipeline names with your workshop audience"