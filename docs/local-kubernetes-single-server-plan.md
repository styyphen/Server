# Local Kubernetes Single-Server Implementation Plan

## 1. Purpose and constraints

This repository contains two related platforms:

1. A reusable observability platform. Applications send OpenTelemetry logs, metrics,
   and traces to one endpoint. Grafana, Prometheus, Loki, Tempo, and Alertmanager
   store, display, and alert on that telemetry.
2. A local development and delivery platform in `localCICD`. It provides Gitea,
   a CI runner, a container registry, AWS/Azure/GCP emulators, SonarQube, reusable
   pipelines, security gates, OpenTofu examples, and repository templates.

The target is one server, not a highly available production cluster. The design must:

- keep the core developer path available;
- prevent CI jobs and Java-based analysis from exhausting the host;
- start expensive optional capabilities only when requested;
- preserve repositories, registry images, and platform configuration;
- be reproducible from version-controlled manifests;
- leave enough capacity for application workloads and the operating system.

Kubernetes does not reduce the resource cost of the existing containers by itself.
The solution is strict resource governance, demand-based workloads, shorter data
retention, and avoiding duplicated components.

## 2. Recommended platform

Use a single-node **K3s** cluster on a dedicated Ubuntu Server LTS installation.
K3s is a better fit than a Docker-in-Docker `kind` or `k3d` cluster for a permanent,
resource-limited server because it avoids an extra containerized cluster layer.

Use the K3s defaults selectively:

- keep `containerd`, CoreDNS, local-path-provisioner, ServiceLB, and metrics-server;
- keep Traefik as the single ingress controller;
- do not install a second ingress controller or a full service mesh;
- use the embedded SQLite datastore for one node;
- use `local-path` persistent volumes initially;
- expose HTTP services through Traefik and expose the registry through one
  documented host port or TLS ingress;
- use one internal DNS suffix, such as `*.dev.home.arpa`.


## 3. Capacity gate

Before implementation, record physical cores, total RAM, free disk, disk type, and
idle consumption. Run the Compose stacks separately and record peak and steady-state
CPU/RAM for each service. Use these gates:

| Host capacity | Supported mode |
|---|---|
| Less than 4 cores or 8 GiB RAM | Not recommended. Run only the core platform and use local CLI scans. |
| 4 cores / 8 GiB RAM | Core platform plus observability; all analysis and emulators strictly on demand, one CI job at a time. |
| 6-8 cores / 16 GiB RAM | Recommended; core and observability always on, one optional heavy profile at a time. |
| 8+ cores / 24+ GiB RAM | Comfortable; limited concurrency is possible after measurements. |

Keep at least 20% of RAM, 20% of CPU, and 20% of disk unallocated. Kubernetes
requests must fit below 80% of allocatable node resources. Set kubelet eviction
thresholds and reserve resources for the OS and Kubernetes daemons.

## 4. Workload classes

### Always-on core

- Gitea, using its existing SQLite database for the initial single-user/small-team
  installation;
- registry;
- OpenTelemetry Collector;
- Grafana;
- Prometheus;
- Loki;
- Tempo;
- Alertmanager;
- node and Kubernetes metrics.

### Event-driven

- one Gitea Actions runner;
- CI job pods;
- builds, tests, lint, OpenTofu validation, Trivy, Gitleaks, Syft, Checkov,
  Conftest, commitlint, and changelog generation.

The runner must have `capacity: 1`, not the current value of 2. Prefer ephemeral
Kubernetes job containers with per-job requests, limits, deadlines, and cleanup.
Do not mount the host Docker socket. Build images rootlessly with BuildKit or
Kaniko and push directly to the local registry. Cache dependencies on a bounded
PVC.

### On-demand platform add-ons

- LocalStack;
- Azurite;
- fake-gcs-server;
- SonarQube and its PostgreSQL database.

These deploy with replica count zero by default. A script scales up exactly the
requested add-on, waits for readiness, runs the related test or analysis, then
scales it back to zero. Use a `ResourceQuota` so only one heavy add-on can run
alongside one CI job on an 8 GiB host.

