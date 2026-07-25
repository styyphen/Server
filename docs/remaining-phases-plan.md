# Remaining Platform Phases

Updated 2026-07-25 after Phase F completion.

## Current position

Phases A through F are complete. Phase H will begin before Phase G by explicit
operator decision. This is safe while Phase H work remains limited to
reversible templates, onboarding, health, backup, cleanup, and validation
automation. Final cutover and retirement of rollback assets must still wait for
Phase G acceptance and the seven-day soak.

## Phase G: optional development services

1. Build a common add-on lifecycle contract with `start`, `stop`, `status`,
   readiness, timeout, and acceptance-test behavior.
2. Package Azurite, fake GCS, LocalStack, and SonarQube/PostgreSQL independently.
3. Keep every add-on at zero replicas by default.
4. Enforce one heavyweight add-on at a time.
5. Give every workload explicit requests, limits, storage bounds, probes,
   Pod Security settings, and NetworkPolicies.
6. Update pipeline templates so repositories request only declared services.
7. Test each add-on in isolation and verify reliable return to zero.

Recommended order:

1. Lifecycle framework
2. Azurite
3. Fake GCS
4. LocalStack
5. SonarQube/PostgreSQL
6. Sequential resource and recovery acceptance

Phase G exit gate: every optional service passes independently without
degrading Gitea, CI, Registry, or observability.

## Phase H: operations and cutover

### H1: repository templates and onboarding

- Add Kubernetes bases/overlays to every repository template.
- Preserve local Docker Compose workflows.
- Add explicit resources, probes, Restricted Pod Security, default-deny-aware
  NetworkPolicies, and OTLP configuration.
- Extend onboarding validation and documentation.

### H2: operational automation

- Add daily platform health checks.
- Add scheduled logical backups and bounded cleanup.
- Add registry and CI artifact retention enforcement.
- Add monthly restore and upgrade rehearsal procedures.
- Ensure every automation path has structured failure diagnostics.

### H3: resilience acceptance

- Controlled VM reboot and workload recovery.
- Disk-pressure warning and eviction behavior.
- Sequential pipelines and optional add-ons.
- Backup/restore verification.
- Windows and guest capacity gates.

### H4: soak and cutover

- Run a seven-day representative soak.
- Review alerts, storage growth, restarts, and backup results.
- Cut over stable DNS only after all gates pass.
- Retain Compose volumes, WSL rollback state, old VM disks, and backups until
  explicit retirement approval.

Phase H exit gate: the full platform passes reboot, disk-pressure,
backup/restore, sequential workload, and seven-day soak tests.

## Guardrails for starting H before G

- Do not perform final DNS cutover.
- Do not retire or delete rollback assets.
- Do not mark Phase H complete until Phase G passes.
- Keep templates compatible with add-ons being absent.
- Merge and deploy H work in small reversible increments.

## Immediate execution order

1. H1 Kubernetes repository templates and onboarding validation.
2. H2 read-only daily health automation.
3. H2 backup and cleanup automation.
4. Pause H final acceptance, complete Phase G, then resume H3 and H4.
