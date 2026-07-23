# Local Cloud Dev Platform Implementation Plan

## 1. Purpose

This document describes how to build a reusable local development platform that behaves like a lightweight local version of a mature cloud engineering environment.

The platform should help new repositories onboard with consistent build, test, security, packaging, infrastructure, and deployment practices.

The platform must support:

- Local Git hosting.
- Pull request style development.
- GitHub Actions style workflows.
- Local CI/CD runners.
- Local container registry.
- Local cloud service emulation.
- Infrastructure as Code validation.
- Build quality gates.
- Security scanning.
- Versioning and release notes.
- Repo onboarding templates.
- Vertical slice delivery.
- Multi-agent implementation.
- Open-source tooling only.

This platform should run separately from the local observability server, but both platforms should be able to connect through a shared Docker network when needed.

---

## 2. High-Level Vision

```text
Developer Machine
    |
    | git push / pull request / local workflow run
    v
Local Dev Platform
    |
    |-- Git Server
    |-- CI/CD Runner
    |-- Container Registry
    |-- Artifact Store
    |-- Cloud Emulators
    |-- IaC Validation
    |-- Security Scanning
    |-- Quality Gates
    |-- Release Automation
    |
    v
Local Runtime / Local Cloud Sandbox
```

The platform should make a repository feel like it is being developed inside a professional engineering environment before it reaches GitHub, Azure DevOps, AWS, GCP, or Azure.

---

## 3. Recommended Open-Source Stack

| Capability | Recommended Tool | Purpose |
|---|---|---|
| Git hosting | Forgejo or Gitea | Local Git server, repos, pull requests, issues, packages |
| GitHub Actions compatible CI | Forgejo Actions, Gitea Actions, or act | Run workflow-style pipelines locally |
| Local workflow execution | act | Run `.github/workflows` locally using Docker |
| Programmable CI engine | Dagger | Write CI/CD pipelines that run locally or in remote CI |
| Container registry | Docker Distribution Registry or Harbor | Store local container images |
| AWS cloud emulator | LocalStack Community Edition | Emulate common AWS services locally |
| Azure Storage emulator | Azurite | Emulate Azure Blob, Queue, and Table Storage locally |
| GCP object storage emulator | fake-gcs-server | Emulate Google Cloud Storage locally |
| Infrastructure as Code | OpenTofu | Open-source Terraform-compatible IaC tool |
| Kubernetes local runtime | Kind or k3d | Run local Kubernetes clusters |
| GitOps | Argo CD | GitOps-style deployment into Kubernetes |
| Policy as Code | Open Policy Agent / Conftest | Validate configuration and IaC policies |
| Secret scanning | Gitleaks | Detect secrets before commit or CI merge |
| Container scanning | Trivy or Grype | Scan images and dependencies for vulnerabilities |
| SBOM generation | Syft | Generate software bill of materials |
| Code quality | SonarQube Community Edition | Static code analysis and quality gates |
| Dependency updates | Renovate Community Edition | Automated dependency update proposals |
| Release notes | git-cliff | Generate changelogs from Git history |
| Commit standards | commitlint | Enforce conventional commits |
| Hooks | pre-commit | Local developer guardrails before commit |
| Documentation | MkDocs Material | Local documentation portal |

---

## 4. Important Constraint

There is no exact open-source local replacement for the full Azure DevOps platform.

The correct design is to create a local platform made of open-source components that provide the same engineering capabilities:

```text
Azure DevOps Repos      -> Forgejo / Gitea
Azure Pipelines         -> Gitea Actions / Forgejo Actions / act / Dagger
Azure Artifacts         -> Gitea Packages / Harbor / local registry
Azure Boards            -> Gitea / Forgejo issues and projects
Azure Cloud Services    -> Azurite and local service emulators
AWS Cloud Services      -> LocalStack
GCP Cloud Services      -> fake-gcs-server and local emulators
Terraform Cloud         -> OpenTofu + local backend
```

---

## 5. Relationship to Observability Server

This platform should be separate from the observability server.

Recommended separation:

```text
local-observability-server/
local-cloud-dev-platform/
```

