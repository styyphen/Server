# Junior Operator Guide: Start, Stop, and Suspend Safely

This guide explains how to operate the local Hyper-V/K3s platform without
losing observability, backups, CI quality gates, or recovery evidence. Run all
PowerShell commands from an elevated terminal on the Windows server.

## 1. Understand what you are controlling

There are four different control targets. Do not mix their commands.

| Target | Examples | Safe control method |
|---|---|---|
| Optional add-on | Azurite, fake GCS, LocalStack, SonarQube | `manage-addon.ps1` |
| Scheduled automation | health, backup, Registry maintenance, H4 soak | Scheduled Task cmdlets |
| CI workload | representative pipeline and Kubernetes Jobs | runner script and `kubectl` |
| Whole platform | Hyper-V VM `local-k3s-server` | Hyper-V cmdlets |

Gitea, Registry, Prometheus, Alertmanager, Grafana, Loki, Tempo, the OpenTelemetry
Collector, Promtail, and core K3s services are platform services. Do not scale
or delete them to save resources. Optional add-ons are already zero replicas
when unused.

## 2. Open the correct shell

1. Open **Windows PowerShell as Administrator**.
2. Move to the repository.
3. Define the approved Kubernetes client paths for this shell.

```powershell
Set-Location C:\Server

$Kubectl = 'D:\HyperV\tools\kubectl-v1.36.1.exe'
$Kubeconfig = 'D:\HyperV\credentials\k3s-admin.yaml'
```

Never print, copy into Git, or edit the kubeconfig and credential files under
`D:\HyperV\credentials`.

## 3. Always run the pre-change checks

Record the current Git state, VM state, cluster state, active add-ons, and
automation state.

```powershell
git status --short --branch

Get-VM -Name local-k3s-server |
  Select-Object Name, State, MemoryAssigned, MemoryDemand

& $Kubectl --kubeconfig $Kubeconfig get nodes
& $Kubectl --kubeconfig $Kubeconfig get pods -A

Get-ScheduledTask -TaskName 'Server-Platform-*' |
  Select-Object TaskName, State

@('azurite', 'fake-gcs', 'localstack', 'sonarqube') | ForEach-Object {
  .\k8s\operations\manage-addon.ps1 -Name $_ -Action status
}
```

Run the full health gate before a planned platform-level change:

```powershell
.\k8s\operations\invoke-daily-health.ps1
if (-not $?) { throw 'Pre-change health failed. Stop and investigate.' }
```

Do not proceed if the working tree contains changes you do not understand, the
node is not Ready, a core pod is unhealthy, or the health script fails.

## 4. Start an optional add-on

Only one optional add-on may run at a time. The wrapper enforces that rule.

### Start and verify

Replace `localstack` with `azurite`, `fake-gcs`, or `sonarqube` as needed.

```powershell
.\k8s\operations\manage-addon.ps1 -Name localstack -Action start
.\k8s\operations\manage-addon.ps1 -Name localstack -Action status
.\k8s\operations\manage-addon.ps1 -Name localstack -Action test
```

The preferred command for normal use starts the add-on, tests its API, and
returns it to zero replicas automatically:

```powershell
.\k8s\operations\manage-addon.ps1 -Name localstack -Action accept
```

### Confirm observability and capacity

```powershell
.\k8s\operations\invoke-daily-health.ps1
& $Kubectl --kubeconfig $Kubeconfig top node
& $Kubectl --kubeconfig $Kubeconfig -n observability get pods
```

The Windows host must retain at least 4 GiB free memory, and the node must
retain at least 15% free filesystem space. The health script enforces both.

## 5. Stop an optional add-on

Stopping an add-on means returning its controller to zero replicas. It does not
delete its PVC or data.

```powershell
.\k8s\operations\manage-addon.ps1 -Name localstack -Action stop
.\k8s\operations\manage-addon.ps1 -Name localstack -Action status
```

Confirm every optional workload is stopped:

