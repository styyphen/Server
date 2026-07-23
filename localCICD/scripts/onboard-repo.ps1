[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern("^[a-zA-Z0-9][a-zA-Z0-9._-]*$")]
    [string] $ProjectName,

    [Parameter(Mandatory)]
    [ValidateSet("dotnet-api", "react", "node-api", "worker-service")]
    [string] $Template,

    [string] $DestinationRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")) "generated-repos"),

    [switch] $Force,

    [switch] $DryRun
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$templateMap = @{
    "dotnet-api"      = "dotnet-api-template"
    "react"          = "react-template"
    "node-api"       = "node-api-template"
    "worker-service" = "worker-service-template"
}

$templatePath = Join-Path $repoRoot "repo-templates\$($templateMap[$Template])"
if (-not (Test-Path $templatePath)) {
    throw "Template '$Template' was not found at '$templatePath'."
}

$destinationRootPath = [System.IO.Path]::GetFullPath($DestinationRoot)
$projectPath = Join-Path $destinationRootPath $ProjectName

if ((Test-Path $projectPath) -and -not $Force) {
    throw "Destination '$projectPath' already exists. Re-run with -Force to replace files."
}

Write-Host "Template:    $Template"
Write-Host "Source:      $templatePath"
Write-Host "Destination: $projectPath"

if ($DryRun) {
    Write-Host "Dry run requested. No files were copied."
    return
}

New-Item -ItemType Directory -Force -Path $destinationRootPath | Out-Null
New-Item -ItemType Directory -Force -Path $projectPath | Out-Null

$textExtensions = @(
    ".cs", ".csproj", ".json", ".js", ".jsx", ".ts", ".tsx", ".md", ".ps1",
    ".yml", ".yaml", ".toml", ".config", ".props", ".html", ".css", ".gitignore"
)

Get-ChildItem -Path $templatePath -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring($templatePath.Length).TrimStart("\", "/")
    $relativePath = $relativePath.Replace("__PROJECT_NAME__", $ProjectName)
    $relativePath = $relativePath.Replace("__PROJECT_SLUG__", $ProjectName.ToLowerInvariant())
    $targetPath = Join-Path $projectPath $relativePath
    $targetDirectory = Split-Path -Parent $targetPath
    New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null

    if ($textExtensions -contains $_.Extension -or $_.Name -in @("Dockerfile", "README.md", "CHANGELOG.md")) {
        $content = Get-Content -Raw -LiteralPath $_.FullName
        $content = $content.Replace("__PROJECT_NAME__", $ProjectName)
        $content = $content.Replace("__PROJECT_SLUG__", $ProjectName.ToLowerInvariant())
        Set-Content -LiteralPath $targetPath -Value $content
    }
    else {
        Copy-Item -LiteralPath $_.FullName -Destination $targetPath -Force
    }
}

Write-Host "Created '$ProjectName' from '$Template'."
Write-Host "Next:"
Write-Host "  cd $projectPath"
Write-Host "  ./scripts/run-local.ps1"
Write-Host "  ./scripts/run-ci-local.ps1"
