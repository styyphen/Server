Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

docker compose down
docker compose up -d

& (Join-Path $PSScriptRoot "health-check.ps1")