Where possible, run Sonar analysis as a scheduled or manually triggered batch
activity rather than on every commit. Cheap gates run first and cancel the pipeline
before SonarQube or image builds start.

## 5. Initial resource budget

These are starting limits, not guarantees. Validate them with real workloads and
adjust requests from observed p95 use.

| Workload | CPU request / limit | Memory request / limit |
|---|---:|---:|
| K3s system allowance | 500m / reserved | 750 Mi / reserved |
| Gitea | 100m / 500m | 256 Mi / 512 Mi |
| Registry | 50m / 300m | 64 Mi / 256 Mi |
| Grafana | 50m / 300m | 128 Mi / 384 Mi |
| Prometheus | 150m / 750m | 384 Mi / 768 Mi |
| Loki | 100m / 500m | 256 Mi / 512 Mi |
| Tempo | 100m / 500m | 256 Mi / 512 Mi |
| OTel Collector | 50m / 300m | 128 Mi / 256 Mi |
| Alertmanager | 25m / 100m | 32 Mi / 128 Mi |
| node/kube metrics | 100m / 400m | 160 Mi / 384 Mi |
| Gitea runner idle | 25m / 200m | 64 Mi / 192 Mi |
| One ordinary CI job | 250m / 1500m | 512 Mi / 2 Gi |
| LocalStack, on demand | 100m / 1000m | 256 Mi / 1 Gi |
| Azurite, on demand | 25m / 300m | 64 Mi / 256 Mi |
| fake-gcs, on demand | 25m / 300m | 64 Mi / 256 Mi |
| SonarQube + PostgreSQL, on demand | 500m / 2000m | 2.5 Gi / 4 Gi |

The always-on application requests total roughly 1.25 CPU and 2.7 GiB RAM,
including the K3s allowance but excluding application workloads. Limits are
ceilings, not capacity reservations. Avoid low CPU limits on latency-sensitive
services if testing shows throttling; retain memory limits to prevent node-wide
out-of-memory failures.

## 6. Kubernetes repository layout

Add the following structure:

