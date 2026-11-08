# Current Kubernetes architecture

Last verified: 2026-11-07 (UTC)

## Overview

The development platform runs as a single-node K3s cluster directly on a
physical Ubuntu server. There is no Hyper-V or other virtual-machine layer.

| Component | Current configuration |
|---|---|
| Hardware | Micro-Star International `MS-7C89` physical desktop |
| Operating system | Ubuntu 24.04.4 LTS, Linux 6.8.0-146-generic |
| Virtualization | None detected |
| Kubernetes node | `k3s-server`, control plane and worker |
| Node address | `192.168.68.54` (DHCP on `eno1`, MAC `2c:f0:5d:82:58:d4`) |
| Kubernetes distribution | K3s `v1.36.1+k3s1` |
| Container runtime | containerd `2.2.3-k3s1` |
| Ingress | Bundled Traefik with K3s ServiceLB on ports 80 and 443 |
| Storage | K3s `local-path` volumes on the server disk |
| Desired state | `k8s/overlays/current` Kustomize overlay |
| Availability model | One node; no high availability or storage replication |

## Architecture diagram

```mermaid
flowchart TB
    Users["LAN clients and developers"]

    subgraph Host["Physical MSI server - 192.168.68.54"]
        Ubuntu["Ubuntu 24.04.4 LTS<br/>No virtualization"]
        K3s["Single-node K3s v1.36.1<br/>Control plane and worker<br/>containerd"]
        Disk["Local server disk<br/>local-path StorageClass"]
        Ubuntu --> K3s
        K3s --> Disk
    end

    Users -->|"HTTP 80 / HTTPS 443"| LB["K3s ServiceLB"]
    Users -->|"Git SSH 32222"| Gitea
    LB --> Traefik

    subgraph System["kube-system"]
        Traefik["Traefik ingress"]
        DNS["CoreDNS"]
        Metrics["Metrics Server"]
        Provisioner["Local-path provisioner"]
        NodeExporter["Node Exporter"]
        Promtail["Promtail"]
    end

    Traefik -->|"gitea.dev.home.arpa"| Gitea
    Traefik -->|"registry.dev.home.arpa"| Registry
    Traefik -->|"grafana.dev.home.arpa"| Grafana
    Traefik -->|"demo.dev.home.arpa"| Demo
    Traefik -->|"ollama.dev.home.arpa"| Ollama

    subgraph Platform["platform-system"]
        Gitea["Gitea<br/>StatefulSet - 1 replica"]
        Registry["OCI Registry<br/>Deployment - 1 replica"]
        GiteaPVC["Data 10 GiB<br/>Config 1 GiB"]
        RegistryPVC["Registry data 20 GiB"]
        Gitea --- GiteaPVC
        Registry --- RegistryPVC
    end

    subgraph CI["ci-jobs"]
        Runner["Gitea Runner<br/>Deployment - concurrency 1"]
        CIJobs["Temporary Kubernetes CI Jobs"]
        Artifacts["CI artifacts 1 GiB"]
        RunnerData["Runner data 1 GiB"]
        Runner --> CIJobs
        CIJobs --> Artifacts
        Runner --- RunnerData
    end

    Gitea -->|"Actions workflow"| Runner
    CIJobs -->|"Push OCI images"| Registry
    CIJobs -->|"Code analysis"| Sonar

    subgraph Apps["demo-apps"]
        Demo["Junior full-stack demo<br/>Deployment - 1 replica"]
    end

    subgraph LLM["llm"]
        Ollama["Ollama<br/>Deployment - 1 replica<br/>NodePort 31134"]
    end

    Demo -->|"Telemetry"| OTel
    Demo -->|"Pull image"| Registry

    subgraph Emulators["cloud-emulators"]
        Sonar["SonarQube<br/>Deployment - 1 replica"]
        Postgres["PostgreSQL 16<br/>StatefulSet - 1 replica"]
        Azurite["Azurite<br/>Scaled to 0"]
        FakeGCS["Fake GCS<br/>Scaled to 0"]
        LocalStack["LocalStack<br/>Scaled to 0"]
        Sonar --> Postgres
    end

    subgraph Observability["observability"]
        Grafana["Grafana"]
        Prometheus["Prometheus"]
        Alertmanager["Alertmanager"]
        Loki["Loki"]
        Tempo["Tempo"]
        OTel["OpenTelemetry Collector"]
        KSM["kube-state-metrics"]
        Grafana --> Prometheus
        Grafana --> Loki
        Grafana --> Tempo
        Prometheus --> Alertmanager
        OTel --> Tempo
    end

    Prometheus --> KSM
    Prometheus --> NodeExporter
    Prometheus --> K3s
    Promtail --> Loki
    K3s --> Promtail
```

## Namespace and workload inventory

| Namespace | Purpose | Current workloads |
|---|---|---|
| `kube-system` | K3s infrastructure | CoreDNS, Traefik, ServiceLB, metrics-server, local-path provisioner, Node Exporter and Promtail |
| `platform-system` | Core development platform | Gitea StatefulSet and OCI Registry Deployment, both with one replica |
| `ci-jobs` | Pipeline execution | One Gitea runner plus short-lived Kubernetes Jobs |
| `observability` | Metrics, logs, traces and dashboards | Grafana, Prometheus, Alertmanager, Loki, Tempo, OpenTelemetry Collector and kube-state-metrics |
| `cloud-emulators` | Code analysis and cloud emulation | SonarQube and PostgreSQL running; Azurite, Fake GCS and LocalStack scaled to zero |
| `demo-apps` | Sample applications | Junior full-stack demo, one replica, image tag `79e60dbe57f1` |
| `llm` | Local model serving | Ollama, one replica, model volume 50 GiB, NodePort `31134` |
| `default` | Kubernetes default | No application workloads |

