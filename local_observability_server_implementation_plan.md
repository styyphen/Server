# Local Observability Server Implementation Plan

## 1. Purpose

This document describes how to build a reusable local observability environment that can be used across many repositories and projects without repeated setup work.

The goal is to run one local Docker-based observability server and allow each application to publish structured logs, metrics, traces, health signals, and custom business metrics into it using a small and repeatable configuration.

The setup must support:

- Reusable local development observability.
- Open-source tooling.
- Minimal per-project configuration.
- Structured logs.
- Application metrics.
- Distributed tracing.
- System and container health monitoring.
- Threshold-based alerts.
- Safe local self-healing.
- Vertical-slice implementation using multiple agents.

---

## 2. Target Architecture

```text
Any Application / Repository
        |
        | OpenTelemetry
        | Logs, Metrics, Traces
        v
OpenTelemetry Collector / Grafana Alloy
        |
        |-------------------|
        |                   |
        v                   v
   Prometheus              Loki
   Metrics Store           Logs Store
        |
        |                   |
        v                   v
      Grafana <--------- Tempo
      Dashboards          Traces Store
        |
        v
 Alerting + Notifications
        |
        v
 Local Recovery / Self-Healing
```

---

## 3. Core Design Decision

Each project must not directly depend on Grafana, Prometheus, Loki, or Tempo.

Each project should only publish telemetry to a single OpenTelemetry endpoint.

```text
Application -> OpenTelemetry Endpoint -> Observability Platform
```

This keeps each application clean, portable, and easy to onboard.

---

## 4. Recommended Open-Source Stack

| Concern | Tool | Responsibility |
|---|---|---|
| Telemetry ingestion | OpenTelemetry Collector or Grafana Alloy | Receive logs, metrics, and traces from applications |
| Metrics | Prometheus | Store and query metrics |
| Logs | Loki | Store structured application logs |
| Traces | Tempo | Store distributed traces |
| Dashboards | Grafana | Visualize metrics, logs, traces, and alerts |
| Alerts | Alertmanager / Grafana Alerting | Route and manage alerts |
| Container health | cAdvisor | Observe Docker container CPU, memory, network, and restarts |
| Host health | Node Exporter | Observe CPU, memory, disk, and filesystem metrics |
| Local recovery | Docker healthchecks and restart policies | Restart unhealthy services safely |

---

## 5. Repository Structure

Create a dedicated repository named:

```text
local-observability-server
```

Recommended structure:

```text
local-observability-server/
│
├── docker-compose.yml
├── .env.example
├── README.md
│
├── docs/
│   ├── implementation-plan.md
│   ├── onboarding-new-project.md
│   ├── alerting-guide.md
│   └── troubleshooting.md
│
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── datasources.yml
│   │   └── dashboards/
│   │       └── dashboards.yml
│   └── dashboards/
│       ├── dotnet-service-overview.json
│       ├── logs-overview.json
│       ├── traces-overview.json
│       ├── container-health.json
│       └── system-health.json
│
├── prometheus/
│   ├── prometheus.yml
│   └── alerts.yml
│
├── alertmanager/
│   └── alertmanager.yml
│
├── otel-collector/
│   └── otel-collector.yml
│
├── loki/
│   └── loki.yml
│
├── tempo/
│   └── tempo.yml
│
├── scripts/
│   ├── start.ps1
│   ├── stop.ps1
│   ├── restart.ps1
│   ├── clean.ps1
│   └── health-check.ps1
│
└── examples/
    └── dotnet-minimal-api/
        ├── Program.cs
        ├── appsettings.Development.json
        └── docker-compose.override.yml
```

---

## 6. Vertical Slice Implementation Model

The implementation should be split into vertical slices so that each slice delivers a usable part of the system from configuration through runtime validation.

Each slice should have:

- A clear outcome.
- A responsible agent.
- Inputs and outputs.
- Acceptance criteria.
- A test plan.
- A rollback plan.

---

# 7. Multi-Agent Work Breakdown

## Agent 1: Platform Orchestrator

### Responsibility

Own the overall Docker Compose platform and make sure all services run together reliably.

### Scope

- Docker Compose structure.
- Shared Docker network.
- Environment variables.
- Service dependencies.
- Volumes.
- Healthchecks.
- Restart policies.

### Deliverables

- `docker-compose.yml`
- `.env.example`
- `scripts/start.ps1`
- `scripts/stop.ps1`
- `scripts/restart.ps1`
- `scripts/health-check.ps1`

### Acceptance Criteria

