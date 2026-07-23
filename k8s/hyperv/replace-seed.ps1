param(
    [string]$VmName = 'local-k3s-server',
    [string]$SeedIso = 'D:\HyperV\seed\azure-seed.iso'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SeedIso)) {
    throw "Seed ISO does not exist: $SeedIso"
}
$vm = Get-VM -Name $VmName -ErrorAction Stop
if ($vm.State -ne 'Off') {
    Stop-VM -Name $VmName -Force -TurnOff
}
$dvd = Get-VMDvdDrive -VMName $VmName | Select-Object -First 1
if ($dvd) {
    Set-VMDvdDrive -VMName $VmName -ControllerNumber $dvd.ControllerNumber `
        -ControllerLocation $dvd.ControllerLocation -Path $SeedIso
} else {
    Add-VMDvdDrive -VMName $VmName -Path $SeedIso
}
Start-VM -Name $VmName | Out-Null
