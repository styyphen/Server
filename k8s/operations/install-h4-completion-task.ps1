[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TaskName = 'Server-Platform-H4-Completion-Gate',
    [string]$CompletionScriptPath,
    [string]$StatePath = 'D:\HyperV\operations\h4-soak\state.json',
    [int]$DelayMinutes = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($CompletionScriptPath)) {
    $CompletionScriptPath = Join-Path $PSScriptRoot 'complete-h4-soak.ps1'
}
$resolvedScript = (Resolve-Path -LiteralPath $CompletionScriptPath).Path
$state = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json
$started = [datetimeoffset]::Parse($state.started_at)
$runAt = $started.AddHours([double]$state.required_hours).
    AddMinutes($DelayMinutes).LocalDateTime

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument (
    '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"' -f $resolvedScript
)
$trigger = New-ScheduledTaskTrigger -Once -At $runAt
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 15)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' `
    -LogonType ServiceAccount -RunLevel Highest

if ($PSCmdlet.ShouldProcess($TaskName, "Register H4 completion gate for $($runAt.ToString('o'))")) {
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Description (
            'Evaluates H4 only after 168 hours; refuses completion without seven successful days.'
        ) -Force | Out-Null
    Write-Host "Registered '$TaskName' for $($runAt.ToString('o'))."
}
