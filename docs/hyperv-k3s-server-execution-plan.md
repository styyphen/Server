# Hyper-V K3s Development Server Execution Plan

## Objective

Build a reliable local self-hosted development server with Git hosting, pull
requests, CI/CD, a container registry, Kubernetes application deployment,
observability, cloud emulators, infrastructure validation, security scanning,
and release automation.

The permanent runtime is the `local-k3s-server` Hyper-V Ubuntu VM stored on
`D:`. WSL is tooling and rollback only. Docker Desktop is not part of the
always-on server path.

## Safety rules

- Do not advance a phase until all exit criteria pass.
- Preserve the WSL cluster, Docker data backup, source cloud images, and failed
  VM disks until the final soak and restore tests pass.
- Never delete or overwrite an existing VM, VHD, PVC, or backup implicitly.
- Back up before every stateful migration.
- Pin K3s, application images, and third-party dependencies.
- Generate credentials outside Git and store runtime credentials in Kubernetes
  Secrets.
- Validate manifests locally and server-side before applying them.
- Run one CI job and at most one heavy optional add-on at a time.
- Keep Docker Desktop and WSL stopped while the Hyper-V server is running,
  unless a capacity test explicitly proves coexistence safe.

## Phase A: stabilize Hyper-V

1. Create a dedicated internal Hyper-V switch and NAT network.
2. Assign the host gateway `192.168.50.1/24`.
3. Assign the VM `192.168.50.10/24`.
4. Configure controlled dynamic memory at 5–8 GiB with a 5-GiB startup
   allocation so Windows retains its 4-GiB safety reserve. Optional heavy
   services remain sequential and scale to zero.
5. Configure DNS, time synchronization, firewall, and hostname.
6. Verify automatic startup and graceful shutdown.
7. Verify SSH after three controlled VM restarts.
8. Measure Windows and guest memory, CPU, and disk headroom.

Exit:

- `developer@192.168.50.10` accepts only key-based SSH.
- SSH survives three VM restarts.
- The VM has outbound DNS and HTTPS connectivity.
- Windows retains at least 4 GiB available RAM.
- Guest RAM and disk remain below 80%.

## Phase B: recovery baseline

1. Shut down the VM cleanly.
2. Copy its active VHDX to `D:\server-backups\hyperv`.
3. Record SHA-256 hashes and VM configuration.
4. Restore the copy as an isolated temporary VM.
5. Verify SSH and filesystem integrity, then remove only the temporary VM
   registration while preserving the backup.

Exit: a documented cold restore boots and accepts SSH without changing the
primary VM.

## Phase C: K3s baseline

1. Install pinned K3s using `k8s/config/k3s-config.yaml`.
2. Enable encrypted Secrets and OS/Kubernetes resource reservations.
3. Apply namespaces, quotas, limits, Pod Security, and default-deny policies.
4. Configure Traefik, local-path storage, and restricted remote kubeconfig.
5. Reboot and validate node, system pods, storage, DNS, ingress, and metrics.

Exit: one healthy node returns automatically after reboot, and all workload
namespaces enforce resource defaults and network isolation.

## Phase D: source and registry

1. Deploy pinned Gitea and Registry workloads.
2. Use separate bounded PVCs.
3. Configure TLS, authentication, backup, and registry cleanup.
4. Create the bootstrap administrator outside Git.
5. Validate clone, push, pull request, image push/pull, reboot, backup, and
   restore.

Exit: the repository-to-registry workflow works without optional emulators.

## Phase E: observability

1. Deploy OpenTelemetry Collector, Grafana, Prometheus, Loki, Tempo, and
   Alertmanager.
2. Apply bounded retention and independent PVCs.
3. Collect K3s, node, Gitea, registry, CI, and application telemetry.
4. Validate sample metrics, logs, traces, correlations, and controlled alerts.

Exit: end-to-end telemetry and storage/resource alerts pass.

## Phase F: safe CI/CD

1. Deploy one Gitea Actions runner with capacity one.
2. Use isolated Kubernetes jobs with requests, limits, deadlines, and cleanup.
3. Build images without mounting the Docker socket.
4. Order cheap checks before builds and analysis.
5. Publish test, coverage, scan, SBOM, and image artifacts to bounded storage.

Exit: a representative pipeline completes without degrading Gitea or
observability.

## Phase G: optional development services

1. Package LocalStack, Azurite, fake GCS, and SonarQube/PostgreSQL separately.
2. Keep replicas at zero by default.
3. Add start, stop, status, readiness, and acceptance-test automation.
4. Enforce one heavy add-on at a time.

Exit: every add-on passes its isolated test and reliably returns to zero.

## Phase H: operations and cutover

1. Update repository templates and onboarding scripts.
2. Add scheduled health, backup, cleanup, and restore exercises.
3. Run reboot, disk-pressure, sequential-pipeline, and seven-day soak tests.
4. Cut over stable DNS only after all definition-of-done workflows pass.
5. Retire rollback assets only with explicit approval.

Exit: all workflows pass after reboot and during a representative full
development cycle.

## Execution status

Updated 2026-07-24:

- Phase A passed: fixed Hyper-V networking, key-only SSH, firewall, controlled
  dynamic memory, three restart tests, and host/guest capacity gates.
- Phase B passed: the cold VHDX backup at
  `D:\server-backups\hyperv\baseline-20260723` was hash-verified and boot-tested
  as an isolated restore.
- Phase C passed: K3s `v1.36.1+k3s1` and Windows kubectl `v1.36.1` passed API,
  node, system workload, reboot recovery, DNS, local-path PVC, Traefik ingress,
  and metrics tests.
- Phase D passed: authenticated Gitea Git/PR and Registry image workflows,
  full-VM reboot persistence, and isolated logical backup/restore tests passed.
  The backup is at `D:\server-backups\platform\phase-d-20260723`.
- Phase E is in progress. The controlled Windows restart resolved the preflight
  capacity blocker. E1 (Prometheus, Alertmanager, and node-exporter) is deployed:
  all seven configured scrape targets, a controlled alert, bounded PVCs, pod
  readiness, and the post-deployment host/guest capacity gates passed. Resume
  with E2 (Grafana) in `docs/phase-e-continuation-plan.md`.
