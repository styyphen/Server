[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TaskName = 'Server-Platform-Daily-Health',
    [string]$HealthScriptPath,
    [string]$DailyAt = '06:00'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($HealthScriptPath)) {
    $HealthScriptPath = Join-Path $PSScriptRoot 'invoke-daily-health.ps1'
}
$resolvedScript = (Resolve-Path -LiteralPath $HealthScriptPath).Path
$time = [datetime]::ParseExact($DailyAt, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture)
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument (
    '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"' -f $resolvedScript
)
$trigger = New-ScheduledTaskTrigger -Daily -At $time
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 15)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

if ($PSCmdlet.ShouldProcess($TaskName, 'Register daily read-only platform health task')) {
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Description (
            'Runs the read-only Hyper-V and Kubernetes health gates and writes structured reports.'
        ) -Force | Out-Null
    Write-Host "Registered '$TaskName' to run daily at $DailyAt."
}