## Network entry points

| Address | Destination | Exposure |
|---|---|---|
| `https://gitea.dev.home.arpa` | Gitea | TLS through Traefik |
| `https://registry.dev.home.arpa` | OCI Registry | TLS through Traefik |
| `https://grafana.dev.home.arpa` | Grafana | TLS through Traefik |
| `http://demo.dev.home.arpa` | Junior full-stack demo | HTTP through Traefik |
| `http://ollama.dev.home.arpa` | Ollama | HTTP through Traefik |
| `192.168.68.54:31134` | Ollama | NodePort |
| `192.168.68.54:32222` | Gitea SSH | NodePort |

Prometheus, Alertmanager, Loki, Tempo, OpenTelemetry and SonarQube use
ClusterIP services. Operators normally reach them using loopback-only
`kubectl port-forward` sessions through `kube-manage`.

## Persistent storage

The default `local-path` StorageClass has a `Delete` reclaim policy,
`WaitForFirstConsumer` volume binding and no volume expansion. The data is
stored on the physical server and is not replicated.

| Namespace | Claim | Capacity | State |
|---|---|---:|---|
| `platform-system` | Gitea data | 10 GiB | Bound |
| `platform-system` | Gitea configuration | 1 GiB | Bound |
| `platform-system` | Registry data | 20 GiB | Bound |
| `ci-jobs` | Runner data | 1 GiB | Bound |
| `ci-jobs` | CI artifacts | 1 GiB | Bound |
| `observability` | Prometheus data | 10 GiB | Bound |
| `observability` | Loki data | 10 GiB | Bound |
| `observability` | Tempo data | 5 GiB | Bound |
| `observability` | Grafana data | 1 GiB | Bound |
| `observability` | Alertmanager data | 1 GiB | Bound |
| `cloud-emulators` | SonarQube data, extensions and logs | 5 GiB total | Bound |
| `cloud-emulators` | SonarQube PostgreSQL data | 5 GiB | Bound |
| `cloud-emulators` | Azurite, Fake GCS and LocalStack data | Deferred | Pending while workloads are scaled to zero |
| `llm` | Ollama models | 50 GiB | Bound |

The live bound capacity at verification time was 120 GiB. Platform names in `/etc/hosts` resolve to `192.168.68.54`. `/dev/sda2` is mounted read-write at `/mnt/dev` by the systemd unit `mnt-dev.mount`.

## Security and resource boundaries

- K3s secrets encryption is enabled at rest.
- The host reserves CPU, memory and ephemeral storage for Linux and Kubernetes.
- Kubelet hard and soft eviction thresholds protect the single node from memory
  and disk exhaustion.
- Default-deny NetworkPolicies protect the primary platform namespaces, with
  explicit rules for DNS and approved application flows.
- `ci-jobs` and `demo-apps` enforce the restricted Pod Security Standard.
- Platform, observability and emulator namespaces enforce baseline security and
  audit or warn against restricted-policy violations.
- ResourceQuotas and LimitRanges bound pods, Jobs, PVCs, CPU and memory.
- The Gitea runner can create and inspect namespaced Jobs and read their logs,
  but it is not a cluster administrator and does not receive a Docker socket.
- Secret values are deliberately excluded from Kustomize and Git.

## Operational notes

- The cluster is intentionally not highly available. Host failure interrupts
  the control plane and every workload.
- Local-path storage has no automatic replication. Backups remain required for
  Gitea, the registry, Grafana and Kubernetes objects.
- Optional emulator workloads are normally kept at zero replicas to preserve
  capacity. SonarQube is currently the only active optional service.
- Ollama is part of `k8s/overlays/current` through `k8s/base/llm`. kube-state-metrics may egress to TCP 443 and 6443 so it can reach the API server. On 2026-11-07 that policy was applied by itself. A full `kubectl apply -k k8s/overlays/current` would also move `junior-fullstack-demo` from image tag `79e60dbe57f1` back to `bootstrap`.
- The node address comes from DHCP. Reserve `192.168.68.54` for MAC `2c:f0:5d:82:58:d4` on the router so the hosts file and ingress address stay aligned.
- The complete desired state is assembled by
  [`k8s/overlays/current/kustomization.yaml`](../k8s/overlays/current/kustomization.yaml).
- K3s host settings are recorded in
  [`k8s/config/k3s-config.yaml`](../k8s/config/k3s-config.yaml).
- Day-to-day commands and port-forward procedures are documented in
  [`k8s/README.md`](../k8s/README.md).

## Revalidation commands

Run these commands on the standalone server to refresh this document after a
platform change:

```bash
kubectl get nodes -o wide
kubectl get namespaces
kubectl get deployments,statefulsets,daemonsets,jobs -A -o wide
kubectl get pods -A -o wide
kubectl get services,ingresses,networkpolicies -A
kubectl get storageclass,pv
kubectl get pvc -A
kubectl get resourcequota,limitrange -A
kubectl top node
kubectl top pods -A
systemd-detect-virt
```
