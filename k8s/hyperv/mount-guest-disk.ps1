param(
    [string]$VmName = 'local-k3s-server',
    [string]$VhdxPath = 'D:\HyperV\local-k3s-server\ubuntu-k3s-azure-udf.vhdx',
    [string]$ResultPath = 'D:\HyperV\mount-guest-disk-result.txt'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$vm = Get-VM -Name $VmName -ErrorAction Stop
if ($vm.State -ne 'Off') {
    Stop-VM -Name $VmName -Force -TurnOff
}
& wsl.exe --mount $VhdxPath --vhd --bare
if ($LASTEXITCODE -ne 0) {
    throw "wsl --mount failed with exit code $LASTEXITCODE"
}
'mounted' | Set-Content -LiteralPath $ResultPath -Encoding ASCII
