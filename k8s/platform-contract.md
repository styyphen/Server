# Platform contract

Status: written 2026-11-07, after Stage 0 was retested. This page is the product. Backstage templates and scorecards will enforce it. The Backstage app is a separate repository at `/mnt/dev/backstage` and is deployed at `https://backstage.dev.home.arpa`.

The runtime is the single-node k3s cluster in [the architecture doc](../docs/current-kubernetes-architecture.md). This contract says what a developer can expect from it.

## Roles

A developer can create a service from a template, open a pull request in Gitea, see CI, open the running URL, and see that service's logs, metrics, and traces in Grafana.

An operator owns the cluster, quotas, add-on accept and stop, secrets, and [`k8s/overlays/current`](overlays/current/kustomization.yaml). Day-to-day cluster work goes through `kube-manage`. A developer does not receive a cluster kubeconfig.

## Paved roads

New services come from one of these templates under `localCICD/repo-templates/`:

| Template | What it produces |
|---|---|
| `dotnet-api` | .NET API |
| `node-api` | Node API |
| `react` | React UI |
| `worker-service` | Background worker |

`.platform/addons.yaml` stays empty unless the service opts in. The only optional names are `azurite`, `fake-gcs`, `localstack`, and `sonarqube`. One heavy add-on runs at a time.

## Rules for every component

- It has an owner. The catalog `Group` is filled in when the catalog exists. Until then the owner is the platform operator.
- It has a `catalog-info.yaml`. Those files arrive in Stage 2.
- It exports OpenTelemetry only to `otel-collector.observability.svc.cluster.local`, port `4317` for gRPC or `4318` for HTTP. The current templates use `4318`. It does not talk to Grafana, Prometheus, Loki, or Tempo directly.
- It has a readiness probe. `dotnet-api` and `node-api` use `GET /health`. `react` uses `GET /`. `worker-service` uses its exec probe. The running junior demo uses `GET /api/health` until it is recreated from a template.
- It has a NetworkPolicy. Ingress comes from Traefik in `kube-system`. Egress is DNS plus the collector on port `4318`, which is the rule already in the template policies.
- Its image is `registry.dev.home.arpa/<project-slug>:<tag>`.
- Its hostname on this LAN is `<project-slug>.dev.home.arpa`.

## One namespace per app

The namespace name is the project slug. Copy the Pod Security labels from `demo-apps` and `ci-jobs`:

```yaml
pod-security.kubernetes.io/enforce: restricted
pod-security.kubernetes.io/audit: restricted
pod-security.kubernetes.io/warn: restricted
```

Give the namespace a `ResourceQuota` named `app-budget` and a `LimitRange` named `app-defaults`, using the same object shape as `ci-budget` and `job-defaults` in [`k8s/base/namespaces`](base/namespaces). `demo-apps` has the Pod Security labels and no quota today. The app budget below is the one new services use, sized from the junior demo container so one service still fits beside the platform on this node:

| | Request | Limit |
|---|---|---|
| Container default | cpu `25m`, memory `48Mi` | cpu `250m`, memory `192Mi` |
| Namespace hard cap | cpu `500m`, memory `512Mi` | cpu `1`, memory `1Gi` |

The quota also caps the namespace at 3 pods and 2 persistent volume claims.

## What is still operator-owned

Secrets stay out of Git. `registry-pull`, CI tokens, and the SonarQube database credential are created out of band, the same way `platform-tls` and `gitea-secrets` are.

Deploying the platform overlay stays an operator action. A full `kubectl apply -k k8s/overlays/current` still rewrites `junior-fullstack-demo` from image tag `79e60dbe57f1` back to `bootstrap`. Do not apply that overlay to publish an app.

Once Flux is installed, merging the app repository is what deploys that app. Until then, the operator applies the app overlay after the pull request merges.
