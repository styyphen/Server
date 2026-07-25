# Phase H2 operations runbook

## Installed schedules

All Windows tasks run as `SYSTEM`, use the external kubeconfig, and keep
credentials and reports outside Git.

| Task | Schedule | Output |
|---|---|---|
| `Server-Platform-Daily-Backup` | Daily 02:00 | `D:\server-backups\platform\daily-*` |
| `Server-Platform-Daily-Health` | Daily 06:00 | `D:\HyperV\operations\health` |
| `Server-Platform-Weekly-Registry-Maintenance` | Sunday 04:00 | `D:\HyperV\operations\registry` |
| `ci-artifact-retention` | Daily 03:30 (Kubernetes CronJob) | Kubernetes Job logs |
| `Server-Platform-H4-Daily-Soak` | Daily 07:00, during H4 | `D:\HyperV\operations\h4-soak` |

Daily backups retain at most 14 successful backup directories and no more than
14 days. They contain Gitea, Registry, Grafana, cluster objects, SHA-256
checksums, and Kubernetes Secret data. Keep the backup disk and its ACLs
administratively restricted.

CI artifact directories older than 14 days are removed. Weekly Registry
maintenance refuses to start unless the newest successful backup is less than
26 hours old. It stops Registry, removes untagged manifests and unreachable
blobs, then restores the prior replica count even on failure. Tagged images are
not removed automatically.

## Routine checks

```powershell
Get-ScheduledTask -TaskName 'Server-Platform-*'
Get-ScheduledTaskInfo -TaskName 'Server-Platform-Daily-Health'
Get-Content -Raw D:\HyperV\operations\health\latest.json

Get-ChildItem D:\server-backups\platform\daily-* -Directory
./k8s/operations/test-platform-backup.ps1

kubectl -n ci-jobs get cronjob/ci-artifact-retention
kubectl -n ci-jobs get jobs --sort-by=.metadata.creationTimestamp
```

Any non-zero scheduled-task result, failed structured report, missed schedule,
or failed CronJob is an operational incident. Fix the cause before manually
rerunning cleanup.

## Monthly restore rehearsal

1. Run `test-platform-backup.ps1` against the newest daily backup.
2. Create an isolated restore directory or isolated test VM. Never restore over
   a live PVC.
3. Extract `gitea.tar.gz`, `registry.zip`, and `grafana.zip`.
4. Confirm the Gitea dump contains `gitea-db.sql`, repositories, and data.
5. Confirm Registry contains `docker/registry/v2` and Grafana contains
   `grafana.db`.
6. Import the Gitea dump and Registry/Grafana data only into isolated storage.
7. Start isolated workloads without production ingress or DNS.
8. Verify Gitea login/clone, Registry pull, and Grafana dashboard access.
9. Record the backup name, hashes, elapsed restore time, and test result under
   `D:\HyperV\operations\rehearsals`.
10. Remove only the explicitly created isolated restore resources.

## Monthly upgrade rehearsal

1. Take and verify a fresh logical backup and retain the latest cold VM backup.
2. Review K3s, Kubernetes, Gitea, Registry, and observability release notes.
3. Confirm the proposed Kubernetes version-skew path is supported.
4. Render and server-dry-run the complete desired state:

   ```powershell
   kubectl kustomize ./k8s/overlays/current
   kubectl apply --dry-run=server -k ./k8s/overlays/current
   ```

5. Clone the cold VM backup into the isolated restore-test VM.
6. Apply the proposed upgrade only to that isolated VM.
7. Run `invoke-daily-health.ps1`, a representative CI pipeline, and backup
   verification there.
8. Record versions, duration, failures, rollback result, and capacity readings.
9. Approve production upgrade only after the isolated rehearsal passes.

Do not use these rehearsals to perform final DNS cutover or retire rollback
assets. Those actions remain blocked until Phase G and the seven-day soak pass.

See `docs/phase-h4-soak-runbook.md` while the temporary H4 acceptance schedule
is active.
