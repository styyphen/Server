param(
    [string]$VmName = 'local-k3s-server',
    [string]$OutputPath = 'D:\HyperV\local-k3s-server-ip.txt',
    [int]$TimeoutSeconds = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)

do {
    $addresses = @(Get-VMNetworkAdapter -VMName $VmName).IPAddresses |
        Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' -and $_ -notlike '169.254.*' }
    if (@($addresses).Count -gt 0) {
        @($addresses)[0] | Set-Content -LiteralPath $OutputPath -Encoding ASCII
        exit 0
    }
    Start-Sleep -Seconds 5
} while ((Get-Date) -lt $deadline)

throw "VM '$VmName' did not report an IPv4 address within $TimeoutSeconds seconds."
