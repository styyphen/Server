# Single-server Kubernetes platform

This directory implements the Hyper-V/K3s server described by the
[single-server plan](../docs/local-kubernetes-single-server-plan.md). The exact
deployed state is recorded in
[current-server-state.md](../docs/current-server-state.md).

## Phase 0: measure and back up

On the current Windows Docker host:

```powershell
./k8s/scripts/measure-capacity.ps1 -SampleSeconds 30
./k8s/scripts/backup-compose.ps1 -OutputDirectory E:\server-backups -PullHelperImage
```

The capacity report and local backup folders are ignored by Git. Place backups on
a different physical disk. The backup script does not stop services; schedule a
brief write freeze and take a final backup before migrating stateful services.

## Phase 1: install K3s

Use a supported Ubuntu Server LTS host with a static address. Review
`config/k3s-config.yaml`, especially the reservations against measured capacity.
The baseline keeps the lightweight K3s ServiceLB so the bundled Traefik ingress can
bind the single node's HTTP and HTTPS ports. Non-HTTP host ports will be added
deliberately in later phases.

Copy the configuration and installer to the server:

```bash
sudo install -d -m 0750 /etc/rancher/k3s
sudo install -m 0640 k8s/config/k3s-config.yaml /etc/rancher/k3s/config.yaml
sudo INSTALL_K3S_VERSION='<approved-version>' sh k8s/scripts/install-k3s.sh
```

The installer requires an explicitly pinned K3s version and downloads the official
installer over TLS. Do not pipe an unpinned release into the server.

Copy `/etc/rancher/k3s/k3s.yaml` to the administration machine, change its server
address from `127.0.0.1`, restrict its file permissions, and keep it outside Git.

Render and validate the baseline without changing a cluster:

```powershell
./k8s/scripts/validate.ps1
./k8s/scripts/bootstrap.ps1
```

Apply to the connected single-node cluster:

```powershell
./k8s/scripts/validate.ps1 -Cluster
./k8s/scripts/bootstrap.ps1 -Apply
```

The baseline creates four namespaces with quotas, default resource limits, Pod
Security labels, and default-deny networking. Workloads added in later phases must
include explicit network policies; DNS is the only egress allowed initially.

## Current deployed overlay

`overlays/single-server` remains the safe K3s baseline. The running D: server
also has the platform workloads represented by `overlays/current`:

```powershell
kubectl kustomize ./k8s/overlays/current
kubectl apply --dry-run=server -k ./k8s/overlays/current
kubectl apply -k ./k8s/overlays/current
```

The current overlay intentionally does not contain Secret values. Create
`platform-tls`, `gitea-secrets`, and `registry-auth` in `platform-system`;
`grafana-admin` and `grafana-tls` in `observability`; and
`gitea-runner-registration` with a `token` key and `ci-registry-auth` with
`username` and `password` keys in `ci-jobs` before applying it to a new
cluster. Runtime credentials remain under `D:\HyperV\credentials`, outside Git.

## Phase F runner bootstrap

The Phase F runner has capacity one and uses the dedicated
`stage-f-orchestrator` host label. It has no Docker socket. Its service account
can create and observe Jobs and read pod logs only in `ci-jobs`; it cannot
create Deployments or read Secrets. Network access is limited to DNS, Gitea,
and the K3s API.

The pinned Kubernetes client is exposed through a read-only OCI image volume.
`/opt/ci/run-native-smoke.sh` launches the first native Job with explicit
requests/limits, restricted pod security, a two-minute active deadline, no
retry, and a five-minute cleanup TTL. The matching manually dispatched workflow
is in `samples/platform-smoke/.gitea/workflows/native-job-smoke.yml`.

`/opt/ci/run-representative-pipeline.sh` runs cheap checks before image work,
publishes an OCI image with Crane without a container daemon, scans it with
Trivy, generates an SPDX JSON SBOM with Syft, and writes test, coverage, scan,
SBOM, and immutable image-digest artifacts to the bounded 1-GiB artifact PVC.
The matching workflow is
`samples/platform-smoke/.gitea/workflows/representative-ci.yml`.

Pipeline output uses timestamped `level`, `event`, and `message` fields.
Failures immediately include Job and pod state, every init/main container exit
reason and log, and related Kubernetes events. Scanner download progress is
suppressed while diagnostic detail is retained.

Create an instance runner registration token in Gitea, store it outside Git,
and create the external Secret:

```powershell
kubectl -n ci-jobs create secret generic gitea-runner-registration `
  --from-literal=token='<registration-token>'
kubectl -n ci-jobs create secret generic ci-registry-auth `
  --from-literal=username='<registry-username>' `
  --from-literal=password='<registry-password>'
kubectl apply --dry-run=server -k ./k8s/overlays/current
kubectl apply -k ./k8s/overlays/current
kubectl -n ci-jobs rollout status deployment/gitea-runner --timeout=120s
```

The runner registration file persists in a bounded 1-GiB PVC so pod restarts do
not create duplicate runner registrations.

Validate native Job execution directly:

```powershell
kubectl -n ci-jobs exec deployment/gitea-runner -- `
  /opt/ci/run-native-smoke.sh
kubectl -n ci-jobs get jobs,pods
```

Validate the representative pipeline directly:

```powershell
kubectl -n ci-jobs exec deployment/gitea-runner -- `
  /opt/ci/run-representative-pipeline.sh
```

## Important limitations

- This is not high availability.
- The default-deny policies assume the K3s network plugin enforces NetworkPolicy.
- Secrets are deliberately excluded from every overlay.
- Do not remove existing Compose volumes after backup. They are the rollback source.
