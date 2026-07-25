# Phase E Continuation Plan

This is the restart point for continuing development of the D: Hyper-V/K3s
server. Read it together with:

- `docs/current-server-state.md`
- `docs/hyperv-k3s-server-execution-plan.md`
- `docs/local-kubernetes-single-server-plan.md`

## Current checkpoint

Captured 2026-07-24 in the Africa/Johannesburg timezone.

- Git branch: `master`
- Last completed server-state commit: `7de4b57`
- Completed phases: A through D
- Active VM: `local-k3s-server`
- VM address: `192.168.50.10`
- K3s: `v1.36.1+k3s1`
- Node: Ready
- Gitea and Registry: Running and persistent
- Phase D backups: present and previously restore-tested
- Phase E E1 workloads: deployed and verified

The live server is healthy. The pre-deployment capacity gate passed after the
controlled Windows restart, and E1 is complete. Resume with E2 (Grafana).

## Resolved pre-deployment blocker

The plan requires Windows to retain at least 4 GiB of available memory.
Measurement on 2026-07-24 showed:

| Measurement | Value |
|---|---:|
| Windows available memory | 2.34 GiB |
| VM assigned memory | 5 GiB |
| VM memory demand | 2.55 GiB |
| Guest available memory | approximately 3.5 GiB |
| Largest avoidable host consumer | Desktop Window Manager, approximately 1.28 GiB |

WSL and Docker Desktop remain stopped. A controlled Windows restart completed on
2026-07-24 and also validated Hyper-V automatic VM startup.

Post-restart validation:

| Measurement | Value |
|---|---:|
| Windows available memory before E1 | 6.096, 6.113, 6.111 GiB |
| Windows available memory after E1 | 5.966, 5.972, 5.972 GiB |
| VM assigned memory | 5 GiB |
| VM memory demand before E1 | 2.6 GiB |
| Guest memory after E1 | 2,454 MiB (67%) |
| Guest available memory after E1 | 3.1 GiB |
| Guest root disk after E1 | 3% used |

## Resume procedure

1. Restart Windows. Do not manually start Docker Desktop or WSL.
2. Wait for Hyper-V automatic startup.
3. Confirm SSH:

   ```powershell
   ssh -i D:\HyperV\credentials\k3s-server-ed25519 developer@192.168.50.10 true
   ```

4. Confirm Kubernetes:

   ```powershell
   $kubectl = 'D:\HyperV\tools\kubectl-v1.36.1.exe'
   $config = 'D:\HyperV\credentials\k3s-admin.yaml'
   & $kubectl --kubeconfig $config get nodes
   & $kubectl --kubeconfig $config get pods -A
   & $kubectl --kubeconfig $config top node
   ```

5. Run the elevated Hyper-V capacity inspection:

   ```powershell
   $script = 'C:\Server\k8s\hyperv\inspect-capacity.ps1'
   $result = 'D:\HyperV\capacity-inspection.json'
   $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script`" " +
       "-VmName local-k3s-server -ResultPath `"$result`""
   Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList $arguments
   Get-Content $result
   ```

6. Measure Windows memory at least three times over 30 seconds:

   ```powershell
   1..3 | ForEach-Object {
       Start-Sleep -Seconds 10
       $os = Get-CimInstance Win32_OperatingSystem
       [math]::Round($os.FreePhysicalMemory / 1MB, 3)
   }
   ```

Exit gate: every settled Windows sample is at least 4 GiB, the node is Ready,
and every non-completed pod is Ready without new crash loops.

Status: passed on 2026-07-24.

If the reserve still fails after restart, do not lower the VM below 5 GiB and do
not weaken the 4-GiB host gate. Reassess host processes or increase physical
RAM before deploying observability.

## Phase E design constraints

The Kubernetes observability deployment must be a new
`k8s/base/observability` package included by a Phase E/current overlay. The
existing root-level Docker Compose observability files are reference material,
not the active server runtime.

Use these rules:

