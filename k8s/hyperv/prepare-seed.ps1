param(
    [string]$OutputDirectory = 'D:\HyperV\seed',
    [string]$PrivateKeyPath = 'D:\HyperV\credentials\k3s-server-ed25519'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$template = Join-Path $PSScriptRoot 'user-data.template'
$metaData = Join-Path $PSScriptRoot 'meta-data'
$publicKeyPath = "$PrivateKeyPath.pub"
if (-not (Test-Path -LiteralPath $publicKeyPath)) {
    throw "SSH public key does not exist: $publicKeyPath"
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$publicKey = (Get-Content -LiteralPath $publicKeyPath -Raw).Trim()
$userData = (Get-Content -LiteralPath $template -Raw).Replace('__SSH_PUBLIC_KEY__', $publicKey)
$userDataPath = Join-Path $OutputDirectory 'user-data'
$metaDataPath = Join-Path $OutputDirectory 'meta-data'
[System.IO.File]::WriteAllText(
    $userDataPath,
    $userData,
    (New-Object System.Text.UTF8Encoding($false)))
Copy-Item -LiteralPath $metaData -Destination $metaDataPath -Force

Write-Host "Seed inputs prepared in $OutputDirectory"
