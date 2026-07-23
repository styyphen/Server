# Build Principles

These rules apply to every repository onboarded to the platform.

## Build Once, Promote Many

Create one artifact and promote it through environments.

```text
Build -> Test -> Scan -> Package -> Promote
```

Do not rebuild different artifacts for `local`, `test`, `staging`, and `prod`.

## Fail Fast

Run cheap checks before expensive checks:

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

## Keep Pipelines Portable

Keep build logic in scripts or Dagger, then call it from CI.

```text
GitHub Actions YAML -> scripts or Dagger
Local runner -> same scripts or Dagger
Remote CI -> same scripts or Dagger
```

## Make Quality Measurable

Each pipeline should print or publish:

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

## Script Repeated Work

If a developer must do a step repeatedly, add a script.

```text
No memory-only setup.
No wiki-only setup.
No required manual clicking.
```

## Keep Environment Parity

Local, CI, and cloud deployment should use the same:

```text
Dockerfile
Build scripts
Test commands
IaC validation
Quality gates
Security gates
```

## Make Pipelines Observable

Emit logs and metrics to the observability server when it is connected through the shared Docker network.

Track:

```text
Pipeline duration
Pipeline result
Test duration
Failed stage
Image build duration
Security findings count
```
