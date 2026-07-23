param(
    [string]$VmName = 'local-k3s-restore-test'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$vm = Get-VM -Name $VmName -ErrorAction SilentlyContinue
if (-not $vm) {
    exit 0
}
if ($vm.State -ne 'Off') {
    Stop-VM -Name $VmName -Force -TurnOff
}
Remove-VM -Name $VmName -Force
