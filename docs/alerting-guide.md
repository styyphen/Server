# Alerting Guide

Prometheus loads alert rules from `prometheus/alerts.yml` and sends firing alerts to Alertmanager.

## Default Alerts

- `ObservabilityTargetDown`: a scrape target is unavailable for 1 minute.
- `HighContainerMemoryUsage`: a container uses more than 85% of its memory limit for 5 minutes.
- `HighContainerCpuUsage`: container CPU usage is above 80% for 5 minutes.
- `LowDiskSpace`: host filesystem usage is above 85% for 5 minutes.
- `HighHttpErrorRate`: service HTTP 5xx rate is above 5% for 5 minutes.
- `ApplicationExceptions`: .NET runtime exceptions are increasing.
- `SlowApiRequests`: service p95 request latency is above 1 second for 5 minutes.
- `ApplicationTelemetryMissing`: no `/health` request metrics have been observed for 1 minute after the service previously emitted health telemetry.
- `ApplicationNetworkUnreachable`: active HTTP probing could not get any HTTP response from the configured health endpoint.
- `ApplicationServiceUnavailable`: active HTTP probing reached the endpoint, but it returned a non-healthy HTTP status.

## Local Routing

The default Alertmanager receiver is intentionally local-only. It groups alerts and exposes them in the Alertmanager UI at http://localhost:9093.

Add email, Slack, Teams, or webhook routing only after deciding how local alerts should leave the machine.

## Thresholds

Current defaults:

```text
Application exception rate: error
CPU: 80%
Memory: 85%
Disk usage: 85%
HTTP 5xx rate: 5% severity error
p95 request latency: 1 second
Scrape target unavailable: 60 seconds
```

Adjust thresholds in `prometheus/alerts.yml`.

Severity labels used by the default rules are:

```text
warning
error
critical
```

Alertmanager routes all three by default. A `critical` alert suppresses lower-severity `warning` and `error` alerts with the same alert name and job.

## Availability Cause Labels

Application availability alerts include:

```text
alert_category=application
failure_cause=network_unreachable
failure_cause=service_unavailable
failure_cause=telemetry_missing
```

`pending` and `firing` are Prometheus alert states. They do not describe the root cause. Use `failure_cause` for reporting.

## Active Health Probes

Active application health checks are powered by Blackbox Exporter. Configure targets in:

```text
prometheus/health-targets.yml
```

Example:

```yaml
- targets:
    - http://host.docker.internal:5000/health
  labels:
    service_name: dotnet-minimal-api
    deployment_environment: Local
```

Use `host.docker.internal` for applications running directly on the Windows host. Use a Docker service name for applications running on the same Docker network.