- The full observability stack starts with one command.
- All containers use a shared Docker network.
- Services have meaningful container names.
- Services have restart policies.
- Core services expose stable local ports.
- Healthcheck script verifies that the platform is running.

### Example ports

```text
Grafana:        http://localhost:3001
Prometheus:     http://localhost:9090
Alertmanager:   http://localhost:9093
Loki:           http://localhost:3100
Tempo:          http://localhost:3200
OTLP gRPC:      http://localhost:4317
OTLP HTTP:      http://localhost:4318
```

---

## Agent 2: Telemetry Ingestion Slice

### Responsibility

Create the telemetry ingestion layer that receives logs, metrics, and traces from applications.

### Scope

- OpenTelemetry Collector or Grafana Alloy configuration.
- OTLP gRPC receiver.
- OTLP HTTP receiver.
- Export logs to Loki.
- Export metrics to Prometheus.
- Export traces to Tempo.

### Deliverables

- `otel-collector/otel-collector.yml`
- Collector service in `docker-compose.yml`
- Local test endpoint validation

### Acceptance Criteria

- Applications can send telemetry to `localhost:4317`.
- Applications can send telemetry to `localhost:4318`.
- Metrics are visible in Prometheus.
- Logs are visible in Loki.
- Traces are visible in Tempo.
- Grafana can query all three telemetry types.

### Slice flow

```text
Application
   -> OpenTelemetry Collector
      -> Prometheus
      -> Loki
      -> Tempo
```

---

## Agent 3: Metrics Slice

### Responsibility

Implement metrics collection and metrics storage.

### Scope

- Prometheus configuration.
- Prometheus scrape targets.
- Container metrics.
- Host metrics.
- Application metrics.
- Default alert rules.

### Deliverables

- `prometheus/prometheus.yml`
- `prometheus/alerts.yml`
- Prometheus service in `docker-compose.yml`
- cAdvisor service in `docker-compose.yml`
- Node Exporter service in `docker-compose.yml`

### Acceptance Criteria

- Prometheus UI loads successfully.
- Prometheus scrapes itself.
- Prometheus scrapes cAdvisor.
- Prometheus scrapes Node Exporter.
- Prometheus receives application metrics.
- Default alert rules load without errors.

### Default metrics to support

```text
http.server.request.duration
http.server.request.count
process.cpu.usage
process.memory.usage
dotnet.gc.heap.size
dotnet.thread_pool.thread.count
container_cpu_usage_seconds_total
container_memory_usage_bytes
node_filesystem_avail_bytes
```

---

## Agent 4: Logging Slice

### Responsibility

Implement structured logging using Loki and Grafana.

### Scope

- Loki configuration.
- Log ingestion from OpenTelemetry Collector.
- Structured log labels.
- Grafana Loki datasource.
- Logs dashboard.

### Deliverables

- `loki/loki.yml`
- Loki service in `docker-compose.yml`
- Grafana Loki datasource configuration
- `grafana/dashboards/logs-overview.json`

### Acceptance Criteria

- Application logs appear in Grafana.
- Logs can be filtered by service name.
- Logs can be filtered by environment.
- Logs can be filtered by log level.
- Logs include trace IDs where available.

### Required log fields

```text
timestamp
level
service.name
deployment.environment
trace.id
span.id
correlation.id
message
exception.type
exception.message
```

### Example structured log

```json
{
  "timestamp": "2026-04-30T10:00:00Z",
  "level": "Warning",
  "service.name": "orders-api",
  "deployment.environment": "Development",
  "trace.id": "aabbcc123",
  "correlation.id": "REQ-123",
  "message": "Order processing exceeded expected duration",
  "durationMs": 2400
}
```

---

## Agent 5: Tracing Slice

### Responsibility

Implement distributed tracing with Tempo and Grafana.

### Scope

- Tempo configuration.
- Trace ingestion from OpenTelemetry Collector.
- Grafana Tempo datasource.
- Trace correlation with logs.
- Trace dashboard.

### Deliverables

- `tempo/tempo.yml`
- Tempo service in `docker-compose.yml`
- Grafana Tempo datasource configuration
- `grafana/dashboards/traces-overview.json`

### Acceptance Criteria

- Application traces appear in Grafana.
- Traces show incoming HTTP requests.
- Traces show outgoing HTTP calls.
- Traces show database calls where instrumentation exists.
- Logs can be correlated with traces using trace ID.

### Trace fields to standardize

```text
service.name
service.version
deployment.environment
http.method
http.route
http.status_code
db.system
db.statement
exception.type
exception.message
```

---

## Agent 6: Grafana Dashboard Slice

### Responsibility

Create ready-to-use dashboards for local development.

