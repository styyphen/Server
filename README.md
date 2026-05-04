# Local Observability Server

Reusable Docker-based observability for local development. Applications send OpenTelemetry logs, metrics, and traces to one endpoint; this stack stores and visualizes them with Grafana, Prometheus, Loki, and Tempo.

## Start

```powershell
Copy-Item .env.example .env
.\scripts\start.ps1
```

Open:

- Grafana: http://localhost:3001
- Prometheus: http://localhost:9090
- Alertmanager: http://localhost:9093
- Loki: http://localhost:3100
- Tempo: http://localhost:3200

Default Grafana credentials are `admin` / `admin` unless changed in `.env`.

## Application Endpoint

Configure applications to export OpenTelemetry to:

- OTLP gRPC: `http://localhost:4317`
- OTLP HTTP: `http://localhost:4318`

Applications should set `service.name`, `service.version`, and `deployment.environment` resource attributes.

## .NET Integration

The reusable integration library lives in `src/Luhl.Observability`.

```csharp
builder.Services.AddProjectObservability(
    builder.Configuration,
    builder.Environment,
    builder.Logging);

var app = builder.Build();

app.UseProjectObservability();
```

Required appsettings:

```json
{
  "Observability": {
    "ServiceName": "orders-api",
    "ServiceVersion": "1.0.0",
    "EnvironmentName": "Development",
    "OtlpEndpoint": "http://localhost:4317"
  }
}
```

## Commands

```powershell
.\scripts\start.ps1
.\scripts\health-check.ps1
.\scripts\test-dotnet-sample.ps1
.\scripts\restart.ps1
.\scripts\stop.ps1
.\scripts\clean.ps1
```

`clean.ps1` keeps Docker volumes by default so local telemetry data is not deleted accidentally.

## Current Status

Implemented:

- Docker Compose stack
- Grafana, Prometheus, Loki, Tempo, OpenTelemetry Collector
- Alertmanager, cAdvisor, Node Exporter
- Grafana datasource and dashboard provisioning
- Service, logs, traces, alerts, container health, and system health dashboards
- Default Prometheus alert rules and Alertmanager routing
- PowerShell lifecycle scripts
- .NET sample API that emits OTLP logs, metrics, and traces
- Reusable `Luhl.Observability` .NET integration library
- Automated sample telemetry validation script

Use `.\scripts\test-dotnet-sample.ps1` after changes to prove metrics, logs, and traces still flow end to end.
