# Onboarding a New Repo

Every onboarded repository must be runnable, testable, scannable, packageable, and explainable from scripts.

## Create From Template

```powershell
./scripts/onboard-repo.ps1 -ProjectName orders-api -Template dotnet-api
```

Supported template targets:

```text
dotnet-api
node-api
react
worker-service
```

## Start the Platform

```powershell
./scripts/start.ps1
./scripts/health-check.ps1
```

## Push to Local Git

```powershell
git remote add local http://localhost:3000/engineering/orders-api.git
git push local main
```

Open the repository at:

```text
http://localhost:3000
```

Create a pull request before merging into `main`.

## Required Repo Files

```text
.github/workflows/ci.yml
.github/workflows/release.yml
.github/workflows/security.yml
.editorconfig
.gitleaks.toml
.pre-commit-config.yaml
.platform/addons.yaml
commitlint.config.js
Dockerfile
docker-compose.yml
k8s/base/kustomization.yaml
k8s/base/workload.yaml
k8s/base/network-policy.yaml
k8s/overlays/local/kustomization.yaml
k8s/overlays/local/namespace.yaml
README.md
CHANGELOG.md
docs/architecture.md
docs/runbook.md
scripts/restore.ps1
scripts/build.ps1
scripts/test.ps1
scripts/lint.ps1
scripts/security-scan.ps1
scripts/package.ps1
scripts/run-local.ps1
scripts/run-ci-local.ps1
```

For .NET repositories, also include:

```text
Directory.Build.props
Directory.Packages.props
global.json
src/
tests/
```

## Required Script Contract

Every script must:

```text
Fail clearly.
Return non-zero on failure.
Print useful diagnostics.
Avoid hidden machine dependencies.
Work locally and in CI.
```

## First Validation

From the new repository:

```powershell
./scripts/restore.ps1
./scripts/lint.ps1
./scripts/build.ps1
./scripts/test.ps1
./scripts/security-scan.ps1
./scripts/package.ps1
./scripts/run-ci-local.ps1
kubectl kustomize ./k8s/base
kubectl kustomize ./k8s/overlays/local
```

The Kubernetes base must render without credentials and must include explicit
resources, probes, a non-root security context, no service-account token unless
required, OTLP configuration, and default-deny-aware network policy. Add
environment-specific namespace, ingress host, image tag/digest, and Secret
references in an overlay rather than editing the base.

The included `local` overlay creates a project-specific namespace with
Restricted Pod Security enforcement. Update its image tag to an immutable
release tag or digest before deployment.

Optional platform services are deny-by-default. Declare only services required
by integration tests or a manually triggered analysis in
`.platform/addons.yaml`. Valid names are `azurite`, `fake-gcs`, `localstack`,
and `sonarqube`; ordinary build, lint, unit-test, and packaging jobs must leave
the list empty.

Platform maintainers can validate all four generated repository contracts with:

```powershell
./scripts/validate-repo-templates.ps1
```

## Local Image Naming

Use stable local names:

```text
localhost:5000/orders-api:local
localhost:5000/identity-api:local
localhost:5000/warehouse-worker:local
```