### Scope

- Grafana provisioning.
- Datasource setup.
- Dashboard provisioning.
- Dashboard JSON files.

### Deliverables

- `grafana/provisioning/datasources/datasources.yml`
- `grafana/provisioning/dashboards/dashboards.yml`
- `grafana/dashboards/dotnet-service-overview.json`
- `grafana/dashboards/container-health.json`
- `grafana/dashboards/system-health.json`
- `grafana/dashboards/logs-overview.json`
- `grafana/dashboards/traces-overview.json`

### Acceptance Criteria

- Grafana starts with all datasources already configured.
- Grafana starts with dashboards already imported.
- No manual dashboard setup is required.
- Dashboards work for any service using `service.name`.

### Required dashboards

#### Service Overview Dashboard

Must show:

```text
Request rate
Error rate
p95 latency
p99 latency
Top slow endpoints
Top failing endpoints
Recent error logs
Trace search by service
```

#### Logs Dashboard

Must show:

```text
Error logs by service
Warning logs by service
Logs by trace ID
Logs by correlation ID
Logs by request path
```

#### Traces Dashboard

Must show:

```text
Trace search by service
Slowest traces
Failed traces
Trace duration distribution
```

#### Container Health Dashboard

Must show:

```text
Container CPU
Container memory
Network usage
Restart count
Container status
```

#### System Health Dashboard

Must show:

```text
Host CPU
Host memory
Disk usage
Filesystem usage
Docker host pressure
```

---

## Agent 7: Alerting Slice

### Responsibility

Implement default alerting rules and alert routing.

### Scope

- Prometheus alert rules.
- Alertmanager configuration.
- Grafana alert visibility.
- Local notification routing.

### Deliverables

- `prometheus/alerts.yml`
- `alertmanager/alertmanager.yml`
- Alertmanager service in `docker-compose.yml`
- Documentation for alert thresholds

### Acceptance Criteria

- Prometheus loads alert rules.
- Alertmanager receives firing alerts.
- Alerts are grouped by service and severity.
- Alerts have useful descriptions and remediation hints.
- Alert thresholds are configurable.

### Default alert rules

#### High CPU Usage

```text
Condition: CPU usage above 80% for 5 minutes
Severity: warning
```

#### High Memory Usage

```text
Condition: memory usage above 85% for 5 minutes
Severity: warning
```

#### Low Disk Space

```text
Condition: disk usage above 85%
Severity: critical
```

#### Container Down

```text
Condition: container unavailable for 1 minute
Severity: critical
```

#### High HTTP Error Rate

```text
Condition: HTTP 5xx rate above 5% for 5 minutes
Severity: warning
```

#### Slow API Requests

```text
Condition: p95 request latency above 1 second for 5 minutes
Severity: warning
```

#### Application Unavailable

```text
Condition: health endpoint unavailable for 1 minute
Severity: critical
```

---

## Agent 8: Self-Healing Slice

### Responsibility

Implement safe local self-healing behavior.

### Scope

- Docker restart policies.
- Docker healthchecks.
- Optional watchdog script.
- Recovery commands.
- Safe failure handling.

### Deliverables

- Healthchecks in `docker-compose.yml`
- Restart policies in `docker-compose.yml`
- `scripts/restart.ps1`
- `scripts/health-check.ps1`
- `docs/troubleshooting.md`

### Acceptance Criteria

- Failed observability services restart automatically.
- Unhealthy containers are visible in Docker.
- Healthcheck script reports service status.
- Recovery script can restart the full platform safely.
- No script deletes data without explicit user action.

### Safe self-healing rules

Allowed:

```text
Restart unhealthy container
Restart observability stack
Report unhealthy dependency
Send alert
Show remediation guidance
```

Not allowed by default:

```text
Delete volumes automatically
Delete logs automatically
Kill unrelated processes
Modify application configuration automatically
Reset databases automatically
```

---

## Agent 9: .NET Integration Slice

### Responsibility

Create a reusable .NET integration pattern for new projects.

### Scope

- Shared observability extension methods.
- Appsettings configuration.
- OpenTelemetry tracing.
- OpenTelemetry metrics.
- Structured logging.
- Health checks.
- Correlation IDs.

### Deliverables

- Example reusable project: `Luhl.Observability`
- `AddProjectObservability(...)`
- `UseProjectObservability(...)`
- Example `Program.cs`
- Example `appsettings.Development.json`

### Acceptance Criteria

- New .NET project can enable observability with one service registration.
- New .NET project can configure service name from appsettings.
- Logs, metrics, and traces are sent to OpenTelemetry endpoint.
- Health endpoint is available.
- Trace ID is included in logs.

