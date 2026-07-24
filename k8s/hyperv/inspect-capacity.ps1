param(
    [string]$VmName = 'local-k3s-server',
    [string]$ResultPath = 'D:\HyperV\capacity-inspection.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $vm = Get-VM -Name $VmName -ErrorAction Stop
    $memory = Get-VMMemory -VMName $VmName -ErrorAction Stop
    $report = [ordered]@{
        succeeded = $true
        capturedAt = (Get-Date).ToString('o')
        vm = [ordered]@{
            name = $vm.Name
            state = $vm.State.ToString()
            assignedGiB = [math]::Round($vm.MemoryAssigned / 1GB, 3)
            demandGiB = [math]::Round($vm.MemoryDemand / 1GB, 3)
            dynamicMemoryEnabled = $memory.DynamicMemoryEnabled
            startupGiB = [math]::Round($memory.Startup / 1GB, 3)
            minimumGiB = [math]::Round($memory.Minimum / 1GB, 3)
            maximumGiB = [math]::Round($memory.Maximum / 1GB, 3)
            bufferPercent = $memory.Buffer
        }
    }
}
catch {
    $report = [ordered]@{
        succeeded = $false
        error = $_.Exception.Message
        stack = $_.ScriptStackTrace
    }
}

$report | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath $ResultPath -Encoding UTF8
if (-not $report.succeeded) {
    exit 1
}
