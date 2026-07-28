# Dagger Pipeline Guide

Dagger is the portable CI layer for this platform. GitHub Actions, Forgejo Actions, Gitea Actions, and local shells should call the same Dagger functions where a repository needs build logic that is more complex than a workflow template.

## When to Use Dagger

Use workflow templates directly for standard restore, lint, test, scan, image build, and release jobs. Add Dagger when a repository needs shared pipeline code across several CI providers, multi-language orchestration, service containers, or reusable packaging logic.

## Recommended Module Contract

Each onboarded repository can expose these functions:

```text
restore
lint
build
test
scan
package
publish
release
```

Keep the function names stable so local and remote runners can use the same commands.

## Local Execution

Install the Dagger CLI, then run one or more functions from the repository root:

```powershell
dagger call restore lint build test scan package
```

The platform runner script can call Dagger instead of `act`:

```powershell
./scripts/run-ci-local.ps1 -Engine dagger -DaggerArgs "restore lint build test scan package"
```

## GitHub Actions Pattern

Use a workflow step like this when a repository has a Dagger module:

```yaml
- name: Run portable pipeline
  run: dagger call restore lint build test scan package
  shell: bash
```

## Standards

- Keep Dagger functions deterministic and non-interactive.
- Write artifacts under `artifacts/`.
- Return non-zero exit codes for failed quality or security gates.
- Use the same Dockerfile, test commands, IaC paths, and scan policy locally and in CI.
- Emit useful stage logs so local runner output can be forwarded to the observability platform later.