### Example appsettings

```json
{
  "Observability": {
    "ServiceName": "orders-api",
    "ServiceVersion": "1.0.0",
    "EnvironmentName": "Development",
    "OtlpEndpoint": "http://localhost:4317",
    "EnableTracing": true,
    "EnableMetrics": true,
    "EnableStructuredLogging": true,
    "EnableRuntimeInstrumentation": true,
    "EnableHttpClientInstrumentation": true,
    "EnableAspNetCoreInstrumentation": true
  }
}
```

### Example Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddProjectObservability(
    builder.Configuration,
    builder.Environment);

var app = builder.Build();

app.UseProjectObservability();

app.MapGet("/health", () => Results.Ok(new
{
    Status = "Healthy",
    Service = "orders-api"
}));

app.Run();
```

### Example extension method shape

```csharp
public static class ObservabilityServiceCollectionExtensions
{
    public static IServiceCollection AddProjectObservability(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment hostEnvironment)
    {
        ArgumentNullException.ThrowIfNull(services);
        ArgumentNullException.ThrowIfNull(configuration);
        ArgumentNullException.ThrowIfNull(hostEnvironment);

        // Configure structured logging, metrics, traces, and health checks here.

        return services;
    }
}
```

---

## Agent 10: Documentation and Developer Experience Slice

### Responsibility

Make the platform easy to use and easy to onboard into any new project.

### Scope

- README.
- Setup guide.
- New project onboarding guide.
- Troubleshooting guide.
- Common commands.
- Dashboard guide.

### Deliverables

- `README.md`
- `docs/onboarding-new-project.md`
- `docs/alerting-guide.md`
- `docs/troubleshooting.md`

### Acceptance Criteria

- A developer can start the stack from the README.
- A developer can onboard a new .NET project from the guide.
- A developer can verify logs, metrics, and traces.
- A developer can understand common alerts.
- A developer can recover from common local failures.

---

# 8. Vertical Slice Delivery Plan

## Slice 1: Platform Bootstrapping

### Outcome

The observability server starts successfully with Docker Compose.

### Includes

```text
Docker Compose
Shared network
Volumes
Grafana
Prometheus
Loki
Tempo
OpenTelemetry Collector
```

### Done when

```text
docker compose up -d
```

starts the platform and Grafana is reachable.

---

## Slice 2: Metrics End-to-End

### Outcome

System, container, and application metrics flow into Prometheus and Grafana.

### Includes

```text
Prometheus
cAdvisor
Node Exporter
Metrics dashboard
Basic metrics alerts
```

### Done when

A sample app sends metrics and they are visible in Grafana.

---

## Slice 3: Logs End-to-End

### Outcome

Structured logs flow from a sample app into Loki and Grafana.

### Includes

```text
Loki
OpenTelemetry logs pipeline
Log labels
Logs dashboard
Trace ID correlation
```

### Done when

A sample warning or error log appears in Grafana with service name and trace ID.

---

## Slice 4: Traces End-to-End

### Outcome

Distributed traces flow from a sample app into Tempo and Grafana.

### Includes

```text
Tempo
OpenTelemetry trace pipeline
Trace dashboard
Logs-to-traces correlation
```

### Done when

A sample HTTP request appears as a trace in Grafana.

---

## Slice 5: Application Integration Library

### Outcome

A .NET project can enable observability with minimal code.

### Includes

```text
AddProjectObservability
UseProjectObservability
ObservabilityOptions
Appsettings binding
Health checks
Correlation IDs
```

### Done when

A new .NET API can publish logs, metrics, and traces using only appsettings and one extension method.

---

## Slice 6: Alerting and Thresholds

### Outcome

The platform warns when system or application health is at risk.

### Includes

```text
Prometheus alert rules
Alertmanager
CPU alerts
Memory alerts
Disk alerts
Container down alerts
HTTP error rate alerts
Latency alerts
```

### Done when

A test alert fires and appears in Alertmanager.

---

## Slice 7: Safe Self-Healing

### Outcome

Common local failures recover safely or produce clear remediation instructions.

### Includes

```text
Docker restart policies
Healthchecks
Recovery scripts
Troubleshooting docs
```

### Done when

Stopping a service causes Docker to restart it or health scripts report the problem clearly.

---

## Slice 8: Developer Onboarding

### Outcome

A new project can be onboarded quickly and consistently.

### Includes

```text
README
New project guide
Example app
Common commands
Troubleshooting guide
```

### Done when

A new developer can run the platform and connect a sample app without manual Grafana configuration.

---

# 9. App Onboarding Standard

Every new project should follow the same onboarding contract.

## Required appsettings section

```json
{
  "Observability": {
    "ServiceName": "service-name-here",
    "ServiceVersion": "1.0.0",
    "EnvironmentName": "Development",
    "OtlpEndpoint": "http://localhost:4317"
  }
}
```

## Required Program.cs calls

```csharp
builder.Services.AddProjectObservability(
    builder.Configuration,
    builder.Environment);