```powershell
& $Kubectl --kubeconfig $Kubeconfig -n cloud-emulators `
  get deployment,statefulset
```

Every add-on should show `0/0`. Never use `kubectl delete pvc` to stop a
service.

## 6. Suspend scheduled automation

`Disable-ScheduledTask` prevents future runs. It does not stop a run that is
already executing.

### Inspect first

```powershell
$TaskName = 'Server-Platform-H4-Daily-Soak'

Get-ScheduledTask -TaskName $TaskName
Get-ScheduledTaskInfo -TaskName $TaskName
```

### Disable future runs

```powershell
Disable-ScheduledTask -TaskName $TaskName
Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State
```

### Stop a currently running task

Use this only for an incident, such as an unsafe resource condition. Preserve
its partial report before retrying.

```powershell
Stop-ScheduledTask -TaskName $TaskName
Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State
Get-ScheduledTaskInfo -TaskName $TaskName
```

Never suspend these casually:

- `Server-Platform-Daily-Backup`
- `Server-Platform-Daily-Health`
- `Server-Platform-Weekly-Registry-Maintenance`
- `Server-Platform-H4-Daily-Soak` while H4 is active

Disabling or interrupting H4 breaks soak continuity. Retain the evidence and
restart a fresh seven-day window after the incident is resolved.

## 7. Resume or manually start scheduled automation

Enable future runs, then verify the next run time:

```powershell
$TaskName = 'Server-Platform-H4-Daily-Soak'

Enable-ScheduledTask -TaskName $TaskName
Get-ScheduledTaskInfo -TaskName $TaskName |
  Select-Object LastRunTime, LastTaskResult, NextRunTime
```

Start one run immediately:

```powershell
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 5
Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State
```

After it finishes, `LastTaskResult` must be `0`:

```powershell
Get-ScheduledTaskInfo -TaskName $TaskName |
  Select-Object LastRunTime, LastTaskResult, NextRunTime
```

Read the structured report instead of trusting task status alone:

```powershell
Get-Content -Raw D:\HyperV\operations\health\latest.json
Get-ChildItem D:\HyperV\operations\h4-soak\cycle-*.json |
  Sort-Object Name -Descending |
  Select-Object -First 1 |
  Get-Content -Raw
```

## 8. Run and observe CI safely

The runner has capacity one. Do not start overlapping representative runs.

```powershell
& $Kubectl --kubeconfig $Kubeconfig -n ci-jobs exec deployment/gitea-runner -- `
  /opt/ci/run-representative-pipeline.sh
```

Inspect Jobs, pods, and structured logs:

```powershell
& $Kubectl --kubeconfig $Kubeconfig -n ci-jobs get jobs,pods
& $Kubectl --kubeconfig $Kubeconfig -n ci-jobs get events `
  --sort-by=.lastTimestamp
```

Do not bypass the cheap checks, vulnerability scan, SBOM, or artifact output to
make a failed build appear successful. Fix the cause and rerun the complete
pipeline.

## 9. Suspend the whole VM

Saving or pausing the VM stops Kubernetes scheduling, monitoring, alert
evaluation, scheduled backups that depend on the guest, and application
availability. Use it only for a short, planned host-maintenance window.

### Preferred short suspension: save the VM

```powershell
.\k8s\operations\invoke-daily-health.ps1
Save-VM -Name local-k3s-server
Get-VM -Name local-k3s-server | Select-Object Name, State
```

Resume a saved VM:

```powershell
Start-VM -Name local-k3s-server
Get-VM -Name local-k3s-server | Select-Object Name, State
```

### Pause and resume CPU execution

Use pause only for a very brief diagnostic action. Network requests will hang
while the VM is paused.

```powershell
Suspend-VM -Name local-k3s-server
Get-VM -Name local-k3s-server | Select-Object Name, State

Resume-VM -Name local-k3s-server
Get-VM -Name local-k3s-server | Select-Object Name, State
```

## 10. Stop and start the whole VM

Use a normal stop for planned maintenance. Do not use `-TurnOff`; it is the
equivalent of removing power and can damage stateful workloads.

```powershell
Stop-VM -Name local-k3s-server -Force

