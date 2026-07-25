[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Write-ValidationEvent {
    param(
        [Parameter(Mandatory)][string] $Level,
        [Parameter(Mandatory)][string] $Event,
        [Parameter(Mandatory)][string] $Message,
        [hashtable] $Data = @{}
    )

    [ordered]@{
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
        level = $Level
        event = $Event
        message = $Message
        data = $Data
    } | ConvertTo-Json -Compress
}

$kubectl = Get-Command kubectl -ErrorAction Stop
$scriptRoot = $PSScriptRoot
$onboardingScript = Join-Path $scriptRoot "onboard-repo.ps1"
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)
$validationRoot = Join-Path $repositoryRoot ".validation/template-validation-$([guid]::NewGuid().ToString('N'))"
$templates = @("dotnet-api", "node-api", "react", "worker-service")

try {
    foreach ($template in $templates) {
        $projectName = "validate-$template"
        Write-ValidationEvent -Level info -Event template_validation_started `
            -Message "Validating generated repository." `
            -Data @{ template = $template; project = $projectName }

        & $onboardingScript -ProjectName $projectName -Template $template -DestinationRoot $validationRoot
        $projectPath = Join-Path $validationRoot $projectName
        $basePath = Join-Path $projectPath "k8s/base"
        $overlayPath = Join-Path $projectPath "k8s/overlays/local"

        $base = (& $kubectl.Source kustomize $basePath) -join "`n"
        if ($LASTEXITCODE -ne 0) {
            throw "Base Kustomize rendering failed for '$template'."
        }

        $overlay = (& $kubectl.Source kustomize $overlayPath) -join "`n"
        if ($LASTEXITCODE -ne 0) {
            throw "Local overlay Kustomize rendering failed for '$template'."
        }

        $requiredPatterns = @(
            "kind: Deployment",
            "kind: NetworkPolicy",
            "runAsNonRoot: true",
            "allowPrivilegeEscalation: false",
            "readOnlyRootFilesystem: true",
            "seccompProfile:",
            "resources:",
            "startupProbe:",
            "readinessProbe:",
            "livenessProbe:",
            "OTEL_EXPORTER_OTLP_ENDPOINT"
        )
        foreach ($pattern in $requiredPatterns) {
            if ($base -notmatch [regex]::Escape($pattern)) {
                throw "Generated '$template' base is missing required contract '$pattern'."
            }
        }

        if ($overlay -match "__PROJECT_(NAME|SLUG)__") {
            throw "Generated '$template' overlay contains unresolved template tokens."
        }
        if ($overlay -notmatch "pod-security.kubernetes.io/enforce: restricted") {
            throw "Generated '$template' overlay does not enforce Restricted Pod Security."
        }
        if ($overlay -notmatch "namespace: $([regex]::Escape($projectName))") {
            throw "Generated '$template' resources are not assigned to the project namespace."
        }
        if ($template -eq "worker-service" -and $base -match "(?m)^kind: Service$") {
            throw "Worker template must not expose a Kubernetes Service."
        }

        Write-ValidationEvent -Level info -Event template_validation_passed `
            -Message "Repository template contract passed." `
            -Data @{ template = $template; project = $projectName }
    }

    Write-ValidationEvent -Level info -Event template_validation_completed `
        -Message "All repository templates passed." `
        -Data @{ count = $templates.Count }
}
catch {
    Write-ValidationEvent -Level error -Event template_validation_failed `
        -Message $_.Exception.Message `
        -Data @{ validation_root = $validationRoot }
    throw
}
finally {
    if (Test-Path -LiteralPath $validationRoot) {
        Remove-Item -LiteralPath $validationRoot -Recurse -Force
    }
}
