# Local Cloud Dev Platform

Local Cloud Dev Platform is a reusable local engineering platform for repository hosting, pull-request workflows, CI/CD, image publishing, cloud service emulation, IaC validation, security scanning, and release automation.

It is built from open-source tools and is intended to feel like a small local version of a mature cloud delivery environment before code reaches GitHub, Azure DevOps, AWS, GCP, or Azure.

## Platform Shape

Recommended services:

| Capability | Default tool |
|---|---|
| Git hosting and pull requests | Forgejo or Gitea |
| Local workflow execution | act |
| Portable CI logic | Dagger |
| Container registry | Docker Distribution Registry |
| AWS emulation | LocalStack Community Edition |
| Azure Storage emulation | Azurite |
| GCP object storage emulation | fake-gcs-server |
| IaC | OpenTofu |
| Policy checks | OPA / Conftest |
| Secret scanning | Gitleaks |
| Image and dependency scanning | Trivy or Grype |
| SBOM | Syft |
| Static analysis | SonarQube Community Edition |
| Release notes | git-cliff |

## Standard Commands

Start the platform:

```powershell
./scripts/start.ps1
```

Check health:

```powershell
./scripts/health-check.ps1
```

Run local CI for an onboarded repository:

```powershell
./scripts/run-ci-local.ps1
```

Stop the platform:

```powershell
./scripts/stop.ps1
```

## Stable Local URLs

| Service | URL |
|---|---|
| Gitea / Forgejo | http://localhost:3000 |
| Git SSH | localhost:2222 |
| Local registry | http://localhost:5000 |
| LocalStack | http://localhost:4566 |
| Azurite Blob | http://localhost:10000 |
| Azurite Queue | http://localhost:10001 |
| Azurite Table | http://localhost:10002 |
| fake-gcs-server | http://localhost:4443 |
| SonarQube | http://localhost:9000 |

## Documentation

- [Implementation Plan](docs/implementation-plan.md)
- [Onboarding a New Repo](docs/onboarding-new-repo.md)
- [Build Principles](docs/build-principles.md)
- [Pipeline Standards](docs/pipeline-standards.md)
- [Cloud Emulator Guide](docs/cloud-emulator-guide.md)
- [Security Gates](docs/security-gates.md)
- [Troubleshooting](docs/troubleshooting.md)

## Done Means

The platform is useful when a developer can start it with one command, create or import a repository, open a pull request, run CI locally, block bad changes with quality and security gates, publish an image to the local registry, use cloud emulators, validate infrastructure, and produce release notes or artifacts.