Both can share a Docker network:

```text
local-platform-network
```

The cloud dev platform should emit telemetry into the observability server.

```text
Local CI Runner
Local Cloud Emulator
Local Registry
Local Git Server
        |
        | logs, metrics, health
        v
Local Observability Server
```

---

## 6. Repository Structure

Create a dedicated repository named:

```text
local-cloud-dev-platform
```

Recommended structure:

```text
local-cloud-dev-platform/
│
├── docker-compose.yml
├── .env.example
├── README.md
│
├── docs/
│   ├── implementation-plan.md
│   ├── onboarding-new-repo.md
│   ├── build-principles.md
│   ├── pipeline-standards.md
│   ├── cloud-emulator-guide.md
│   ├── security-gates.md
│   └── troubleshooting.md
│
├── gitea/
│   ├── app.ini
│   └── actions-runner/
│       └── config.yaml
│
├── forgejo/
│   └── app.ini
│
├── registry/
│   └── config.yml
│
├── localstack/
│   └── init/
│       ├── create-sqs.sh
│       ├── create-s3.sh
│       └── create-dynamodb.sh
│
├── azurite/
│   └── README.md
│
├── gcp/
│   └── fake-gcs-server/
│       └── README.md
│
├── opentofu/
│   ├── modules/
│   ├── environments/
│   │   ├── local/
│   │   ├── aws/
│   │   ├── azure/
│   │   └── gcp/
│   └── policies/
│
├── pipelines/
│   ├── templates/
│   │   ├── dotnet-ci.yml
│   │   ├── node-ci.yml
│   │   ├── docker-build.yml
│   │   ├── security-scan.yml
│   │   ├── release.yml
│   │   └── opentofu-validate.yml
│   └── dagger/
│       └── README.md
│
├── repo-templates/
│   ├── dotnet-api-template/
│   ├── react-template/
│   ├── node-api-template/
│   └── worker-service-template/
│
├── scripts/
│   ├── start.ps1
│   ├── stop.ps1
│   ├── restart.ps1
│   ├── health-check.ps1
│   ├── onboard-repo.ps1
│   ├── run-ci-local.ps1
│   └── clean.ps1
│
└── examples/
    ├── dotnet-api/
    ├── node-api/
    ├── react-app/
    └── worker-service/
```

---

# 7. Target Platform Capabilities

## 7.1 Git Server Capability

### Purpose

Provide a local Git server that supports repository hosting, branches, pull requests, issues, and code review.

### Recommended tools

```text
Forgejo
Gitea
```

### Why

These provide a lightweight self-hosted Git platform with a familiar developer experience.

### Required features

```text
Repository creation
Branch protection
Pull requests
Code review
Issues
Labels
Project boards
Packages where needed
Actions-compatible workflows
```

---

## 7.2 CI/CD Capability

### Purpose

Provide local pipeline execution before code is pushed to remote GitHub, Azure DevOps, or cloud CI.

### Recommended tools

```text
act
Forgejo Actions
Gitea Actions
Dagger
```

### Recommended approach

Use two levels:

```text
Level 1: act for running GitHub Actions workflow files locally.
Level 2: Dagger for reusable build logic that can run locally and in CI.
```

This avoids locking build logic inside one CI provider.

### Pipeline principle

Build logic should be portable.

```text
The pipeline should run locally.
The pipeline should run in GitHub Actions.
The pipeline should run in another CI system with minimal changes.
```

---

## 7.3 Local Container Registry Capability

### Purpose

Allow projects to build and push images locally using stable image names.

### Recommended tools

```text
Docker Distribution Registry
Harbor
Gitea Packages
```

### Recommended default

Start simple with Docker Distribution Registry.

Use Harbor later if you need:

```text
Image vulnerability scanning
Image signing policies
Role-based access control
Project-level image management
```

### Example local image naming

```text
localhost:5000/orders-api:local
localhost:5000/identity-api:local
localhost:5000/warehouse-worker:local
```

---

## 7.4 Cloud Emulator Capability

### Purpose

Allow applications to test cloud integration locally without using real cloud accounts.

### AWS local emulation

