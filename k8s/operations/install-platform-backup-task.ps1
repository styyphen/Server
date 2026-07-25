[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TaskName = 'Server-Platform-Daily-Backup',
    [string]$BackupScriptPath,
    [string]$KubeconfigPath = 'D:\HyperV\credentials\k3s-admin.yaml',
    [string]$DailyAt = '02:00'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($BackupScriptPath)) {
    $BackupScriptPath = Join-Path $PSScriptRoot 'invoke-platform-backup.ps1'
}
$resolvedScript = (Resolve-Path -LiteralPath $BackupScriptPath).Path
$resolvedKubeconfig = (Resolve-Path -LiteralPath $KubeconfigPath).Path
$time = [datetime]::ParseExact($DailyAt, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture)

$systemSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18')
$systemRead = [System.Security.AccessControl.FileSystemAccessRule]::new(
    $systemSid,
    [System.Security.AccessControl.FileSystemRights]::Read,
    [System.Security.AccessControl.AccessControlType]::Allow
)

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument (
    '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"' -f $resolvedScript
)
$trigger = New-ScheduledTaskTrigger -Daily -At $time
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

if ($PSCmdlet.ShouldProcess($TaskName, 'Register daily logical platform backup task')) {
    $acl = Get-Acl -LiteralPath $resolvedKubeconfig
    $acl.SetAccessRule($systemRead)
    Set-Acl -LiteralPath $resolvedKubeconfig -AclObject $acl
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Description (
            'Creates hashed logical platform backups and enforces bounded backup retention.'
        ) -Force | Out-Null
    Write-Host "Registered '$TaskName' to run daily at $DailyAt."
}
