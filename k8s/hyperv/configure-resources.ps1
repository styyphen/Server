param(
    [string]$VmName = 'local-k3s-server',
    [string]$ResultPath = 'D:\HyperV\configure-resources-result.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Set-VMMemory -VMName $VmName -DynamicMemoryEnabled $true `
        -MinimumBytes 5GB -StartupBytes 5GB -MaximumBytes 8GB -Buffer 5
    Set-VMProcessor -VMName $VmName -Count 6
    Set-VM -Name $VmName -AutomaticStartAction Start -AutomaticStartDelay 15 `
        -AutomaticStopAction ShutDown -AutomaticCheckpointsEnabled $false
    $report = [ordered]@{
        succeeded = $true
        vm = Get-VM -Name $VmName |
            Select-Object Name, State, ProcessorCount, MemoryStartup,
                DynamicMemoryEnabled, AutomaticStartAction,
                AutomaticStopAction, AutomaticCheckpointsEnabled
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
