# Phase H4 Seven-Day Soak Runbook

## Acceptance window

H4 requires at least 168 elapsed hours and successful representative cycles on
seven distinct UTC calendar days. The completion evaluator refuses to pass
early. DNS cutover and rollback-asset retirement remain prohibited until the
soak passes and the operator gives separate explicit approval.

## Daily representative cycle

`Server-Platform-H4-Daily-Soak` runs daily at 07:00 as `SYSTEM`. Each cycle:

1. Runs all platform health and host/guest capacity gates.
2. Requires the newest logical backup to be no more than 26 hours old and
   verifies its hashes and isolated extraction.
3. Runs cheap checks, socketless image build/push, Trivy scanning, SBOM
   generation, and artifact publication through the capacity-one runner.
4. Starts, tests, and stops Azurite, fake GCS, LocalStack, and
   SonarQube/PostgreSQL sequentially.
5. Captures pod restart counters, active Alertmanager alerts, and Kubernetes
   Warning events.

State and immutable daily reports are stored under
`D:\HyperV\operations\h4-soak`. A second invocation on the same UTC day reads
the existing report and does not repeat the workload.

`Server-Platform-H4-Completion-Gate` runs once, 168 hours and 15 minutes after
the recorded start. It writes `completion.json` and exits non-zero if any gate
is still unmet.

## Operator checks

```powershell
Get-ScheduledTask -TaskName Server-Platform-H4-Daily-Soak
Get-ScheduledTask -TaskName Server-Platform-H4-Completion-Gate
Get-ScheduledTaskInfo -TaskName Server-Platform-H4-Daily-Soak
Get-Content -Raw D:\HyperV\operations\h4-soak\state.json
Get-ChildItem D:\HyperV\operations\h4-soak\cycle-*.json

./k8s/operations/complete-h4-soak.ps1
```

The last command is expected to exit non-zero before 168 hours. At the end of
the window it requires seven successful days, no failed cycles, no active
alerts, and no observed restart-counter growth. Review all recorded Warning
events even when the automated gate passes.

Any failed daily cycle is an incident. Correct the underlying problem, retain
the failed report, and restart a new seven-day window rather than overwriting
evidence.

The pre-window validation on 2026-07-25 found that Linux did not return
released dynamic memory to Hyper-V promptly after sequential add-ons. The VM
maximum was therefore tightened from 8 GiB to 7 GiB, above H3's observed
6.84-GiB peak, so repeated cycles cannot consume the Windows reserve merely
through retained balloon assignment.

The formal window started at `2026-07-25T18:33:20Z`. Its earliest completion
evaluation is `2026-08-01T20:48:20+02:00`.
