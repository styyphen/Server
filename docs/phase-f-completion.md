# Phase F Safe CI/CD Completion

Verified 2026-07-25 against the permanent `standalone-kubernetes`.

## Implemented controls

- Gitea Runner `1.0.0`, one replica and capacity one.
- Dedicated `stage-f-orchestrator` label and 30-minute runner timeout.
- No Docker, containerd, or Podman socket mounts.
- Namespaced RBAC for Jobs, pod state/logs, and diagnostic events only.
- Restricted Pod Security, default-deny networking, explicit resources,
  active deadlines, zero retries, and cleanup TTLs.
- Bounded 1-GiB runner PVC and bounded 1-GiB artifact PVC.
- Cheap checks before image publishing and scanning.
- Daemonless OCI publishing with Crane `0.20.3`.
- Trivy `0.61.1` vulnerability/secret scanning with a bounded persistent DB
  cache.
- Syft `1.44.0` SPDX JSON SBOM generation.
- Timestamped structured stage/job/container diagnostics.

## Acceptance evidence

The representative pipeline produced and verified:

- `test-results.xml`
- `coverage.json`
- `scan.json`
- `sbom.spdx.json`
- `image-digest.txt`

Direct execution passed, then Gitea Actions workflow run `2` passed for
`developer-admin/phase-d-smoke` at commit
`e0e7e262403cd228047f6f1ebe9ba73098efbfc9`.

Post-run checks:

| Gate | Result |
|---|---|
| Windows free memory | 4.67 GiB |
| K3s node CPU | 3% |
| K3s node memory | 69% |
| Idle runner | 2m CPU / 8 MiB |
| Gitea and Registry | Ready |
| Observability workloads | All Ready |
| Required artifacts | All present and non-empty |
| Runner can create Jobs | Yes |
| Runner can create Deployments | No |
| Runner can read Secrets | No |

Phase F exit criterion is satisfied: a representative pipeline completes
without degrading Gitea or observability.