```text
k8s/
|-- base/
|   |-- namespaces/
|   |-- platform/
|   |   |-- gitea/
|   |   `-- registry/
|   |-- observability/
|   |   |-- otel-collector/
|   |   |-- grafana/
|   |   |-- prometheus/
|   |   |-- loki/
|   |   |-- tempo/
|   |   `-- alertmanager/
|   `-- policies/
|-- addons/
|   |-- localstack/
|   |-- azurite/
|   |-- fake-gcs/
|   `-- sonarqube/
|-- overlays/
|   `-- single-server/
|-- scripts/
|   |-- bootstrap.ps1
|   |-- deploy.ps1
|   |-- addon.ps1
|   |-- health-check.ps1
|   |-- backup.ps1
|   `-- restore.ps1
`-- README.md
```

Use Kustomize for repository-owned manifests and Helm only for well-maintained
upstream applications where it materially reduces maintenance. Pin every chart
version and image by immutable version (preferably digest). Never use `latest`,
which is currently the default for several `localCICD` images.

Use separate namespaces:

- `platform-system` for Gitea, registry, and runner;
- `observability` for telemetry;
- `cloud-emulators` for optional emulators;
- `ci-jobs` for short-lived CI workloads;
- one namespace per deployed application or project.

Apply `ResourceQuota`, `LimitRange`, and default-deny `NetworkPolicy` to every
workload namespace.

## 7. Component mapping and changes

| Current component | Kubernetes implementation |
|---|---|
| Gitea | StatefulSet, one replica, PVC, ClusterIP, Ingress, PodDisruptionBudget omitted on one node |
| Gitea runner | One runner controller/pod with concurrency one; isolated `ci-jobs` namespace |
| Registry v2 | Deployment with PVC, garbage collection maintenance job, authenticated TLS endpoint |
| Grafana | Deployment, PVC, provisioned ConfigMaps/Secrets, Ingress |
| Prometheus | StatefulSet, PVC, 15-30 day or size-based retention, Kubernetes service discovery |
| Loki | Single-binary StatefulSet, filesystem PVC, 3-7 day retention on an 8 GiB host |
| Tempo | Single-binary StatefulSet, filesystem PVC, 24-hour retention initially |
| OTel Collector | One gateway Deployment; OTLP exposed internally and through a controlled endpoint |
| Alertmanager | One-replica StatefulSet/Deployment with PVC |
| cAdvisor | Remove; kubelet already exposes container metrics |
| Node Exporter | DaemonSet with one pod on the single node |
| Docker Compose healthchecks | Startup, readiness, and liveness probes |
| LocalStack/Azurite/fake-gcs | Deployments scaled to zero by default, individual PVCs |
| SonarQube/PostgreSQL | On-demand StatefulSets, bounded JVM heap and PostgreSQL memory |

Prometheus should scrape kube-state-metrics, kubelet/cAdvisor endpoints, node
exporter, platform services, and application `ServiceMonitor`-equivalent targets.
Do not run the existing standalone cAdvisor container.

## 8. Storage and retention

Use separate PVCs so a full telemetry disk cannot corrupt Gitea or registry data.
Start with:

- Gitea: 10 Gi;
- registry: 20 Gi with scheduled untagged-image cleanup;
- Prometheus: 10 Gi with both time and size retention;
- Loki: 10 Gi with 3-7 day retention;
- Tempo: 5 Gi with 24-hour retention;
- Grafana/Alertmanager: 1 Gi each;
- runner cache: 5 Gi with scheduled cleanup;
- optional emulators and SonarQube: separate, bounded PVCs.

Back up Gitea repositories/database/configuration and registry data to a second
physical disk or remote target. Telemetry is disposable by default and need not be
backed up. Run and verify a restore quarterly. A local-path PVC on the same disk is
not a backup.

Set storage alerts at 70%, 80%, and 90%. At 80%, prune CI caches and registry
artifacts; at 90%, stop new CI jobs before the node disk fills.

## 9. Security and reliability baseline

- Put credentials and runner registration tokens in Kubernetes Secrets generated
  outside Git; replace the hard-coded Gitea secrets currently in `app.ini`.
- Bootstrap sealed/encrypted secret handling before committing any real values.
- Use TLS at Traefik, authentication on Gitea, Grafana, registry, and SonarQube,
  and do not expose Prometheus/Loki/Tempo directly outside the host.
- Use non-root containers, read-only root filesystems, dropped Linux capabilities,
  `seccompProfile: RuntimeDefault`, and no privilege escalation where supported.
- Never expose or mount `/var/run/docker.sock` into the runner or LocalStack.
- Use dedicated service accounts and least-privilege RBAC. The CI runner may create
  Jobs only in `ci-jobs`; it must not administer the cluster.
- Use readiness and startup probes; use liveness probes only when restart is a safe
  recovery.
- Set `terminationGracePeriodSeconds`, job `activeDeadlineSeconds`,
  `backoffLimit`, and `ttlSecondsAfterFinished`.
- Use topology spread, replica anti-affinity, or multi-replica databases only after
  adding nodes; they provide no availability benefit on one node.
- Pin images and automate controlled update pull requests. Scan the pinned images.

## 10. Delivery phases

### Phase 0: Measure and safeguard

1. Inventory the server and capture per-container steady/peak utilization.
2. Back up all existing named volumes and test that Gitea can be restored.
3. Define DNS names, TLS approach, storage paths, and the server capacity tier.
4. Establish acceptance thresholds: no swapping during a normal CI run, less than
   80% sustained RAM, less than 80% disk, and a responsive Gitea/Grafana UI.

Exit: capacity and recovery reports are committed without secrets.

### Phase 1: Bootstrap the single node

1. Install and harden Ubuntu and K3s.
2. Configure OS/kubelet reservations, eviction thresholds, time sync, firewall,
   storage classes, and Traefik.
3. Create namespaces, quotas, limit ranges, network policies, and secret workflow.
4. Add idempotent bootstrap, validation, and uninstall documentation.

Exit: a reboot returns a healthy cluster and no workload can run without resource
defaults.

### Phase 2: Migrate core development services

1. Deploy pinned Gitea and registry workloads.
2. Restore copied data into new PVCs; keep Compose volumes untouched for rollback.
3. Configure ingress/TLS, authentication, backup, and registry cleanup.
4. Validate clone, push, pull request, image push/pull, reboot, backup, and restore.

Exit: the repository-to-registry workflow works without the cloud emulators.

### Phase 3: Migrate and slim observability

1. Deploy the OTel gateway and single-binary telemetry stores.
2. Convert configuration files to ConfigMaps and secrets.
3. replace standalone cAdvisor with kubelet metrics and add kube-state-metrics.
4. Apply retention and storage limits; import existing Grafana provisioning.
5. instrument K3s, Gitea, registry, runner, and application namespaces.

Exit: sample logs, metrics, and traces flow end-to-end and resource/disk alerts fire
in a controlled test.

### Phase 4: Safe CI execution

1. Change runner capacity from two to one.
2. Replace Docker-socket builds with rootless BuildKit/Kaniko jobs.
3. Apply CI namespace quota, job defaults, cache bounds, deadlines, and cleanup.
4. Execute cheap checks before heavy analysis and cancel superseded branch builds.
5. Publish test, coverage, scan, SBOM, and image artifacts to bounded storage.

Exit: a representative pipeline completes while the core platform remains within
the capacity thresholds.

### Phase 5: On-demand emulators and analysis

1. Package each emulator as an independent add-on scaled to zero.
2. Add `addon.ps1 start|stop|status <name>` with readiness checks.
3. Deploy SonarQube/PostgreSQL with fixed JVM/database limits and a mutual-exclusion
   policy for other heavy add-ons on small hosts.
4. Update pipeline templates to request only the services a repository declares.

Exit: each emulator and SonarQube passes an isolated acceptance test and reliably
returns to zero replicas.

### Phase 6: Templates, operations, and cutover

1. Update all repository templates from Compose deployment to Kubernetes overlays
   while retaining local developer commands.
2. Add application requests/limits, probes, Pod Security settings, OTLP endpoint,
   and NetworkPolicy to every template.
3. Create daily health/backup jobs and monthly restore/update exercises.
4. Run a 7-day soak including sequential pipelines and disk-pressure tests.
5. Stop Compose only after acceptance; retain its volumes for a documented rollback
   period, then remove them only with explicit approval.

Exit: all definition-of-done workflows pass on one node after reboot and during a
full representative CI run.

## 11. Validation matrix

Validate every phase with repeatable scripts:

- cluster: node ready, system pods healthy, quotas and default-deny policies active;
- source: clone, push, PR, merge, and persistent data after reboot;
- CI: failed test blocks merge; successful run emits artifacts; only one job runs;
- registry: authenticated push/pull and deployment by immutable digest;
- observability: sample metric, log, trace, alert, and cross-correlation;
- cloud: S3/SQS/DynamoDB, Blob/Queue/Table, and GCS read/write tests independently;
- IaC/security: format, validate, policy, secret, dependency, image, and SBOM gates;
- operations: backup/restore, certificate renewal, disk pruning, and node reboot;
- capacity: normal and worst representative workflows remain below thresholds and
  core UIs stay responsive.

## 12. Rollback

Migrate data by copy, not by moving the original volumes. During each service
cutover:

1. stop writes briefly;
2. take a final backup;
3. restore into its PVC;
4. change DNS/ports;
5. validate;
6. revert DNS/ports and restart Compose if validation fails.

Do not run the old and new stateful service against the same data directory. Keep
the Compose definitions and original volumes unchanged until the soak period and
restore test pass.

## 13. Key decisions

- Optimize for a reliable single-node development appliance, not false high
  availability.
- Keep Gitea, the registry, and a slim observability path always available.
- Run only one CI job and one heavy optional capability at a time on small hosts.
- Scale cloud emulators and SonarQube to zero when idle.
- Remove duplicated cAdvisor and Docker-socket access.
- Enforce requests, memory limits, quotas, retention, cache cleanup, and disk alerts
  from the first deployment.
- Measure before increasing concurrency or retention.
