Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

docker compose up -d

Write-Host ""
Write-Host "Local observability stack is starting."
Write-Host "Grafana:      http://localhost:3001"
Write-Host "Prometheus:  http://localhost:9090"
Write-Host "Loki:        http://localhost:3100"
Write-Host "Tempo:       http://localhost:3200"
Write-Host "OTLP gRPC:   http://localhost:4317"
Write-Host "OTLP HTTP:   http://localhost:4318"
Write-Host ""
Write-Host "Run scripts/health-check.ps1 to inspect service health."
