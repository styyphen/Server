param(
    [string]$VmName = 'local-k3s-server',
    [string]$ResultPath = 'D:\HyperV\local-k3s-server-result.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $vm = Get-VM -Name $VmName -ErrorAction Stop
    if ($vm.State -ne 'Running') {
        Start-VM -Name $VmName | Out-Null
    }
    Start-Sleep -Seconds 5
    $report = [ordered]@{
        succeeded = $true
        vm = Get-VM -Name $VmName |
            Select-Object Name, State, Generation, ProcessorCount, MemoryAssigned, Path
        network = Get-VMNetworkAdapter -VMName $VmName |
            Select-Object SwitchName, MacAddress, IPAddresses
        disks = @(Get-VMHardDiskDrive -VMName $VmName | Select-Object Path)
    }
} catch {
    $report = [ordered]@{
        succeeded = $false
        error = $_.Exception.Message
        stack = $_.ScriptStackTrace
    }
}

$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
if (-not $report.succeeded) {
    exit 1
}
