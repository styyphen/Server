param(
    [string]$VmName = 'local-k3s-server',
    [string]$SwitchName = 'LocalServerNAT',
    [string]$NatName = 'LocalServerNAT',
    [string]$Gateway = '192.168.50.1',
    [string]$Prefix = '192.168.50.0/24',
    [string]$ResultPath = 'D:\HyperV\configure-nat-result.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $switch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
    if ($switch -and $switch.SwitchType -ne 'Internal') {
        throw "Existing switch '$SwitchName' is not Internal."
    }
    if (-not $switch) {
        $switch = New-VMSwitch -Name $SwitchName -SwitchType Internal
    }

    $adapterAlias = "vEthernet ($SwitchName)"
    $gatewayAddress = Get-NetIPAddress -InterfaceAlias $adapterAlias `
        -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object IPAddress -eq $Gateway
    if (-not $gatewayAddress) {
        New-NetIPAddress -InterfaceAlias $adapterAlias -IPAddress $Gateway `
            -PrefixLength 24 | Out-Null
    }

    $nat = Get-NetNat -Name $NatName -ErrorAction SilentlyContinue
    if ($nat -and $nat.InternalIPInterfaceAddressPrefix -ne $Prefix) {
        throw "Existing NAT '$NatName' uses a different prefix."
    }
    if (-not $nat) {
        New-NetNat -Name $NatName -InternalIPInterfaceAddressPrefix $Prefix |
            Out-Null
    }

    Connect-VMNetworkAdapter -VMName $VmName -SwitchName $SwitchName
    $report = [ordered]@{
        succeeded = $true
        switch = Get-VMSwitch -Name $SwitchName |
            Select-Object Name, SwitchType
        nat = Get-NetNat -Name $NatName |
            Select-Object Name, InternalIPInterfaceAddressPrefix
        adapter = Get-VMNetworkAdapter -VMName $VmName |
            Select-Object SwitchName, MacAddress
    }
} catch {
    $report = [ordered]@{
        succeeded = $false
        error = $_.Exception.Message
        stack = $_.ScriptStackTrace
    }
}

$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
if (-not $report.succeeded) {
    exit 1
}
