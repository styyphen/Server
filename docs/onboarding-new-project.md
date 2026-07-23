# Onboarding a New Project

Applications should publish telemetry only to OpenTelemetry. They should not depend directly on Grafana, Prometheus, Loki, or Tempo.

For .NET applications, use the `Luhl.Observability` project as the standard integration pattern.

## Required Settings

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

Use lower-case service names separated by hyphens.

## Endpoint

Use one of:

- OTLP gRPC: `http://localhost:4317`
- OTLP HTTP: `http://localhost:4318`

Prefer OTLP gRPC for .NET services unless the application runtime or library only supports HTTP.

If you only define `appsettings.Development.json`, run the app with:

```powershell
$env:ASPNETCORE_ENVIRONMENT = "Development"
dotnet run
```

For samples and local tools, keep a base `appsettings.json` as well so service identity does not fall back to library defaults when the app runs as `Production`.

## .NET Program.cs

```csharp
using Luhl.Observability;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddProjectObservability(
    builder.Configuration,
    builder.Environment,
    builder.Logging);

var app = builder.Build();

app.UseProjectObservability();

app.MapGet("/", () => Results.Ok(new
{
    Status = "OK"
}));

app.Run();
```

`UseProjectObservability()` maps `/health` and returns a JSON health response.

## Verification

1. Start this stack with `.\scripts\start.ps1`.
2. Start the application.
3. Send a request to the application.
4. Open Grafana at http://localhost:3001.
5. Check the service, logs, and traces dashboards.

## Active Availability Monitoring

To distinguish network unreachable from service unavailable, add the service health endpoint to `prometheus/health-targets.yml`:

```yaml
- targets:
    - http://host.docker.internal:5000/health
  labels:
    service_name: dotnet-minimal-api
    deployment_environment: Local
```

Then reload Prometheus:

```powershell
Invoke-WebRequest -UseBasicParsing -Method Post http://localhost:9090/-/reload
```

## Sample App Validation

Run:

```powershell
.\scripts\test-dotnet-sample.ps1
```

The script starts the sample API, sends traffic to `/work`, `/warning`, and `/error`, then verifies:

- `sample_requests_total` is present in Prometheus.
- `dotnet-minimal-api` logs are present in Loki.
- `dotnet-minimal-api` traces are present in Tempo.

## Service Naming

Use lower-case names separated by hyphens:

- `identity-api`
- `orders-api`
- `payments-api`
- `catalog-api`
- `notification-worker`
