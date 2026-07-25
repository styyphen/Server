[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TaskName = 'Server-Platform-Weekly-Registry-Maintenance',
    [string]$MaintenanceScriptPath,
    [string]$KubeconfigPath = 'D:\HyperV\credentials\k3s-admin.yaml',
    [DayOfWeek]$DayOfWeek = [DayOfWeek]::Sunday,
    [string]$WeeklyAt = '04:00'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($MaintenanceScriptPath)) {
    $MaintenanceScriptPath = Join-Path $PSScriptRoot 'invoke-registry-maintenance.ps1'
}
$resolvedScript = (Resolve-Path -LiteralPath $MaintenanceScriptPath).Path
$resolvedKubeconfig = (Resolve-Path -LiteralPath $KubeconfigPath).Path
$time = [datetime]::ParseExact($WeeklyAt, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture)
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument (
    '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"' -f $resolvedScript
)
$trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek $DayOfWeek -At $time
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

if ($PSCmdlet.ShouldProcess($TaskName, 'Register controlled weekly Registry maintenance task')) {
    $acl = Get-Acl -LiteralPath $resolvedKubeconfig
    $systemRead = [System.Security.AccessControl.FileSystemAccessRule]::new(
        [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18'),
        [System.Security.AccessControl.FileSystemRights]::Read,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    $acl.SetAccessRule($systemRead)
    Set-Acl -LiteralPath $resolvedKubeconfig -AclObject $acl
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Description (
            'After a fresh backup, stops Registry, removes untagged content, and restores Registry.'
        ) -Force | Out-Null
    Write-Host "Registered '$TaskName' for $DayOfWeek at $WeeklyAt."
}
