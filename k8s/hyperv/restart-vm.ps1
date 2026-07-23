param(
    [string]$VmName = 'local-k3s-server',
    [string]$ResultPath = 'D:\HyperV\restart-vm-result.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $vm = Get-VM -Name $VmName -ErrorAction Stop
    if ($vm.State -eq 'Running') {
        Restart-VM -Name $VmName -Force -Wait
    } else {
        Start-VM -Name $VmName | Out-Null
    }
    $report = [ordered]@{
        succeeded = $true
        state = (Get-VM -Name $VmName).State.ToString()
    }
} catch {
    $report = [ordered]@{
        succeeded = $false
        error = $_.Exception.Message
        stack = $_.ScriptStackTrace
    }
}

$report | ConvertTo-Json | Set-Content -LiteralPath $ResultPath -Encoding UTF8
if (-not $report.succeeded) {
    exit 1
}
