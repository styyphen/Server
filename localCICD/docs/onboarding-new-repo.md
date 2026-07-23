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
commitlint.config.js
Dockerfile
docker-compose.yml
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
```

## Local Image Naming

Use stable local names:

```text
localhost:5000/orders-api:local
localhost:5000/identity-api:local
localhost:5000/warehouse-worker:local
```