Recommended tool:

```text
LocalStack Community Edition
```

Useful for local development with:

```text
S3-style storage
SQS-style queues
SNS-style messaging
DynamoDB-style persistence
Lambda-style execution where supported
```

### Azure local emulation

Recommended tool:

```text
Azurite
```

Useful for local development with:

```text
Blob Storage
Queue Storage
Table Storage
```

### GCP local emulation

Recommended tools:

```text
fake-gcs-server
```

Useful for local development with:

```text
Google Cloud Storage style object storage
```

### Design rule

Applications should hide cloud provider details behind ports/interfaces.

```text
Application Service
    -> Storage Port
        -> AWS S3 Adapter
        -> Azure Blob Adapter
        -> GCP Storage Adapter
        -> Local File Adapter
```

This keeps the application testable and cloud-portable.

---

## 7.5 Infrastructure as Code Capability

### Purpose

Allow infrastructure definitions to be validated locally before deployment.

### Recommended tool

```text
OpenTofu
```

### Required commands

```text
tofu fmt
tofu init
tofu validate
tofu plan
```

### Recommended structure

```text
opentofu/
├── modules/
│   ├── service-container/
│   ├── queue/
│   ├── object-storage/
│   └── database/
│
└── environments/
    ├── local/
    ├── aws/
    ├── azure/
    └── gcp/
```

### Principle

The same IaC standards should apply to local and cloud environments.

```text
Format
Validate
Plan
Policy check
Security scan
```

---

## 7.6 Quality Gate Capability

### Purpose

Stop poor quality changes before they become part of the main branch.

### Required quality gates

```text
Restore dependencies
Compile/build
Run unit tests
Run integration tests
Measure coverage
Run static analysis
Run formatting check
Run security scan
Build container image
Generate SBOM
Validate IaC
```

### Recommended tools

```text
SonarQube Community Edition
dotnet format
ESLint
Prettier
EditorConfig
ReportGenerator
commitlint
pre-commit
```

---

## 7.7 Security Gate Capability

### Purpose

Catch secrets, vulnerable packages, vulnerable images, and unsafe IaC before merge.

### Recommended tools

```text
Gitleaks
Trivy
Grype
Syft
Checkov
Conftest
Open Policy Agent
```

### Required security checks

```text
Secret scanning
Dependency vulnerability scanning
Container image scanning
SBOM generation
IaC security validation
Policy as Code validation
```

---

## 7.8 Release Capability

### Purpose

Create predictable versioning, changelogs, and release artifacts.

### Recommended tools

```text
git-cliff
semantic-release
commitlint
Cosign
Syft
```

### Required release outputs

```text
Version number
Changelog
Container image
SBOM
Signed artifact where required
Release notes
```

---

# 8. Mature Build Principles

Every repository onboarded to this platform should follow these principles.

## 8.1 Build once, promote many

A build artifact should be created once and promoted through environments.

Avoid rebuilding different artifacts for each environment.

```text
Build -> Test -> Scan -> Package -> Promote
```

---

## 8.2 Fail fast

Cheap checks should run first.

Recommended order:

```text
1. Validate commit message
2. Restore dependencies
3. Format check
4. Compile
5. Unit tests
6. Static analysis
7. Security scan
8. Integration tests
9. Container build
10. IaC validation
11. Package and publish
```

---

## 8.3 Keep pipelines portable

Pipeline logic should not be trapped inside one vendor.

Preferred pattern:

```text
GitHub Actions YAML calls scripts or Dagger pipeline.
Local runner calls the same scripts or Dagger pipeline.
Remote CI calls the same scripts or Dagger pipeline.
```

---

## 8.4 Make quality measurable

Each repo should report:

```text
Build status
Test count
Test pass/fail
Code coverage
Static analysis result
Security scan result
Container scan result
SBOM location
Artifact version
```

---

## 8.5 No hidden manual steps

If a developer must perform a step repeatedly, script it.

```text
Do not rely on memory.
Do not rely on wiki-only setup.
Do not rely on manual clicking.
```

---

## 8.6 Environment parity

Local development should behave as closely as possible to CI and cloud deployment.

