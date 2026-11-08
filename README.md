# Local Observability Server

Reusable Docker-based observability for local development, now running as a single-node k3s platform. The execution plan below is the gate for the next change: bring up a [Backstage](https://backstage.io/) developer portal on this cluster. Stage 0 was applied on 2026-11-07. Stages 1 through 5 are still waiting.

## Execution plan

Status: Stage 0 retested and Stage 1 written on 2026-11-07. Backstage is not installed.

Backstage is an open-source framework for a developer portal. The portal this platform will run uses the three parts described at [backstage.io](https://backstage.io/):

| Backstage part | What it does here |
|---|---|
| [Software Catalog](https://backstage.io/docs/features/software-catalog/) | One list of services, owners, APIs, and the platform tools already running |
| [Software Templates](https://backstage.io/docs/features/software-templates/) | The four repo templates under `localCICD/repo-templates/`, started from `/create` |
| [TechDocs](https://backstage.io/docs/features/techdocs/creating-and-publishing/) | Markdown that already lives next to the code, rendered in the portal |

k3s stays the runtime. Gitea, the registry, CI, SonarQube, and the OpenTelemetry stack stay the platform underneath the portal. `kube-manage` stays the operator console. The official install and deploy guides are [Standalone Installation](https://backstage.io/docs/getting-started/) and [Deploying with Kubernetes](https://backstage.io/docs/deployment/k8s/).

### What is already true

Checked on `k3s-server` on 2026-11-07.

- Node `k3s-server` is Ready, k3s `v1.36.1+k3s1`, 8 cores, about 15.5 GiB RAM. The NIC address is `192.168.68.54/22` from DHCP.
- Ingress for Gitea, the registry, Grafana, and `demo.dev.home.arpa` is published on `192.168.68.54` through Traefik.
- `platform-system`, `ci-jobs`, `observability`, `cloud-emulators`, `demo-apps`, and `llm` are the working namespaces. Desired state for everything except Ollama is `k8s/overlays/current`.
- Two pods are unhealthy. `demo-apps/junior-fullstack-demo` is `ImagePullBackOff`. `observability/kube-state-metrics` is `CrashLoopBackOff`.
- Backstage's standalone guide asks for at least 6 GiB of memory and 20 GiB of disk for a local demo app. This host can run one small Backstage deployment plus Postgres. It cannot also keep SonarQube, the cloud emulators, and a demo dataset hot at the same time.

### Stage 0 — Repair the paved road

Do this before `npx @backstage/create-app`. A catalog that lists a demo which cannot pull its image is the wrong first page.

1. Reserve `192.168.68.54` for this host on the DHCP server. The lease on `eno1` was short when this plan was written, and `/etc/hosts` still points the platform names at `192.168.68.59`.

   ```bash
   sudo sed -i 's/192.168.68.59/192.168.68.54/' /etc/hosts
   grep home.arpa /etc/hosts
   ```

   The line must include `gitea.dev.home.arpa`, `registry.dev.home.arpa`, `grafana.dev.home.arpa`, `demo.dev.home.arpa`, and `ollama.dev.home.arpa`. Put the same line in the Windows hosts file. kubelet resolves `registry.dev.home.arpa` through this file, and the demo pull currently dies with `dial tcp 192.168.68.59:443: connect: no route to host`.

2. Recreate the demo pod and confirm the health URL:

   ```bash
   kubectl -n demo-apps delete pod -l app.kubernetes.io/name=junior-fullstack-demo
   kubectl -n demo-apps rollout status deploy/junior-fullstack-demo
   curl -sS -H 'Host: demo.dev.home.arpa' http://192.168.68.54/api/health
   ```

3. Give kube-state-metrics a way out of the `observability` default-deny policy. Its policy in `k8s/base/observability/network-policies.yaml` allows Prometheus to scrape port 8080 and allows no egress. The process exits on `Get "https://10.43.0.1:443/version": connect: connection refused`. Prometheus already allows TCP 443 and 6443, which is how pods reach the API server at `192.168.68.54:6443`. Add that egress to the kube-state-metrics policy and set `policyTypes` to `Ingress` and `Egress`:

   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: kube-state-metrics
     namespace: observability
   spec:
     podSelector:
       matchLabels: {app.kubernetes.io/name: kube-state-metrics}
     policyTypes: [Ingress, Egress]
     ingress:
       - from:
           - podSelector:
               matchLabels: {app.kubernetes.io/name: prometheus}
         ports:
           - {protocol: TCP, port: 8080}
     egress:
       - ports:
           - {protocol: TCP, port: 443}
           - {protocol: TCP, port: 6443}
   ```

   Apply with the same dry-run the platform already uses, then apply for real:

   ```bash
   kubectl apply --dry-run=server -k ./k8s/overlays/current
   kubectl apply -k ./k8s/overlays/current
   kubectl -n observability rollout status deploy/kube-state-metrics
   ```

4. Mount `/dev/sda2` read-write on `/mnt/dev` so `kube-manage` resolves. The symlink is `/home/developer/.local/bin/kube-manage` → `/mnt/dev/Server/k8s/manage.sh`.
5. Put the Ollama workload in `llm` into `k8s/overlays/current`, or record it as an on-demand add-on with the same accept/stop lifecycle as SonarQube.
6. Refresh `docs/current-kubernetes-architecture.md` with the revalidation commands at the bottom of that file. The page was last verified on 2026-07-30.

Exit check: demo Ready, kube-state-metrics Ready, `kube-manage status` runs, and Gitea, the registry, Grafana, and the demo answer on `192.168.68.54`.

Result on 2026-11-07:

- `/etc/hosts` now maps the five platform names to `192.168.68.54`. A copy of the previous file is `/etc/hosts.bak.stage0-20261107`.
- `junior-fullstack-demo` is Running and `http://demo.dev.home.arpa/api/health` returns `{"status":"ok","version":"79e60dbe57f1"}`.
- The kube-state-metrics NetworkPolicy allows egress to TCP 443 and 6443. The pod is Running. The policy was applied from `k8s/base/observability/network-policies.yaml` on its own. `kubectl apply -k k8s/overlays/current` was not run, because that overlay still sets the demo image to `registry.dev.home.arpa/junior-fullstack-demo:bootstrap` and would replace the running tag.
- `/dev/sda2` is mounted read-write at `/mnt/dev` by systemd unit `mnt-dev.mount`, enabled for boot. `kube-manage status` runs.
- Ollama is declared in `k8s/base/llm` and included from `k8s/overlays/current`. The live Deployment, Service, PVC, IngressRoute, and ServersTransport already matched that spec, so apply reported them unchanged. Namespace `llm` is baseline Pod Security.
- The router reservation for MAC `2c:f0:5d:82:58:d4` → `192.168.68.54` is still outstanding. The Windows hosts file was not changed from this server.

### Stage 1 — Write the platform contract

Add one short page beside `k8s/README.md` before any Backstage code exists.

- A developer creates a service from a template, opens a pull request, sees CI, opens the running URL, and sees logs, metrics, and traces.
- An operator owns the cluster, quotas, add-on accept/stop, secrets, and `k8s/overlays/current`.
- The only paved roads are `dotnet-api`, `node-api`, `react`, and `worker-service`.
- Every component has an owner, a `catalog-info.yaml`, OTLP to the collector, a `/health` endpoint, a network policy, and an image from `registry.dev.home.arpa`.
- Each app gets its own namespace, copied from the quota and Pod Security pattern on `demo-apps` and `ci-jobs`.

Result on 2026-11-07: the contract is [`k8s/platform-contract.md`](k8s/platform-contract.md), linked from [`k8s/README.md`](k8s/README.md). Stage 0 was retested first: the node was Ready on `192.168.68.54`, demo health returned `79e60dbe57f1`, kube-state-metrics was Running with API egress, Gitea, the registry, and Grafana answered, and `kube-manage status` succeeded. No cluster object was changed for this stage.

### Stage 2 — Create the Backstage app and fill the catalog

Follow [Standalone Installation](https://backstage.io/docs/getting-started/) on a workstation, then containerize. The documented prerequisites are Node.js 22 or 24, Yarn 4.4.1 (`corepack enable`, then `yarn set version 4.4.1`), and a normal build toolchain.

```bash
npx @backstage/create-app@latest
```

Name the app directory `backstage`. Keep it as its own Gitea repository. The generated tree has `app-config.yaml`, `catalog-info.yaml`, `packages/app`, and `packages/backend`. `yarn start` is only the local smoke test at `http://localhost:3000`. The cluster copy is a built image, as in [Deploying with Kubernetes](https://backstage.io/docs/deployment/k8s/).

Register what this node already runs. Core catalog discovery targets GitHub, GitLab, Bitbucket, and Azure DevOps, so the first source is a location list committed in this repo. Add `catalog-info.yaml` to this repo, to `developer-admin/junior-fullstack-demo`, and to each template. Kinds for the first import:

- `System` for the local development platform
- `Component` for Gitea, the registry, Grafana, the demo, Ollama, and Backstage itself
- `Group` for the owning team
- `API` only where a real API exists

TechDocs reads Markdown beside the code. Point it at `k8s/README.md`, `docs/current-kubernetes-architecture.md`, and each template's `docs/`. Update `docs/onboarding-new-project.md` so the published page matches the cluster endpoint, `otel-collector.observability.svc:4317`, and the Compose localhost instructions stay marked as the workstation path.

### Stage 3 — Deploy Backstage into this cluster

Use the shape from the Kubernetes guide, adapted to this platform. Skip the guide's minikube, `hostPath`, and `storageClassName: manual` volume. This node already has the `local-path` StorageClass. Keep secret values out of Git, the same rule as `platform-tls` and `gitea-secrets`.

| Object | Choice on this server |
|---|---|
| Namespace | `backstage` |
| App | One replica, container port `7007`, image in `registry.dev.home.arpa` |
| Database | PostgreSQL, one replica, `local-path` PVC, Secret created out of band |
| Config | `backend.database.client: pg` using `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD` |
| Ingress | Traefik host `backstage.dev.home.arpa` on the existing ServiceLB address |
| Policy | NetworkPolicy, requests, limits, and a non-root security context, same standard as `k8s/base` |
| Sign-in | Guest sign-in for the first operator check, then a Gitea OAuth2 app so the portal user and the Git user are the same person |

Build and push the image with the existing registry path (Crane or the Gitea runner, no Docker socket on the runner). Dry-run the overlay before apply. Confirm the other platform pods stay Ready after the new namespace is up.

Exit check: `https://backstage.dev.home.arpa` shows the catalog and a TechDocs page for this repo.

### Stage 4 — Make `/create` the on-ramp

Map `localCICD/repo-templates/` onto four Software Templates. Keep the file layout, Dockerfiles, k8s overlays, and `.platform/addons.yaml` (optional services stay empty unless someone opts in).

1. Parameters are the project name, the owner, and a SonarQube opt-in.
2. Publish creates a repository in one Gitea org. Built-in publish actions target GitHub and GitLab, so this step is a Gitea API action with a token that can create repos in that org and nothing else.
3. The new `catalog-info.yaml` is registered in the catalog.
4. Install Flux and let it reconcile Kustomize. The platform overlay stays operator-owned. Each app repo is its own Flux `Kustomization` with a namespace, quota, and network policy. The template opens a pull request. Merge is what deploys. The template runner has no cluster-admin rights.
5. `registry-pull` and CI tokens come from Sealed Secrets or External Secrets, populated once per namespace pattern. The developer gets no kubeconfig.

Exit check: create a throwaway `node-api` from the portal, merge its pull request, watch Flux roll it out, open its URL, and see its OTLP series in Grafana. Remove it by dropping that repo from the Flux list.

### Stage 5 — Show the tools that are already here

Add a plugin only when the tool is already on this node.

- Kubernetes plugin, read-only, limited to the component's namespace.
- Grafana link filtered by `service.name`.
- SonarQube link only when `.platform/addons.yaml` opts in. SonarQube keeps the existing on-demand lifecycle.
- Gitea link for the repo, open pull requests, and the latest Actions run.
- Five scorecard checks: owner in `catalog-info.yaml`, `/health` present, pod Ready, image from `registry.dev.home.arpa`, NetworkPolicy present.

Exit check: the junior full-stack component page shows owner, repo, CI, SonarQube, Grafana, the pod, and those five checks.

### Leave these for later

A second ingress, a service mesh, high availability, multi-cluster, running Azurite, LocalStack, fake-gcs, and SonarQube together, replacing `kube-manage`, and a chat plugin in the portal. Ollama in `llm` and Continue on the Windows client remain the coding assistant.

### Order of work

| Step | Done when |
|---|---|
| 0 | Demo and kube-state-metrics are Ready, names resolve to `192.168.68.54`, architecture doc matches `kubectl` |
| 1 | The one-page contract is merged |
| 2 | `catalog-info.yaml` exists for the platform and the demo |
| 3 | `backstage.dev.home.arpa` serves catalog and TechDocs |
| 4 | Flux deploys one template published to Gitea |
| 5 | The other three templates, the Kubernetes and Grafana links, and the five checks are live |

The first useful milestone is step 3 plus one template in step 4. Steps 0 and the hosts edit are the only cluster changes that should happen before the Backstage app exists.

## Compose observability stack

The sections below are the workstation Docker Compose path. The cluster path is `k8s/README.md` and `docs/current-kubernetes-architecture.md`. Applications on the cluster export OTLP to the collector Service in `observability`, and they keep the same `Luhl.Observability` settings.

Reusable Docker-based observability for local development. Applications send OpenTelemetry logs, metrics, and traces to one endpoint; this stack stores and visualizes them with Grafana, Prometheus, Loki, and Tempo.

## Start

```powershell
Copy-Item .env.example .env
.\scripts\start.ps1
```

Open:

- Grafana: http://localhost:3001
- Prometheus: http://localhost:9090
- Alertmanager: http://localhost:9093
- Loki: http://localhost:3100
- Tempo: http://localhost:3200

Default Grafana credentials are `admin` / `admin` unless changed in `.env`.

## Application Endpoint

Configure applications to export OpenTelemetry to:

- OTLP gRPC: `http://localhost:4317`
- OTLP HTTP: `http://localhost:4318`

Applications should set `service.name`, `service.version`, and `deployment.environment` resource attributes.

## .NET Integration

The reusable integration library lives in `src/Luhl.Observability`.

```csharp
builder.Services.AddProjectObservability(
    builder.Configuration,
    builder.Environment,
    builder.Logging);

var app = builder.Build();

app.UseProjectObservability();
```

Required appsettings:

```json
{
  "Observability": {
    "ServiceName": "orders-api",
    "ServiceVersion": "1.0.0",
    "EnvironmentName": "Development",
    "OtlpEndpoint": "http://localhost:4317"
  }
}
```

## Commands

```powershell
.\scripts\start.ps1
.\scripts\health-check.ps1
.\scripts\test-dotnet-sample.ps1
.\scripts\restart.ps1
.\scripts\stop.ps1
.\scripts\clean.ps1
```

`clean.ps1` keeps Docker volumes by default so local telemetry data is not deleted accidentally.

## Current Status

Implemented:

- Docker Compose stack
- Grafana, Prometheus, Loki, Tempo, OpenTelemetry Collector
- Alertmanager, cAdvisor, Node Exporter
- Grafana datasource and dashboard provisioning
- Service, logs, traces, alerts, container health, and system health dashboards
- Default Prometheus alert rules and Alertmanager routing
- PowerShell lifecycle scripts
- .NET sample API that emits OTLP logs, metrics, and traces
- Reusable `Luhl.Observability` .NET integration library
- Automated sample telemetry validation script

Use `.\scripts\test-dotnet-sample.ps1` after changes to prove metrics, logs, and traces still flow end to end.
