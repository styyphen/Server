# Current D: Server State

Verified 2026-07-25 against the running Hyper-V VM and Kubernetes API.

## Source of truth

- Repository and automation: `C:\Server`
- Permanent server runtime: Hyper-V VM `local-k3s-server`
- VM storage: `D:\HyperV\local-k3s-server`
- Runtime credentials: `D:\HyperV\credentials`
- Cold VM backup: `D:\server-backups\hyperv\baseline-20260723`
- Platform logical backup: `D:\server-backups\platform\phase-d-20260723`
- Observability logical backup:
  `D:\server-backups\observability\phase-e-20260725`

Credentials, kubeconfigs, certificates, private keys, VHDX files, and backup
archives are runtime state and must not be committed.

## Hyper-V and Ubuntu

| Setting | Current value |
|---|---|
| VM name | `local-k3s-server` |
| Address | `192.168.50.10/24` |
| Host/NAT gateway | `192.168.50.1` |
| Hyper-V switch | `LocalServerNAT` |
| CPUs | 6 |
| Dynamic memory | 5–8 GiB; 5-GiB startup |
| Guest OS | Ubuntu 24.04.4 LTS |
| SSH account | `developer`, key-only |
| Automatic actions | Start automatically; graceful guest shutdown |
| Checkpoints | Disabled |

The server uses the fixed hostnames `gitea.dev.home.arpa` and
`registry.dev.home.arpa`. Windows trusts the private local CA stored outside
Git. WSL and Docker Desktop are not part of the always-on runtime.

## Kubernetes

| Setting | Current value |
|---|---|
| Distribution | K3s `v1.36.1+k3s1` |
| Node | `k3s-server`, Ready |
| Runtime | containerd `2.2.3-k3s1` |
| Pod CIDR | `10.42.0.0/16` |
| Service CIDR | `10.43.0.0/16` |
| Ingress | Traefik `3.6.13` |
| Storage class | `local-path` |
| Windows client | kubectl `v1.36.1` |

The live K3s configuration matches
`k8s/config/k3s-config.yaml`. Secrets encryption, system/kube reservations,
eviction thresholds, namespace quotas, resource defaults, Pod Security labels,
and default-deny network policies are active.

## Deployed platform

| Component | Version | Persistent storage | Endpoint |
|---|---|---|---|
| Gitea rootless | `1.26.2` | 10 GiB data + 1 GiB config | `https://gitea.dev.home.arpa` |
| Distribution Registry | `3.1.1` | 20 GiB | `https://registry.dev.home.arpa` |
| Prometheus | `3.1.0` | 10 GiB | Cluster-internal |
| Alertmanager | `0.28.0` | 1 GiB | Cluster-internal |
| Node exporter | `1.8.2` | None | Cluster-internal |
| Grafana | `11.5.2` | 1 GiB | `https://grafana.dev.home.arpa` |
| Loki | `3.3.2` | 10 GiB | Cluster-internal |
| Promtail | `3.3.2` | None | Cluster-internal |
| Tempo | `2.7.1` | 5 GiB | Cluster-internal |
| OpenTelemetry Collector | `0.118.0` | None | Cluster-internal |
| Gitea Runner | `1.0.0` | 1 GiB registration data | Cluster-internal |

Gitea SSH is exposed on node port `32222`. Registry access requires bcrypt
authentication and TLS. K3s/containerd trusts the local CA and has registry
authentication in root-owned `/etc/rancher/k3s/registries.yaml`.

The live desired objects are rendered by `k8s/overlays/current`. Before applying
that overlay to a new cluster, create these external Secrets in
`platform-system`:

- `platform-tls`
- `gitea-secrets`
- `registry-auth`

Also create these external Secrets in `observability`:

- `grafana-admin`
- `grafana-tls`

Use `k8s/scripts/generate-platform-bootstrap.sh` to generate new material
outside Git. Create the Gitea administrator after first startup with the Gitea
CLI; its password is also stored outside Git.

## Verified workflows

- K3s node, DNS, local-path storage, Traefik ingress, and metrics survive reboot.
- Gitea authenticated Git pushes, branches, and pull-request creation pass.
- Registry rejects anonymous requests and accepts authenticated requests.
- A pinned image was pushed, pulled through K3s, and resolved by immutable
  digest.
- Gitea repositories/database/configuration and Registry manifests/blobs were
  backed up and restored into isolated validation directories.
- The VM cold backup booted as an isolated restore.

## Phase status

- Phases A–D in `docs/hyperv-k3s-server-execution-plan.md` are complete.
- Phase E is complete. E1 through E4, full-VM reboot recovery, capacity checks,
  controlled telemetry and alert tests, and logical backup/restore testing
  passed.
- Phase F is complete. Gitea Actions run through one capacity-one runner using
  the `stage-f-orchestrator` label. Cheap checks execute before image work.
  Native Jobs enforce Restricted Pod Security, explicit resources, deadlines,
  zero retries, and cleanup TTLs. Crane publishes without Docker/containerd/
  Podman sockets; Trivy scans the published image; Syft emits an SPDX JSON SBOM.
  Test, coverage, scan, SBOM, and immutable digest artifacts persist on a
  bounded 1-GiB PVC. Runner RBAC permits namespaced Job lifecycle, pod logs,
  and event reads, but denies Deployment creation and Secret reads.
- Gitea Actions run `2` for `developer-admin/phase-d-smoke` completed
  successfully at commit `e0e7e262403cd228047f6f1ebe9ba73098efbfc9`.
  Post-run Windows free memory was 4.67 GiB; VM assigned/demand memory was
  6.07/4.85 GiB; K3s memory was 69%; and Gitea plus all observability pods
  remained Ready.
- Phase H started before Phase G by operator decision. H1 is complete: all four
  repository templates include Kubernetes bases and Restricted local overlays,
  and generated-repository validation enforces their deployment contract.
  H2 automation subsequently completed; final cutover remains blocked on H3
  resilience acceptance and the seven-day soak.
- Phase H2 is complete. SYSTEM scheduled tasks run logical backups at 02:00,
  health checks at 06:00, and guarded Registry maintenance Sundays at 04:00.
  The `ci-artifact-retention` CronJob runs daily at 03:30. The first production
  backup is `D:\server-backups\platform\daily-20260725T110627Z`; all four
  artifact hashes and isolated extraction checks passed.
- Phase G is complete. Four optional add-on packages are installed in
  `cloud-emulators` and default to zero replicas. The lifecycle enforces one
  active add-on, performs API acceptance, and guarantees cleanup. The final
  sequential run passed with at least 4.22 GiB Windows free memory and all core
  health gates green. Hyper-V dynamic-memory buffer is 5% with the existing
  5/5/8 GiB minimum/startup/maximum bounds. H3 is next.
- The Docker Compose observability files in the repository are legacy/local
  development assets, not the active D: server runtime.
