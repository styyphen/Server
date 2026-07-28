• Phases 0 and 1 are implemented.

  Added:

  - k8s/README.md
  - k8s/config/k3s-config.yaml
  - k8s/scripts/measure-capacity.ps1
  - k8s/scripts/backup-compose.ps1
  - k8s/scripts/install-k3s.sh
  - k8s/scripts/bootstrap.ps1
  - k8s/scripts/validate.ps1
  - Namespace, quota, limit-range, Pod Security, and default-deny network-policy manifests
  - Single-server Kustomize overlay
  - Git exclusions for reports, backups, and kubeconfigs

  Validation passed:

  - 20 Kubernetes resources render successfully
  - 4 namespaces
  - 4 resource quotas
  - 4 limit ranges
  - 8 network policies
  - All PowerShell scripts parse under PowerShell 5.1
  - git diff --check passes

  Before Phase 2, execute the phase gates on the actual machines:

  ./k8s/scripts/measure-capacity.ps1 -SampleSeconds 30
  ./k8s/scripts/backup-compose.ps1 -OutputDirectory E:\server-backups -PullHelperImage

  Then install K3s on Ubuntu following k8s/README.md. After connecting kubectl:

  ./k8s/scripts/validate.ps1 -Cluster
  ./k8s/scripts/bootstrap.ps1 -Apply

  I have not applied anything to a cluster or touched existing Docker volumes. Live execution is gated because this session cannot access Docker Desktop/WMI and no Ubuntu K3s server is currently connected.
  Phase 2 will migrate Gitea and the registry once these gates pass.