$Deadline = (Get-Date).AddMinutes(5)
do {
  Start-Sleep -Seconds 5
  $State = (Get-VM -Name local-k3s-server).State
} until ($State -eq 'Off' -or (Get-Date) -ge $Deadline)

if ($State -ne 'Off') { throw 'VM did not stop within five minutes.' }
```

Start it again:

```powershell
Start-VM -Name local-k3s-server
Get-VM -Name local-k3s-server | Select-Object Name, State
```

## 11. Mandatory post-start verification

Node readiness appears before every application is ready. Wait for both.

```powershell
& $Kubectl --kubeconfig $Kubeconfig wait node/k3s-server `
  --for=condition=Ready --timeout=600s

$Deadline = (Get-Date).AddMinutes(10)
do {
  Start-Sleep -Seconds 10
  $Pods = & $Kubectl --kubeconfig $Kubeconfig get pods -A -o json |
    ConvertFrom-Json
  $Unhealthy = @($Pods.items | Where-Object {
    $_.status.phase -ne 'Succeeded' -and (
      $_.status.phase -ne 'Running' -or
      @($_.status.containerStatuses | Where-Object { -not $_.ready }).Count -gt 0
    )
  })
} until ($Unhealthy.Count -eq 0 -or (Get-Date) -ge $Deadline)

if ($Unhealthy.Count -gt 0) {
  $Unhealthy | ForEach-Object {
    "$($_.metadata.namespace)/$($_.metadata.name):$($_.status.phase)"
  }
  throw 'Workloads did not recover within ten minutes.'
}

Start-Sleep -Seconds 30
.\k8s\operations\invoke-daily-health.ps1
if (-not $?) { throw 'Post-start platform health failed.' }
```

The extra 30 seconds allows the kubelet statistics proxy and monitoring
endpoints to converge after application readiness.

## 12. Preserve code quality when changing configuration

Never edit live Kubernetes objects as the permanent solution. Change the files
in Git, validate them, commit them, then apply the committed configuration.

```powershell
Set-Location C:\Server
git status --short --branch

.\k8s\scripts\validate.ps1
& $Kubectl --kubeconfig $Kubeconfig kustomize .\k8s\overlays\current
& $Kubectl --kubeconfig $Kubeconfig apply --dry-run=server `
  -k .\k8s\overlays\current
```

Review only your changes:

```powershell
git diff --check
git diff
```

Commit explicit files, not every unknown workspace change:

```powershell
git add -- path\to\changed-file.yaml path\to\updated-guide.md
git commit -m "ops: describe the controlled change"
git push origin master
git status --short --branch
```

Apply only after validation and commit:

```powershell
& $Kubectl --kubeconfig $Kubeconfig apply -k .\k8s\overlays\current
.\k8s\operations\invoke-daily-health.ps1
```

## 13. Failure checklist

If any command fails:

1. Stop making changes.
2. Preserve the command output and structured report.
3. Check node conditions, pods, events, and the affected container logs.
4. Return optional add-ons to zero replicas.
5. Do not delete PVCs, backups, old VM disks, or rollback assets.
6. Fix the source-controlled configuration and rerun all quality gates.

```powershell
& $Kubectl --kubeconfig $Kubeconfig describe node k3s-server
& $Kubectl --kubeconfig $Kubeconfig get pods -A -o wide
& $Kubectl --kubeconfig $Kubeconfig get events -A `
  --sort-by=.lastTimestamp

@('azurite', 'fake-gcs', 'localstack', 'sonarqube') | ForEach-Object {
  .\k8s\operations\manage-addon.ps1 -Name $_ -Action stop
}

.\k8s\operations\invoke-daily-health.ps1
```

Escalate when the node has pressure, a stateful pod repeatedly restarts, the
newest backup is older than 26 hours, a scheduled task returns non-zero, an
active alert remains, or Windows free memory falls below 4 GiB.
