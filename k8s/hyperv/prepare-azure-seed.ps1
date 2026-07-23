param(
    [string]$OutputDirectory = 'D:\HyperV\seed',
    [string]$PrivateKeyPath = 'D:\HyperV\credentials\k3s-server-ed25519'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$userData = Get-Content -LiteralPath (Join-Path $OutputDirectory 'user-data') -Raw
$customData = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userData))
$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<Environment xmlns="http://schemas.dmtf.org/ovf/environment/1">
  <ProvisioningSection xmlns="http://schemas.microsoft.com/windowsazure">
    <Version>1.0</Version>
    <LinuxProvisioningConfigurationSet xmlns="http://schemas.microsoft.com/windowsazure"
      xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
      <ConfigurationSetType>LinuxProvisioningConfiguration</ConfigurationSetType>
      <HostName>k3s-server</HostName>
      <UserName>developer</UserName>
      <UserPassword></UserPassword>
      <DisableSshPasswordAuthentication>true</DisableSshPasswordAuthentication>
      <CustomData>$customData</CustomData>
    </LinuxProvisioningConfigurationSet>
  </ProvisioningSection>
  <PlatformSettingsSection xmlns="http://schemas.microsoft.com/windowsazure">
    <Version>1.0</Version>
    <PlatformSettings>
      <KmsServerHostname></KmsServerHostname>
      <ProvisionGuestAgent>true</ProvisionGuestAgent>
    </PlatformSettings>
  </PlatformSettingsSection>
</Environment>
"@

[System.IO.File]::WriteAllText(
    (Join-Path $OutputDirectory 'ovf-env.xml'),
    $xml,
    (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Azure OVF seed input prepared in $OutputDirectory"
