# Remaining Platform Phases

Updated 2026-07-25 after Phase F completion.

## Current position

Phases A through G and H1/H2 are complete. Phase H began before Phase G by
explicit operator decision; Phase G subsequently passed its isolated and
sequential acceptance gates. H3 resilience acceptance is next. Final cutover
and retirement of rollback assets must still wait for H3 and the seven-day
soak.

## Phase G: optional development services — complete

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

Completed 2026-07-25. The final sequential report is
`D:\HyperV\operations\addons\phase-g-20260725T125130Z.json`.

## Phase H: operations and cutover

### H1: repository templates and onboarding — complete

- Add Kubernetes bases/overlays to every repository template.
- Preserve local Docker Compose workflows.
- Add explicit resources, probes, Restricted Pod Security, default-deny-aware
  NetworkPolicies, and OTLP configuration.
- Extend onboarding validation and documentation.

Completed 2026-07-25. All four templates have a Kubernetes base and local
overlay, retain Docker Compose workflows, and pass generated-repository
contract validation.

### H2: operational automation — complete

- Add daily platform health checks.
- Add scheduled logical backups and bounded cleanup.
- Add registry and CI artifact retention enforcement.
- Add monthly restore and upgrade rehearsal procedures.
- Ensure every automation path has structured failure diagnostics.

Completed 2026-07-25. Windows schedules now run daily health and logical
backups plus guarded weekly Registry maintenance. Kubernetes enforces 14-day CI
artifact retention. Backup hashes and isolated extraction passed, and the
monthly restore/upgrade rehearsal procedure is documented.

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

1. Run H3 resilience acceptance.
2. Run the H4 seven-day representative soak.
3. Review cutover gates and request explicit rollback-asset retirement approval.
