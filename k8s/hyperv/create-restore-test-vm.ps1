param(
    [string]$VmName = 'local-k3s-restore-test',
    [string]$VmRoot = 'D:\HyperV\restore-test',
    [string]$VhdxPath = 'D:\HyperV\restore-test\local-k3s-server-restore-test.vhdx',
    [string]$SwitchName = 'LocalServerNAT',
    [string]$MacAddress = '00155D826500',
    [string]$ResultPath = 'D:\HyperV\restore-test-result.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    if (Get-VM -Name $VmName -ErrorAction SilentlyContinue) {
        throw "Restore-test VM '$VmName' already exists."
    }
    if (-not (Test-Path -LiteralPath $VhdxPath)) {
        throw "Restore-test disk does not exist: $VhdxPath"
    }
    New-VM -Name $VmName -Generation 1 -MemoryStartupBytes 6GB `
        -VHDPath $VhdxPath -Path $VmRoot -SwitchName $SwitchName | Out-Null
    Set-VMProcessor -VMName $VmName -Count 4
    Set-VMMemory -VMName $VmName -DynamicMemoryEnabled $false -StartupBytes 6GB
    Set-VM -VMName $VmName -AutomaticStartAction Nothing `
        -AutomaticStopAction ShutDown -AutomaticCheckpointsEnabled $false
    Set-VMNetworkAdapter -VMName $VmName -StaticMacAddress $MacAddress `
        -DhcpGuard On -RouterGuard On
    Start-VM -Name $VmName | Out-Null
    $report = [ordered]@{
        succeeded = $true
        vm = Get-VM -Name $VmName |
            Select-Object Name, State, Generation, ProcessorCount, MemoryAssigned
        disk = (Get-VMHardDiskDrive -VMName $VmName | Select-Object -First 1).Path
    }
} catch {
    $report = [ordered]@{
        succeeded = $false
        error = $_.Exception.Message
        stack = $_.ScriptStackTrace
    }
}

$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
if (-not $report.succeeded) {
    exit 1
}