- Pin every container image to an explicit version.
- Use one replica per component.
- Use monolithic/single-binary Loki and Tempo with local filesystem storage.
- Set requests, limits, probes, Pod Security settings, and NetworkPolicies on
  every workload.
- Store Grafana credentials in a Secret generated outside Git.
- Use separate bounded PVCs.
- Keep total Phase E memory requests at or below 1.5 GiB.
- Keep total Phase E memory limits at or below 2.5 GiB.
- Keep retention deliberately short for this single development server.
- Deploy one increment at a time and remeasure Windows and guest memory after
  each increment.

## Rollout order and gates

### E1: Prometheus and Alertmanager

1. Add pinned manifests and bounded PVCs.
2. Scrape K3s, node, Gitea, Registry, and observability components.
3. Configure at least node unavailable, memory pressure, and storage pressure
   alerts.
4. Deploy and wait for readiness.
5. Verify Prometheus targets and send a controlled test alert.
6. Recheck the 4-GiB Windows reserve and guest headroom.

Rollback: scale both deployments to zero or remove only the E1 objects. Preserve
their PVCs unless explicit deletion is approved.

Status: completed and verified on 2026-07-24.

- Prometheus, Alertmanager, and node-exporter are Ready.
- Prometheus scrapes itself, Alertmanager, the K3s API, kubelet, node-exporter,
  Gitea, and Registry; all seven targets were healthy.
- Node unavailable, memory pressure, and storage pressure rules are loaded.
- A short-lived controlled alert was accepted and visible in Alertmanager.
- Prometheus and Alertmanager PVCs are Bound.
- E1 requests are 480 MiB and limits are 1,024 MiB.
- The post-E1 host and guest capacity gates passed.

### E2: Grafana

Status: next increment; not deployed.

1. Generate the administrator credential outside Git.
2. Provision Prometheus, Loki, and Tempo data sources declaratively.
3. Expose Grafana through Traefik using the existing private CA model.
4. Verify authenticated login, Prometheus queries, and dashboard persistence.
5. Recheck capacity.

Rollback: scale Grafana to zero and preserve its PVC.

### E3: Loki and log collection

1. Deploy single-binary Loki with filesystem storage and short retention.
2. Deploy a resource-bounded collector for Kubernetes pod logs.
3. Verify logs from K3s, Gitea, Registry, and a test pod.
4. Verify queries through both Loki API and Grafana.
5. Recheck capacity.

Rollback: stop the collector first, then scale Loki to zero; preserve its PVC.

### E4: Tempo and OpenTelemetry Collector

1. Deploy single-binary Tempo with local storage.
2. Deploy the OpenTelemetry Collector on ports 4317 and 4318.
3. Route traces to Tempo, metrics to Prometheus, and logs to Loki.
4. Generate controlled sample telemetry.
5. Verify metrics, logs, traces, and trace/log correlation.
6. Recheck capacity.

Rollback: stop the Collector first, then scale Tempo to zero; preserve its PVC.

## Phase E completion gate

Before marking Phase E complete:

- Reboot the full VM and verify automatic recovery.
- Confirm all Prometheus targets are healthy.
- Confirm controlled alert delivery.
- Confirm Grafana authentication and persistent dashboards.
- Confirm sample metrics, logs, and traces.
- Confirm all observability PVCs are Bound and below alert thresholds.
- Confirm Windows retains at least 4 GiB available memory.
- Confirm guest memory and disk remain below 80%.
- Create and restore-test logical observability backups under
  `D:\server-backups\observability`.
- Update `docs/current-server-state.md` and the main execution plan.
- Run manifest, syntax, whitespace, and secret scans.
- Commit the completed Phase E state to `master`.

## Safety reminders

- Do not delete Phase B or Phase D backups.
- Do not delete or recreate existing Gitea/Registry PVCs.
- Do not commit D: credentials, kubeconfigs, certificates, keys, VHDX files, or
  backup archives.
- Do not run Docker Desktop or WSL alongside the server without a new capacity
  test.
- Do not advance to CI/CD until every Phase E exit gate passes.
