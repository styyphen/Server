# Troubleshooting

## Stack Does Not Start

Run:

```powershell
docker compose ps
docker compose logs
```

Check whether another local process is already using ports `3001`, `9090`, `9093`, `3100`, `3200`, `4317`, or `4318`.

## Grafana Has No Data

Confirm the application is sending telemetry to:

- `http://localhost:4317` for OTLP gRPC
- `http://localhost:4318` for OTLP HTTP

Then check collector logs:

```powershell
docker compose logs otel-collector
```

Confirm Grafana provisioning loaded:

```powershell
docker compose logs grafana
```

Open Grafana at http://localhost:3001 and check the `Local Observability` folder.

## Prometheus Targets Are Down

Open http://localhost:9090/targets and inspect the failing target. Run:

```powershell
.\scripts\health-check.ps1
```

## Sample Telemetry Test Fails

Run:

```powershell
dotnet build .\examples\dotnet-minimal-api\DotnetMinimalApi.csproj
docker compose logs otel-collector
```

If metrics are missing immediately after a request, wait for the Prometheus scrape interval and retry. The default scrape interval is 15 seconds.

If traces are missing, check Tempo and Collector logs:

```powershell
docker compose logs tempo
docker compose logs otel-collector
```

## Safe Recovery

Restart the stack:

```powershell
.\scripts\restart.ps1
```

This does not delete volumes.
