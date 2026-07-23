Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Project = Join-Path $Root "examples/dotnet-minimal-api/DotnetMinimalApi.csproj"
$Url = "http://localhost:5088"
$SampleRunId = [guid]::NewGuid().ToString("N")

Set-Location $Root

dotnet build $Project

$env:ASPNETCORE_ENVIRONMENT = "Development"
$env:SAMPLE_RUN_ID = $SampleRunId
$process = Start-Process -FilePath "dotnet" `
    -ArgumentList "run --project `"$Project`" --urls $Url" `
    -WorkingDirectory $Root `
    -WindowStyle Hidden `
    -PassThru

try {
    $ready = $false
    for ($attempt = 1; $attempt -le 20; $attempt++) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "$Url/health" -TimeoutSec 2
            if ($response.StatusCode -eq 200) {
                $ready = $true
                break
            }
        }
        catch {
            Start-Sleep -Seconds 1
        }
    }

    if (-not $ready) {
        throw "Sample API did not become ready at $Url."
    }

    1..5 | ForEach-Object {
        Invoke-WebRequest -UseBasicParsing -Uri "$Url/work" -TimeoutSec 10 | Out-Null
    }

    Invoke-WebRequest -UseBasicParsing -Uri "$Url/warning" -TimeoutSec 10 | Out-Null

    try {
        Invoke-WebRequest -UseBasicParsing -Uri "$Url/error" -TimeoutSec 10 | Out-Null
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -ne 500) {
            throw
        }
    }

    $metrics = $null
    for ($attempt = 1; $attempt -le 18; $attempt++) {
        Start-Sleep -Seconds 5
        $metricQuery = [uri]::EscapeDataString("sum(sample_requests_total{service_name=""dotnet-minimal-api"", sample_run_id=""$SampleRunId""})")
        $metrics = Invoke-RestMethod "http://localhost:9090/api/v1/query?query=$metricQuery"
        if ($metrics.data.result.Count -gt 0 -and [double]$metrics.data.result[0].value[1] -gt 0) {
            break
        }
    }

    $logsQuery = [uri]::EscapeDataString('{service_name="dotnet-minimal-api"}')
    $logs = Invoke-RestMethod "http://localhost:3100/loki/api/v1/query_range?query=$logsQuery&limit=5"
    $traces = Invoke-RestMethod "http://localhost:3200/api/search?limit=10"

    if (-not $metrics -or $metrics.data.result.Count -eq 0 -or [double]$metrics.data.result[0].value[1] -le 0) {
        throw "Prometheus did not return sample_requests_total."
    }

    if ($logs.data.result.Count -eq 0) {
        throw "Loki did not return logs for dotnet-minimal-api."
    }

    if ($traces.traces.Count -eq 0) {
        throw "Tempo did not return traces."
    }

    Write-Host "OK Prometheus fresh sample_requests_total increase: $($metrics.data.result[0].value[1])"
    Write-Host "OK Loki dotnet-minimal-api streams: $($logs.data.result.Count)"
    Write-Host "OK Tempo traces: $($traces.traces.Count)"
}
finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force
    }
}
