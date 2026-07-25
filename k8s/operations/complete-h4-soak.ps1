[CmdletBinding()]
param(
    [string]$OutputDirectory = 'D:\HyperV\operations\h4-soak',
    [string]$ResultPath = 'D:\HyperV\operations\h4-soak\completion.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$statePath = Join-Path $OutputDirectory 'state.json'
if (-not (Test-Path -LiteralPath $statePath)) {
    throw "H4 soak has not started; '$statePath' does not exist."
}

$state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
$started = [datetimeoffset]::Parse($state.started_at)
$elapsedHours = [math]::Round(([datetimeoffset]::UtcNow - $started).TotalHours, 2)
$cycles = @(Get-ChildItem -LiteralPath $OutputDirectory -Filter 'cycle-*.json' -File |
    ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json })
$successful = @($cycles | Where-Object { $_.succeeded })
$failed = @($cycles | Where-Object { -not $_.succeeded })
$days = @($successful.day_utc | Sort-Object -Unique)

$activeAlerts = @()
$restartSamples = @{}
foreach ($cycle in $successful) {
    $evidence = @($cycle.steps | Where-Object { $_.name -eq 'operational_evidence' })[0].evidence
    $activeAlerts += @($evidence.alerts)
    foreach ($property in $evidence.pod_restarts.PSObject.Properties) {
        if (-not $restartSamples.ContainsKey($property.Name)) {
            $restartSamples[$property.Name] = [System.Collections.Generic.List[int]]::new()
        }
        $restartSamples[$property.Name].Add([int]$property.Value)
    }
}

$restartGrowth = @{}
foreach ($key in $restartSamples.Keys) {
    $values = $restartSamples[$key]
    if ($values.Count -gt 1) {
        $growth = $values[$values.Count - 1] - $values[0]
        if ($growth -gt 0) { $restartGrowth[$key] = $growth }
    }
}

$checks = [ordered]@{
    elapsed_168_hours = ($elapsedHours -ge [double]$state.required_hours)
    seven_successful_days = ($days.Count -ge [int]$state.required_successful_days)
    no_failed_cycles = ($failed.Count -eq 0)
    no_active_alerts = ($activeAlerts.Count -eq 0)
    no_restart_growth = ($restartGrowth.Count -eq 0)
}
$succeeded = @($checks.Values | Where-Object { -not $_ }).Count -eq 0
$result = [ordered]@{
    schema_version = 1
    succeeded = $succeeded
    evaluated_at = [datetimeoffset]::UtcNow.ToString('o')
    started_at = $state.started_at
    elapsed_hours = $elapsedHours
    successful_days = $days
    failed_cycles = @($failed.day_utc)
    active_alert_count = $activeAlerts.Count
    restart_growth = $restartGrowth
    checks = $checks
}
$result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
$result | ConvertTo-Json -Depth 12
if (-not $succeeded) { exit 1 }
