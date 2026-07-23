param(
    [string]$VhdxPath = 'D:\HyperV\local-k3s-server\ubuntu-k3s-azure-udf.vhdx'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

& wsl.exe --unmount $VhdxPath
if ($LASTEXITCODE -ne 0) {
    throw "wsl --unmount failed with exit code $LASTEXITCODE"
}
