[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TaskName = 'Server-Platform-H4-Daily-Soak',
    [string]$SoakScriptPath,
    [string]$KubeconfigPath = 'D:\HyperV\credentials\k3s-admin.yaml',
    [string]$DailyAt = '07:00'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SoakScriptPath)) {
    $SoakScriptPath = Join-Path $PSScriptRoot 'invoke-h4-soak-cycle.ps1'
}
$resolvedScript = (Resolve-Path -LiteralPath $SoakScriptPath).Path
$resolvedKubeconfig = (Resolve-Path -LiteralPath $KubeconfigPath).Path
$time = [datetime]::ParseExact($DailyAt, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture)
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument (
    '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"' -f $resolvedScript
)
$trigger = New-ScheduledTaskTrigger -Daily -At $time
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' `
    -LogonType ServiceAccount -RunLevel Highest

if ($PSCmdlet.ShouldProcess($TaskName, 'Register daily H4 representative soak task')) {
    $acl = Get-Acl -LiteralPath $resolvedKubeconfig
    $systemSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $systemRead = [System.Security.AccessControl.FileSystemAccessRule]::new(
        $systemSid,
        [System.Security.AccessControl.FileSystemRights]::Read,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    $acl.SetAccessRule($systemRead)
    Set-Acl -LiteralPath $resolvedKubeconfig -AclObject $acl

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Description (
            'Runs one H4 health, backup, CI, add-on, alert, storage, and restart evidence cycle.'
        ) -Force | Out-Null
    Write-Host "Registered '$TaskName' to run daily at $DailyAt."
}
