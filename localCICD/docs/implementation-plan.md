# Implementation Plan

Build the platform vertically. Do not wait for every service to exist before proving the developer workflow.

## Target Outcome

A repository can move through this local path:

```text
Repo -> Build -> Test -> Scan -> Package -> Deploy locally -> Observe
```

Repeat the path for each template:

```text
.NET API
Node API
React app
Worker service
Infrastructure module
```

## Repository Layout

Use this platform structure:

```text
local-cloud-dev-platform/
|-- docker-compose.yml
|-- .env.example
|-- README.md
|-- docs/
|-- gitea/ or forgejo/
|-- registry/
|-- localstack/
|-- azurite/
|-- gcp/fake-gcs-server/
|-- opentofu/
|-- pipelines/
|-- repo-templates/
|-- scripts/
`-- examples/
```

## Delivery Slices

1. Bootstrap Docker Compose, shared network, Git server, registry, and platform scripts.
2. Enable local repo hosting, branch protection, pull requests, and review.
3. Run local CI with `act`, Actions runners, and workflow templates.
4. Add quality gates for build, test, format, coverage, and static analysis.
5. Add security gates for secrets, dependencies, images, SBOM, IaC, and policy.
6. Add LocalStack, Azurite, and fake-gcs-server with provisioning examples.
7. Add OpenTofu validation, environments, modules, and policy checks.
8. Build, scan, push, and pull images from the local registry.
9. Add conventional commits, changelog generation, versioning, and release artifacts.
10. Add repo templates and `scripts/onboard-repo.ps1`.

## Platform Services

Start with:

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
```

Add later when needed:

```text
harbor
argo-cd
minio
nexus repository oss
verdaccio
renovate
```

## Acceptance Checklist

Run these checks as the platform matures:

```powershell
./scripts/start.ps1
./scripts/health-check.ps1
./scripts/onboard-repo.ps1 -ProjectName sample-api -Template dotnet-api
./scripts/run-ci-local.ps1
```

Then verify:

```text
Repo can be pushed to local Git.
Pull request can be opened and merged.
Failed tests block merge.
Seeded secrets are detected.
Image builds and pushes to localhost:5000.
Cloud emulator write/read works.
tofu validate and policy checks pass.
Changelog and release artifact can be generated.
Telemetry reaches the observability server when connected.
```
