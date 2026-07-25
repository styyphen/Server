# Phase H3 Resilience Acceptance

Completed 2026-07-25.

## Result

H3 passed. The platform recovered from a controlled VM reboot, asserted and
recovered from a bounded disk-pressure test, completed the representative CI
pipeline and every optional add-on sequentially, verified a fresh logical
backup, and preserved the host and guest capacity gates.

## Evidence

- Controlled reboot:
  - Hyper-V reported the VM running normally after restart.
  - The node and all controller-managed workloads converged in 104.4 seconds.
  - The first strict probe correctly observed Running pods still inside their
    readiness delays; the final probe reported no unhealthy workloads.
  - Report: `D:\HyperV\operations\h3-reboot-recovery.json`.
- Disk pressure:
  - The test temporarily changed only the backed-up kubelet soft disk threshold
    from 15% to 91% free, with the hard 10% threshold unchanged. This exercised
    kubelet behavior without consuming approximately 118 GiB or expanding the
    dynamic VHD.
  - Kubernetes asserted `DiskPressure` and evicted the disposable BestEffort
    pod with reason `Evicted`.
  - The runner, Loki, and Registry BestEffort replicas were also evicted and
    recreated by their controllers. Only confirmed Evicted terminal records
    were removed.
  - The exact K3s configuration was restored, `DiskPressure` cleared, and full
    health passed.
  - Report: `D:\HyperV\operations\h3-disk-pressure.json`.
- Representative CI:
  - Cheap checks, socketless image build/push, Trivy scan, SBOM generation, and
    artifact output passed through the capacity-one runner.
- Optional services:
  - Azurite, fake GCS, LocalStack, and SonarQube/PostgreSQL passed sequentially.
  - Every service returned to zero replicas.
  - Report:
    `D:\HyperV\operations\addons\phase-g-20260725T131123Z.json`.
- Backup and restore:
  - Fresh backup:
    `D:\server-backups\platform\daily-20260725T130245Z`.
  - SHA-256 verification and isolated extraction passed for four artifacts and
    229 exported Kubernetes objects.
- Final capacity:
  - Windows free memory: 4.37 GiB, above the 4 GiB gate.
  - Node filesystem free: 90.83%, above the 15% gate.
  - Final health report:
    `D:\HyperV\operations\health\health-20260725T131501Z.json`.

## Operational findings

- Do not treat `$LASTEXITCODE` as the result of a PowerShell script; it may
  contain the exit code of an earlier native command. Use `$?`, exceptions, or
  an explicit result object.
- Reboot acceptance must wait for workload readiness after node readiness.
- Disk-pressure recovery should remove only terminal pods whose reason is
  explicitly `Evicted`; controller-managed replacements must be allowed to
  converge before the final health gate.
- Optional services remain sequential. SonarQube was the peak memory case and
  preserved 4.61 GiB of Windows free memory during acceptance.

## Next gate

H4 is next: run the seven-day representative soak, review alerts, storage
growth, restarts, and backup results, then request explicit approval before DNS
cutover or retirement of any rollback asset.
