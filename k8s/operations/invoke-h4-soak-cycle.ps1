[CmdletBinding()]
param(
    [string]$KubectlPath = 'D:\HyperV\tools\kubectl-v1.36.1.exe',
    [string]$KubeconfigPath = 'D:\HyperV\credentials\k3s-admin.yaml',
    [string]$OutputDirectory = 'D:\HyperV\operations\h4-soak'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$startedAt = Get-Date
$day = $startedAt.ToUniversalTime().ToString('yyyyMMdd')
$cyclePath = Join-Path $OutputDirectory "cycle-$day.json"
$statePath = Join-Path $OutputDirectory 'state.json'
$steps = [System.Collections.Generic.List[object]]::new()

function Write-SoakEvent {
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

function Invoke-Step {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action
    )
    $stepStarted = Get-Date
    try {
        $evidence = & $Action
        $steps.Add([pscustomobject]@{
            name = $Name
            status = 'passed'
            duration_seconds = [math]::Round(((Get-Date) - $stepStarted).TotalSeconds, 2)
            evidence = $evidence
        })
    }
    catch {
        $steps.Add([pscustomobject]@{
            name = $Name
            status = 'failed'
            duration_seconds = [math]::Round(((Get-Date) - $stepStarted).TotalSeconds, 2)
            evidence = @{ error = $_.Exception.Message; stack = $_.ScriptStackTrace }
        })
        throw
    }
}

function Invoke-KubectlJson {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = & $KubectlPath --kubeconfig $KubeconfigPath @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "kubectl $($Arguments -join ' ') failed: $($output -join [Environment]::NewLine)"
    }
    ($output -join "`n") | ConvertFrom-Json
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
if (Test-Path -LiteralPath $cyclePath) {
    $existing = Get-Content -Raw -LiteralPath $cyclePath | ConvertFrom-Json
    Write-SoakEvent -Level $(if ($existing.succeeded) { 'info' } else { 'error' }) `
        -Event soak_cycle_already_recorded -Message "H4 cycle already exists for UTC day $day." `
        -Data @{ report = $cyclePath; succeeded = $existing.succeeded }
    if (-not $existing.succeeded) { exit 1 }
    exit 0
}

if (-not (Test-Path -LiteralPath $statePath)) {
    $pods = Invoke-KubectlJson -Arguments @('get', 'pods', '-A', '-o', 'json')
    $baseline = @{}
    foreach ($pod in $pods.items) {
        $key = "$($pod.metadata.namespace)/$($pod.metadata.name)"
        $baseline[$key] = [int](@($pod.status.containerStatuses |
            Measure-Object -Property restartCount -Sum).Sum)
    }
    [ordered]@{
        schema_version = 1
        started_at = $startedAt.ToUniversalTime().ToString('o')
        required_hours = 168
        required_successful_days = 7
        baseline_restarts = $baseline
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statePath -Encoding UTF8
}

$succeeded = $false
try {
    Write-SoakEvent -Level info -Event soak_cycle_started `
        -Message "H4 soak cycle started for UTC day $day." -Data @{ report = $cyclePath }

    Invoke-Step -Name platform_health -Action {
        $healthDirectory = Join-Path $OutputDirectory "health-$day"
        & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `
            (Join-Path $PSScriptRoot 'invoke-daily-health.ps1') `
            -KubectlPath $KubectlPath -KubeconfigPath $KubeconfigPath `
            -OutputDirectory $healthDirectory
        if ($LASTEXITCODE -ne 0) { throw 'Platform health gate failed.' }
        $health = Get-Content -Raw -LiteralPath (Join-Path $healthDirectory 'latest.json') |
            ConvertFrom-Json
        @{
            report = Join-Path $healthDirectory 'latest.json'
            checks = $health.checks.Count
        }
    }

    Invoke-Step -Name backup_verification -Action {
        $latest = Get-ChildItem -LiteralPath 'D:\server-backups\platform' -Directory `
            -Filter 'daily-*' | Sort-Object Name -Descending | Select-Object -First 1
        if ($null -eq $latest) { throw 'No platform backup exists.' }
        $ageHours = [math]::Round(((Get-Date) - $latest.CreationTime).TotalHours, 2)
        if ($ageHours -gt 26) {
            throw "Newest platform backup is $ageHours hours old; maximum is 26 hours."
        }
        & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `
            (Join-Path $PSScriptRoot 'test-platform-backup.ps1') -BackupPath $latest.FullName
        if ($LASTEXITCODE -ne 0) { throw 'Backup verification failed.' }
        @{ backup = $latest.FullName; age_hours = $ageHours }
    }

    Invoke-Step -Name representative_ci -Action {
        $runner = Invoke-KubectlJson -Arguments @(
            '-n', 'ci-jobs', 'get', 'pods',
            '-l', 'app.kubernetes.io/name=gitea-runner', '-o', 'json'
        )
        $readyRunner = @($runner.items | Where-Object {
            $_.status.phase -eq 'Running' -and
            @($_.status.containerStatuses | Where-Object { -not $_.ready }).Count -eq 0
        } | Select-Object -First 1)
        if ($readyRunner.Count -ne 1) { throw 'No Ready Gitea runner pod exists.' }
        $output = & $KubectlPath --kubeconfig $KubeconfigPath -n ci-jobs exec `
            $readyRunner[0].metadata.name -- /opt/ci/run-representative-pipeline.sh 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Representative CI failed: $($output -join [Environment]::NewLine)"
        }
        @{ runner = $readyRunner[0].metadata.name; tail = @($output | Select-Object -Last 8) }
    }

    Invoke-Step -Name sequential_addons -Action {
        & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `
            (Join-Path $PSScriptRoot 'invoke-phase-g-acceptance.ps1') `
            -KubectlPath $KubectlPath -KubeconfigPath $KubeconfigPath `
            -OutputDirectory (Join-Path $OutputDirectory "addons-$day")
        if ($LASTEXITCODE -ne 0) { throw 'Sequential add-on acceptance failed.' }
        $report = Get-ChildItem -LiteralPath (Join-Path $OutputDirectory "addons-$day") `
            -Filter 'phase-g-*.json' -File | Sort-Object Name -Descending |
            Select-Object -First 1
        @{ report = $report.FullName }
    }

    Invoke-Step -Name operational_evidence -Action {
        $soakState = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
        $soakStarted = [datetimeoffset]::Parse($soakState.started_at)
        $pods = Invoke-KubectlJson -Arguments @('get', 'pods', '-A', '-o', 'json')
        $restarts = @{}
        foreach ($pod in $pods.items) {
            $key = "$($pod.metadata.namespace)/$($pod.metadata.name)"
            $restarts[$key] = [int](@($pod.status.containerStatuses |
                Measure-Object -Property restartCount -Sum).Sum)
        }
        $alerts = Invoke-KubectlJson -Arguments @(
            'get',
            '--raw=/api/v1/namespaces/observability/services/http:alertmanager:9093/proxy/api/v2/alerts'
        )
        $events = Invoke-KubectlJson -Arguments @(
            'get', 'events', '-A', '--field-selector=type=Warning', '-o', 'json'
        )
        $recentWarnings = @($events.items | ForEach-Object {
            $event = $_
            $timestamp = @(
                $event.eventTime
                $event.series.lastObservedTime
                $event.lastTimestamp
                $event.metadata.creationTimestamp
            ) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
                Select-Object -First 1
            if ($null -ne $timestamp -and
                [datetimeoffset]::Parse([string]$timestamp) -ge $soakStarted) {
                @{
                    namespace = $event.metadata.namespace
                    reason = $event.reason
                    message = $event.message
                    observed_at = [string]$timestamp
                }
            }
        })
        @{
            pod_restarts = $restarts
            active_alerts = @($alerts).Count
            alerts = @($alerts)
            warning_events = $recentWarnings
        }
    }
    $succeeded = $true
}
catch {
    Write-SoakEvent -Level error -Event soak_cycle_failed `
        -Message $_.Exception.Message -Data @{ stack = $_.ScriptStackTrace }
}
finally {
    $report = [ordered]@{
        schema_version = 1
        day_utc = $day
        succeeded = $succeeded
        started_at = $startedAt.ToUniversalTime().ToString('o')
        completed_at = (Get-Date).ToUniversalTime().ToString('o')
        duration_seconds = [math]::Round(((Get-Date) - $startedAt).TotalSeconds, 2)
        steps = $steps
    }
    $report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $cyclePath -Encoding UTF8
    Write-SoakEvent -Level $(if ($succeeded) { 'info' } else { 'error' }) `
        -Event soak_cycle_completed -Message "H4 soak cycle completed; report: $cyclePath" `
        -Data @{ succeeded = $succeeded; report = $cyclePath }
}

if (-not $succeeded) { exit 1 }
