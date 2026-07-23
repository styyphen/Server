param(
    [string]$OutputPath = 'D:\HyperV\hyperv-inspection.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $report = [ordered]@{
        succeeded = $true
        virtualMachines = @(Get-VM | Select-Object Name, State, Generation, Path)
        switches = @(Get-VMSwitch | Select-Object Name, SwitchType, NetAdapterInterfaceDescription)
        dvdDrives = @(Get-VMDvdDrive -VMName 'local-k3s-server' -ErrorAction SilentlyContinue |
            Select-Object Path, ControllerNumber, ControllerLocation)
        network = @(Get-VMNetworkAdapter -VMName 'local-k3s-server' -ErrorAction SilentlyContinue |
            Select-Object SwitchName, IPAddresses)
        targetFiles = @(Get-ChildItem 'D:\HyperV\local-k3s-server' -Force -ErrorAction SilentlyContinue |
            Select-Object FullName, Length, LastWriteTime)
    }
} catch {
    $report = [ordered]@{
        succeeded = $false
        error = $_.Exception.Message
        stack = $_.ScriptStackTrace
    }
}

$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