```text
Same Dockerfile
Same build scripts
Same test commands
Same IaC validation
Same quality gates
Same security gates
```

---

## 8.7 Observable pipelines

The local dev platform should send logs and metrics to the observability server.

Track:

```text
Pipeline duration
Pipeline result
Test duration
Failed stage
Image build duration
Security findings count
```

---

# 9. Standard Repository Onboarding Contract

Every new repository should include:

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
scripts/build.ps1
scripts/test.ps1
scripts/lint.ps1
scripts/security-scan.ps1
scripts/package.ps1
scripts/run-local.ps1
```

For .NET projects:

```text
Directory.Build.props
Directory.Packages.props
global.json
src/
tests/
```

---

# 10. Standard CI Pipeline

## Pipeline stages

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

## Example pipeline flow

```text
Developer opens pull request
        |
        v
CI starts
        |
        |-- commit validation
        |-- formatting
        |-- build
        |-- tests
        |-- security scans
        |-- container build
        |-- IaC validation
        v
Quality gate result
        |
        v
Merge allowed or blocked
```

---

# 11. Example GitHub Actions Style Workflow

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

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.0.x'

      - name: Restore dependencies
        run: ./scripts/restore.ps1
        shell: pwsh

      - name: Check formatting
        run: ./scripts/lint.ps1
        shell: pwsh

      - name: Build solution
        run: ./scripts/build.ps1
        shell: pwsh

      - name: Run tests
        run: ./scripts/test.ps1
        shell: pwsh

      - name: Run security scan
        run: ./scripts/security-scan.ps1
        shell: pwsh

      - name: Build container image
        run: ./scripts/package.ps1
        shell: pwsh
```

The same workflow can be tested locally using `act`.

---

# 12. Example Local CI Command

```powershell
./scripts/run-ci-local.ps1
```

Example internal behavior:

```powershell
act pull_request --container-architecture linux/amd64
```

Or, when using Dagger:

```powershell
dagger call build test scan package
```

---

# 13. Multi-Agent Work Breakdown

## Agent 1: Platform Orchestrator

### Responsibility

Own the Docker Compose platform and shared runtime setup.

### Deliverables

```text
docker-compose.yml
.env.example
scripts/start.ps1
scripts/stop.ps1
scripts/restart.ps1
scripts/health-check.ps1
```

### Acceptance Criteria

```text
Platform starts with one command
All services use stable names
All services use restart policies
All required ports are documented
Healthcheck script validates the platform
```

---

## Agent 2: Git Server Slice

### Responsibility

Set up local Git hosting using Forgejo or Gitea.

### Deliverables

```text
Forgejo or Gitea service
Persistent Git volume
Admin bootstrap guide
Repo creation guide
Branch protection guide
```

### Acceptance Criteria

```text
Developer can create a repo
Developer can push code
Developer can open pull request
Developer can review and merge pull request
```

---

## Agent 3: CI Runner Slice

### Responsibility

Set up local CI execution.

### Deliverables

```text
Actions runner service
act local execution script
Dagger optional pipeline example
Pipeline template folder
```

### Acceptance Criteria

```text
A sample workflow runs locally
A pull request workflow can be simulated
A failed test blocks the pipeline
A successful pipeline produces artifacts
```

---

## Agent 4: Container Registry Slice

### Responsibility

Set up local container image publishing.

### Deliverables

```text
Local registry service
Registry config
Image naming guide
Push/pull test script
```

### Acceptance Criteria

```text
Sample app image builds successfully
Image pushes to local registry
Image pulls from local registry
Image can be deployed locally
```

---

## Agent 5: Cloud Emulator Slice

### Responsibility

Set up local AWS, Azure, and GCP-style services.

### Deliverables

```text
LocalStack service
Azurite service
fake-gcs-server service
Cloud emulator guide
Sample provisioning scripts
```

### Acceptance Criteria

```text
App can write to local S3-style storage
App can write to Azure Blob-style storage
App can write to GCP Storage-style storage
App can use local queue where supported
```

---

## Agent 6: Infrastructure as Code Slice

### Responsibility

