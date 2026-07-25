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
`platform-tls`, `gitea-secrets`, and `registry-auth` in `platform-system`, plus
`grafana-admin` and `grafana-tls` in `observability`, before applying it to a new
cluster. Runtime credentials remain under `D:\HyperV\credentials`, outside Git.

## Important limitations

- This is not high availability.
- The default-deny policies assume the K3s network plugin enforces NetworkPolicy.
- Secrets are deliberately excluded from every overlay.
- Do not remove existing Compose volumes after backup. They are the rollback source.
