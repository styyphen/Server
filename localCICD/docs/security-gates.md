# Security Gates

Security gates run before merge and before release. A failing security gate must return a non-zero exit code.

## Required Checks

```text
Secret scanning
Dependency vulnerability scanning
Container image scanning
SBOM generation
IaC security validation
Policy as Code validation
```

## Recommended Tools

| Check | Tool |
|---|---|
| Secrets | Gitleaks |
| Dependencies | Trivy or Grype |
| Container images | Trivy or Grype |
| SBOM | Syft |
| IaC security | Checkov |
| Policy as Code | OPA / Conftest |

## Standard Command

Every repo must expose:

```powershell
./scripts/security-scan.ps1
```

That script should run the repo's applicable checks and fail on high-confidence findings.

## Secret Scanning

Expected files:

```text
.gitleaks.toml
.pre-commit-config.yaml
```

Run locally before commit and in CI:

```powershell
gitleaks detect --source . --config .gitleaks.toml
```

## Container Scanning

Build the image once, then scan the same image that will be pushed:

```powershell
./scripts/package.ps1
trivy image localhost:5000/orders-api:local
```

## SBOM

Generate an SBOM for each release artifact or container image:

```powershell
syft localhost:5000/orders-api:local -o spdx-json
```

Publish or store the SBOM with the artifact.

## IaC and Policy

Run OpenTofu validation before policy checks:

```powershell
tofu fmt -check
tofu init
tofu validate
tofu plan
conftest test opentofu/
```

## Acceptance Test

Seed a test-only secret or vulnerable image in a disposable branch and verify:

```text
Pipeline fails.
Failure message names the gate.
Finding is visible in pipeline output.
Merge is blocked.
```
