# Pipeline Standards

Pipelines must run locally and in remote CI with minimal differences.

## Standard Stages

Use this order unless a repo has a specific reason to differ:

```text
Checkout
Validate commit
Restore dependencies
Format check
Build
Unit tests
Coverage
Static analysis
Security scan
Integration tests
Container build
Container scan
SBOM generation
IaC validation
Package
Publish artifact
Generate changelog
```

## Required Local Commands

Every repo should expose:

```powershell
./scripts/restore.ps1
./scripts/build.ps1
./scripts/test.ps1
./scripts/lint.ps1
./scripts/security-scan.ps1
./scripts/package.ps1
./scripts/run-local.ps1
./scripts/run-ci-local.ps1
```

## Local GitHub Actions Run

Use `act` to test workflow files locally:

```powershell
act pull_request --container-architecture linux/amd64
```

Wrap it in:

```powershell
./scripts/run-ci-local.ps1
```

## Portable Pipeline Logic

For reusable logic, use Dagger or scripts:

```powershell
dagger call build test scan package
```

CI YAML should orchestrate; scripts or Dagger should perform the build work.

## Example Workflow

```yaml
name: ci

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout source
        uses: actions/checkout@v4

      - name: Restore dependencies
        run: ./scripts/restore.ps1
        shell: pwsh

      - name: Check formatting
        run: ./scripts/lint.ps1
        shell: pwsh

      - name: Build
        run: ./scripts/build.ps1
        shell: pwsh

      - name: Test
        run: ./scripts/test.ps1
        shell: pwsh

      - name: Security scan
        run: ./scripts/security-scan.ps1
        shell: pwsh

      - name: Package
        run: ./scripts/package.ps1
        shell: pwsh
```

## Merge Rule

Do not merge when any required gate fails:

```text
Commit validation
Format
Build
Tests
Coverage
Static analysis
Security scans
Container scan
IaC validation
Policy checks
```