Set up OpenTofu validation and environment structure.

### Deliverables

```text
OpenTofu folder structure
Local environment example
AWS environment example
Azure environment example
GCP environment example
IaC validation script
Policy checks
```

### Acceptance Criteria

```text
tofu fmt passes
tofu validate passes
tofu plan runs for local environment
Policy checks run successfully
```

---

## Agent 7: Quality Gate Slice

### Responsibility

Implement build quality gates for onboarded repositories.

### Deliverables

```text
Build scripts
Test scripts
Lint scripts
Coverage scripts
SonarQube configuration
EditorConfig
```

### Acceptance Criteria

```text
Build fails on compilation errors
Build fails on failing tests
Build fails on formatting issues
Coverage report is generated
Static analysis runs successfully
```

---

## Agent 8: Security Gate Slice

### Responsibility

Implement local security checks.

### Deliverables

```text
Gitleaks config
Trivy scan script
Grype scan script
Syft SBOM script
Checkov IaC scan script
Conftest policy script
```

### Acceptance Criteria

```text
Secrets are detected
Vulnerable images are detected
SBOM is generated
IaC policy violations are detected
Security results are visible in pipeline output
```

---

## Agent 9: Release Automation Slice

### Responsibility

Implement versioning, changelog, and release artifact generation.

### Deliverables

```text
git-cliff configuration
commitlint configuration
release workflow template
artifact naming standard
versioning guide
```

### Acceptance Criteria

```text
Conventional commits are validated
Changelog is generated
Version is calculated predictably
Release artifact is produced
```

---

## Agent 10: Repo Template and Onboarding Slice

### Responsibility

Create reusable repository templates and onboarding automation.

### Deliverables

```text
repo-templates/dotnet-api-template
repo-templates/react-template
repo-templates/node-api-template
repo-templates/worker-service-template
scripts/onboard-repo.ps1
docs/onboarding-new-repo.md
```

### Acceptance Criteria

```text
A new repo can be created from a template
Required files are included
CI workflow is included
Security config is included
Build scripts are included
README explains how to run locally
```

---

# 14. Vertical Slice Delivery Plan

## Slice 1: Local Platform Bootstrap

### Outcome

A developer can start the local platform with one command.

### Includes

```text
Docker Compose
Shared network
Git server
Registry
Basic scripts
```

### Done when

```text
./scripts/start.ps1
```

starts the platform successfully.

---

## Slice 2: Repo Hosting and Pull Requests

### Outcome

A developer can create a repository, push code, and open a pull request locally.

### Includes

```text
Forgejo or Gitea
Repository setup
Branch protection guide
Pull request flow
```

### Done when

A sample repo can be reviewed and merged locally.

---

## Slice 3: Local CI Execution

### Outcome

A project can run a CI workflow locally.

### Includes

```text
act
Actions runner
CI workflow templates
Build scripts
Test scripts
```

### Done when

A sample `.github/workflows/ci.yml` runs locally and reports success or failure.

---

## Slice 4: Quality Gates

### Outcome

A bad change is blocked before merge.

### Includes

```text
Build gate
Test gate
Format gate
Coverage gate
Static analysis gate
```

### Done when

A failing test or formatting issue blocks the pipeline.

---

## Slice 5: Security Gates

### Outcome

Secrets, vulnerable packages, and vulnerable images are detected locally.

### Includes

```text
Gitleaks
Trivy
Grype
Syft
Checkov
Conftest
```

### Done when

A seeded test secret or vulnerable image causes the pipeline to fail.

---

## Slice 6: Local Cloud Emulation

### Outcome

Applications can develop against local cloud-like services.

### Includes

```text
LocalStack
Azurite
fake-gcs-server
Provisioning scripts
Sample app adapters
```

### Done when

A sample app writes to local object storage and local queues where supported.

---

## Slice 7: Infrastructure as Code Validation

### Outcome

Infrastructure changes are validated locally before merge.

### Includes

```text
OpenTofu
IaC modules
Local environment
Cloud environment folders
Policy checks
```

### Done when

`tofu validate` and policy checks run in CI.

---

