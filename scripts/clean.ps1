Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "This removes containers and the observability network only."
Write-Host "Docker volumes are preserved so local telemetry data is not deleted."
docker compose down --remove-orphans