var app = builder.Build();

app.UseProjectObservability();
```

## Required service naming convention

Use lower-case names separated by hyphens.

Examples:

```text
identity-api
orders-api
payments-api
catalog-api
warehouse-api
notification-worker
```

---

# 10. Alert Threshold Configuration

Use named thresholds instead of magic numbers.

Example configuration:

```json
{
  "ObservabilityThresholds": {
    "HighCpuPercentage": 80,
    "HighMemoryPercentage": 85,
    "LowDiskSpacePercentage": 85,
    "HighHttpErrorRatePercentage": 5,
    "SlowRequestP95Milliseconds": 1000,
    "SlowDatabaseP95Milliseconds": 500,
    "ContainerUnavailableSeconds": 60
  }
}
```

---

# 11. Testing Strategy

## Platform tests

```text
Verify Docker Compose starts successfully
Verify all containers are healthy
Verify expected ports are available
Verify Grafana datasources are provisioned
Verify Prometheus targets are up
```

## Metrics tests

```text
Send sample request to app
Verify request counter increases
Verify latency metric appears
Verify runtime metrics appear
```

## Logs tests

```text
Write information log
Write warning log
Write error log
Verify logs appear in Grafana
Verify logs contain service name
Verify logs contain trace ID where available
```

## Traces tests

```text
Send HTTP request to sample app
Verify trace appears in Grafana
Verify trace contains HTTP route
Verify trace links to logs
```

## Alert tests

```text
Trigger test alert
Verify Prometheus shows firing alert
Verify Alertmanager receives alert
Verify alert includes remediation text
```

## Self-healing tests

```text
Stop a container
Verify restart policy recovers it
Break a healthcheck
Verify unhealthy status is visible
Run recovery script
Verify platform returns to healthy state
```

---

# 12. Implementation Order

Recommended order:

```text
1. Create repository structure
2. Add Docker Compose shell
3. Add Grafana
4. Add Prometheus
5. Add Loki
6. Add Tempo
7. Add OpenTelemetry Collector
8. Add cAdvisor and Node Exporter
9. Add Grafana provisioning
10. Add default dashboards
11. Add Prometheus alerts
12. Add Alertmanager
13. Add Docker healthchecks
14. Add PowerShell scripts
15. Add .NET sample application
16. Add reusable .NET observability library
17. Add onboarding documentation
18. Add troubleshooting documentation
```

---

# 13. Definition of Done

The observability server is complete when:

```text
A developer can start the stack with one command.
A new .NET service can connect using appsettings and one Program.cs call.
Metrics are visible in Grafana.
Structured logs are visible in Grafana.
Traces are visible in Grafana.
Logs and traces can be correlated.
System health is visible.
Container health is visible.
Alerts fire when thresholds are crossed.
Common failures recover safely.
Dashboards and datasources are provisioned automatically.
No manual Grafana setup is required.
```

---

# 14. Suggested Agent Assignment Table

| Agent | Slice | Main Output |
|---|---|---|
| Agent 1 | Platform Orchestration | Docker Compose, scripts, network, volumes |
| Agent 2 | Telemetry Ingestion | OpenTelemetry Collector configuration |
| Agent 3 | Metrics | Prometheus, cAdvisor, Node Exporter, metrics alerts |
| Agent 4 | Logging | Loki, structured logs, log dashboard |
| Agent 5 | Tracing | Tempo, traces dashboard, correlation |
| Agent 6 | Dashboards | Grafana provisioning and dashboards |
| Agent 7 | Alerts | Alertmanager and alert rules |
| Agent 8 | Self-Healing | Healthchecks, restart policies, recovery scripts |
| Agent 9 | .NET Integration | Shared observability package and sample app |
| Agent 10 | Documentation | README, onboarding guide, troubleshooting guide |

---

# 15. Implementation Principle

Do not build this as one large task.

Build it as vertical slices where each slice proves one part of the system end-to-end.

The ideal sequence is:

```text
Start stack
Send telemetry
Store telemetry
View telemetry
Alert on telemetry
Recover safely
Repeat for new project
```

That keeps the implementation maintainable, testable, and easy to extend.