## Slice 8: Container Build and Registry

### Outcome

Applications can build, scan, and push images locally.

### Includes

```text
Dockerfile standards
Local registry
Image naming standard
Container scan
SBOM generation
```

### Done when

A sample image is built, scanned, pushed, and pulled from the local registry.

---

## Slice 9: Release Automation

### Outcome

A repository can produce versioned release artifacts and changelogs.

### Includes

```text
Conventional commits
git-cliff
semantic versioning
artifact naming
release workflow
```

### Done when

A sample release produces a version, changelog, image, and artifact.

---

## Slice 10: Repo Onboarding Automation

### Outcome

A new project can be onboarded quickly using templates.

### Includes

```text
Repo templates
Onboarding script
Pipeline templates
Security config
Documentation templates
```

### Done when

A new repository can be created and pass the default pipeline with minimal manual configuration.

---

# 15. Standard New Repo Onboarding Flow

## Step 1: Create repo from template

```powershell
./scripts/onboard-repo.ps1 -ProjectName orders-api -Template dotnet-api
```

## Step 2: Start local platform

```powershell
./scripts/start.ps1
```

## Step 3: Push repo to local Git server

```powershell
git remote add local http://localhost:3000/engineering/orders-api.git
git push local main
```

## Step 4: Run CI locally

```powershell
./scripts/run-ci-local.ps1
```

## Step 5: Build and publish local image

```powershell
./scripts/package.ps1
```

## Step 6: Deploy into local runtime

```powershell
docker compose up -d
```

## Step 7: Verify through observability server

```text
Open Grafana
Check service logs
Check service metrics
Check traces
Check pipeline health
```

---

# 16. Suggested Docker Compose Services

```text
gitea or forgejo
gitea-runner or forgejo-runner
registry
localstack
azurite
fake-gcs-server
sonarqube
postgres
redis
kind or k3d control tooling
```

Optional services:

```text
harbor
argo-cd
minio
nexus repository oss
verdaccio
renovate
```

---

# 17. Local Ports

Recommended stable ports:

```text
Gitea / Forgejo:       http://localhost:3000
Gitea SSH:             localhost:2222
Local registry:        http://localhost:5000
LocalStack:            http://localhost:4566
Azurite Blob:          http://localhost:10000
Azurite Queue:         http://localhost:10001
Azurite Table:         http://localhost:10002
fake-gcs-server:       http://localhost:4443
SonarQube:             http://localhost:9000
```

If the observability server also uses Grafana on `3001`, keep the Git server on `3000`.

---

# 18. Integration with Observability Platform

The local cloud dev platform should be observable.

Track:

```text
Git server health
Runner health
Pipeline duration
Pipeline failures
Registry health
Cloud emulator health
SonarQube health
Security scan failures
```

Recommended labels:

```text
service.name
service.type
pipeline.name
pipeline.stage
repository.name
branch.name
commit.sha
build.result
```

---

# 19. Definition of Done

The platform is complete when:

```text
A developer can start the platform with one command.
A developer can create or import a repo locally.
A developer can open a pull request locally.
A CI workflow can run locally.
A bad change can be blocked by quality gates.
A secret can be detected before merge.
A vulnerable image can be detected before release.
A container image can be pushed to the local registry.
An application can use local AWS-style services.
An application can use local Azure Storage-style services.
An application can use local GCP Storage-style services.
Infrastructure can be validated with OpenTofu.
A changelog and release artifact can be generated.
New repos can onboard using templates.
The platform can emit health signals into the observability server.
```

---

# 20. Recommended Build Standard for Every Repo

Every onboarded repo should have these commands:

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

Every command should:

```text
Fail clearly
Return non-zero exit code on failure
Avoid hidden dependencies
Print useful diagnostics
Work locally and in CI
```

---

# 21. Implementation Principle

Do not build this as one big platform first.

Build it vertically:

```text
Repo -> Build -> Test -> Scan -> Package -> Deploy locally -> Observe
```

Then repeat for each template:

```text
.NET API
Node API
React app
Worker service
Infrastructure module
```

This keeps the platform practical, reliable, and easy to extend.

