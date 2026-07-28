[CmdletBinding()]
param(
    [string]$KubectlPath = 'kubectl',
    [string]$KubeconfigPath = '/etc/rancher/k3s/k3s.yaml',
    [string]$OutputDirectory = './.local/server-platform/operations/addons',
    [int]$TimeoutSeconds = 900
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$startedAt = Get-Date
$results = [System.Collections.Generic.List[object]]::new()
$addons = @('azurite', 'fake-gcs', 'localstack', 'sonarqube')
$manager = Join-Path $PSScriptRoot 'manage-addon.ps1'
$health = Join-Path $PSScriptRoot 'invoke-daily-health.ps1'

function Write-AcceptanceEvent {
    param(
        [Parameter(Mandatory)][ValidateSet('info', 'error')][string]$Level,
        [Parameter(Mandatory)][string]$Event,
        [Parameter(Mandatory)][string]$Message,
        [hashtable]$Data = @{}
    )
    [ordered]@{
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
        level = $Level
        event = $Event
        message = $Message
        data = $Data
    } | ConvertTo-Json -Depth 8 -Compress
}

function Invoke-Manager {
    param([string]$Addon, [string]$Action)
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $manager `
        -Name $Addon -Action $Action -KubectlPath $KubectlPath `
        -KubeconfigPath $KubeconfigPath -TimeoutSeconds $TimeoutSeconds
    if ($LASTEXITCODE -ne 0) {
        throw "Add-on lifecycle failed: $Action $Addon."
    }
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$reportPath = Join-Path $OutputDirectory "phase-g-$($startedAt.ToUniversalTime().ToString('yyyyMMddTHHmmssZ')).json"
$succeeded = $false

try {
    Write-AcceptanceEvent -Level info -Event phase_g_acceptance_started `
        -Message 'Sequential Phase G acceptance started.' -Data @{ addons = $addons }

    foreach ($addon in $addons) {
        $addonStartedAt = Get-Date
        try {
            Invoke-Manager -Addon $addon -Action start
            Invoke-Manager -Addon $addon -Action test

            $capacity = & $KubectlPath --kubeconfig $KubeconfigPath top node 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Capacity collection failed: $($capacity -join [Environment]::NewLine)"
            }
            $healthPath = Join-Path $OutputDirectory "health-$addon"
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $health `
                -KubectlPath $KubectlPath -KubeconfigPath $KubeconfigPath `
                -OutputDirectory $healthPath
            if ($LASTEXITCODE -ne 0) {
                throw "Platform health degraded while '$addon' was active."
            }

            $results.Add([pscustomobject]@{
                addon = $addon
                status = 'passed'
                duration_seconds = [math]::Round(((Get-Date) - $addonStartedAt).TotalSeconds, 2)
                capacity = $capacity -join "`n"
            })
            Write-AcceptanceEvent -Level info -Event addon_sequential_acceptance_passed `
                -Message "Sequential acceptance passed for '$addon'." -Data @{ addon = $addon }
        }
        finally {
            Invoke-Manager -Addon $addon -Action stop
        }
    }

    $stateJson = (& $KubectlPath --kubeconfig $KubeconfigPath -n cloud-emulators `
        get deployment,statefulset -l platform.dev.home.arpa/addon -o json) -join "`n"
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to verify final add-on state.'
    }
    $state = $stateJson | ConvertFrom-Json
    $active = @($state.items | Where-Object { [int]$_.spec.replicas -ne 0 })
    if ($active.Count -gt 0) {
        throw "Acceptance left $($active.Count) add-on workload(s) active."
    }
    $succeeded = $true
}
catch {
    Write-AcceptanceEvent -Level error -Event phase_g_acceptance_failed `
        -Message $_.Exception.Message -Data @{ stack = $_.ScriptStackTrace }
}
finally {
    foreach ($addon in $addons) {
        try {
            Invoke-Manager -Addon $addon -Action stop
        }
        catch {
            $succeeded = $false
            Write-AcceptanceEvent -Level error -Event phase_g_cleanup_failed `
                -Message $_.Exception.Message -Data @{ addon = $addon }
        }
    }
    $report = [ordered]@{
        schema_version = 1
        succeeded = $succeeded
        started_at = $startedAt.ToUniversalTime().ToString('o')
        completed_at = (Get-Date).ToUniversalTime().ToString('o')
        results = $results
    }
    $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-AcceptanceEvent -Level $(if ($succeeded) { 'info' } else { 'error' }) `
        -Event phase_g_acceptance_completed `
        -Message "Sequential Phase G acceptance completed; report: $reportPath" `
        -Data @{ succeeded = $succeeded; report = $reportPath }
}

if (-not $succeeded) {
    exit 1
}
