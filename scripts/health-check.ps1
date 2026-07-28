Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$services = @(
    @{ Name = "Grafana"; Url = "http://localhost:3001/api/health" },
    @{ Name = "Prometheus"; Url = "http://localhost:9090/-/healthy" },
    @{ Name = "Alertmanager"; Url = "http://localhost:9093/-/healthy" },
    @{ Name = "Blackbox Exporter"; Url = "http://localhost:9115/-/healthy" },
    @{ Name = "Loki"; Url = "http://localhost:3100/ready" },
    @{ Name = "Tempo"; Url = "http://localhost:3200/ready" },
    @{ Name = "OTel Collector"; Url = "http://localhost:13133/" },
    @{ Name = "cAdvisor"; Url = "http://localhost:8080/healthz" },
    @{ Name = "Node Exporter"; Url = "http://localhost:9100/metrics" }
)

$failed = $false

Write-Host "Container status"
docker compose ps
Write-Host ""
Write-Host "Endpoint checks"

foreach ($service in $services) {
    try {
        $response = Invoke-WebRequest -Uri $service.Url -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
            Write-Host ("OK   {0} {1}" -f $service.Name, $service.Url)
        }
        else {
            $failed = $true
            Write-Host ("FAIL {0} returned HTTP {1}" -f $service.Name, $response.StatusCode)
        }
    }
    catch {
        $failed = $true
        Write-Host ("FAIL {0} {1}" -f $service.Name, $_.Exception.Message)
    }
}

if ($failed) {
    exit 1
}
