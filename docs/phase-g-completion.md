# Phase G completion

Completed 2026-07-25.

## Delivered

- Common `start`, `stop`, `status`, `test`, and `accept` lifecycle with
  structured events, timeouts, fail-fast scheduling/startup diagnostics,
  mutual exclusion, and guaranteed return to zero.
- Azurite `3.35.0`, fake-gcs-server `1.54.0`, socketless LocalStack `3.8.1`,
  SonarQube `10.7-community`, and PostgreSQL `16.10-alpine`.
- Explicit requests/limits, bounded PVCs and temporary storage, startup/
  readiness/liveness probes, Restricted Pod Security settings, and
  default-deny-aware NetworkPolicies.
- Repository declarations under `.platform/addons.yaml`; all templates deny
  optional services by default.
- Sequential acceptance automation with live platform health and capacity
  checks while each add-on is active.

## Exit evidence

Successful report:

```text
D:\HyperV\operations\addons\phase-g-20260725T125130Z.json
```

| Add-on | API acceptance | Guest CPU | Guest memory |
|---|---|---:|---:|
| Azurite | Blob endpoint | 4% | 61% |
| fake GCS | Bucket create/list | 4% | 62% |
| LocalStack | Health and S3 loaded | 7% | 61% |
| SonarQube/PostgreSQL | System API UP | 23% | 97% |

Every platform health run passed. Windows free memory remained at or above
4.22 GiB, node filesystem remained 90.88% free, and no core workload became
unavailable. SonarQube briefly reached 97% of Kubernetes allocatable memory
during startup, but the node stayed Ready without MemoryPressure or eviction.
It must remain mutually exclusive with other add-ons and CI jobs.

All five add-on workloads finished with desired replicas `0` and Ready
replicas `0`.

## Operation

```powershell
./k8s/operations/manage-addon.ps1 -Name azurite -Action accept
./k8s/operations/manage-addon.ps1 -Name fake-gcs -Action accept
./k8s/operations/manage-addon.ps1 -Name localstack -Action accept
./k8s/operations/manage-addon.ps1 -Name sonarqube -Action accept

./k8s/operations/invoke-phase-g-acceptance.ps1
```

The external `sonarqube-database` Secret is required in `cloud-emulators`.
Its generated source credential is stored outside Git under
`D:\HyperV\credentials`.
