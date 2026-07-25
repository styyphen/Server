[CmdletBinding()]
param(
    [string]$KubectlPath = 'D:\HyperV\tools\kubectl-v1.36.1.exe',
    [string]$KubeconfigPath = 'D:\HyperV\credentials\k3s-admin.yaml',
    [string]$BackupRoot = 'D:\server-backups\platform',
    [string]$OutputDirectory = 'D:\HyperV\operations\registry',
    [int]$MaximumBackupAgeHours = 26
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$startedAt = Get-Date
$jobName = 'registry-garbage-collect'
$originalReplicas = 1
$scaledDown = $false
$succeeded = $false

function Write-MaintenanceEvent {
    param(
        [Parameter(Mandatory)][ValidateSet('info', 'error')][string]$Level,
        [Parameter(Mandatory)][string]$Event,
        [Parameter(Mandatory)][string]$Message,
        [hashtable]$Data = @{}
    )
    [ordered]@{
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
        level = $Level
        event = $Event
        message = $Message
        data = $Data
    } | ConvertTo-Json -Depth 8 -Compress
}

function Invoke-Kubectl {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = & $KubectlPath --kubeconfig $KubeconfigPath @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "kubectl $($Arguments -join ' ') failed: $($output -join [Environment]::NewLine)"
    }
    $output
}

try {
    $latestBackup = Get-ChildItem -LiteralPath $BackupRoot -Directory -Filter 'daily-*' |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($null -eq $latestBackup) {
        throw "No daily backup exists under '$BackupRoot'; Registry maintenance is blocked."
    }
    $manifestPath = Join-Path $latestBackup.FullName 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Latest backup has no manifest: '$manifestPath'."
    }
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    $backupAgeHours = ((Get-Date).ToUniversalTime() - ([datetime]$manifest.completed_at).ToUniversalTime()).TotalHours
    if (-not $manifest.succeeded -or $backupAgeHours -gt $MaximumBackupAgeHours) {
        throw "Latest backup is unsuccessful or $([math]::Round($backupAgeHours, 2)) hours old; Registry maintenance is blocked."
    }

    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    Write-MaintenanceEvent -Level info -Event registry_maintenance_started `
        -Message 'Controlled Registry garbage collection started.' `
        -Data @{ backup = $latestBackup.FullName; backup_age_hours = [math]::Round($backupAgeHours, 2) }

    $deploymentOutput = Invoke-Kubectl -Arguments @(
        '-n', 'platform-system', 'get', 'deployment', 'registry', '-o', 'json'
    )
    $deployment = ($deploymentOutput -join "`n") | ConvertFrom-Json
    $originalReplicas = [int]$deployment.spec.replicas
    if ($originalReplicas -lt 1) {
        throw 'Registry has no active replicas; refusing maintenance because its prior state is unhealthy.'
    }

    Invoke-Kubectl -Arguments @(
        '-n', 'platform-system', 'scale', 'deployment/registry', '--replicas=0'
    ) | Out-Null
    $scaledDown = $true
    $deadline = (Get-Date).AddMinutes(3)
    do {
        Start-Sleep -Seconds 2
        $remainingOutput = Invoke-Kubectl -Arguments @(
            '-n', 'platform-system', 'get', 'pods',
            '-l', 'app.kubernetes.io/name=registry',
            '-o', 'json'
        )
        $remaining = ($remainingOutput -join "`n") | ConvertFrom-Json
    } while ($remaining.items.Count -gt 0 -and (Get-Date) -lt $deadline)
    if ($remaining.items.Count -gt 0) {
        throw 'Registry pods did not terminate within three minutes.'
    }

    $jobManifest = @"
apiVersion: batch/v1
kind: Job
metadata:
  name: $jobName
  namespace: platform-system
spec:
  activeDeadlineSeconds: 600
  backoffLimit: 0
  ttlSecondsAfterFinished: 3600
  template:
    metadata:
      labels:
        app.kubernetes.io/name: registry-garbage-collect
    spec:
      serviceAccountName: registry
      automountServiceAccountToken: false
      restartPolicy: Never
      securityContext:
        fsGroup: 1000
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        seccompProfile: {type: RuntimeDefault}
      containers:
        - name: garbage-collect
          image: docker.io/library/registry:3.1.1
          args: [garbage-collect, --delete-untagged, /etc/distribution/config.yml]
          resources:
            requests: {cpu: 25m, memory: 64Mi}
            limits: {cpu: 300m, memory: 256Mi}
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: {drop: [ALL]}
            readOnlyRootFilesystem: true
          volumeMounts:
            - {name: data, mountPath: /var/lib/registry}
            - {name: config, mountPath: /etc/distribution/config.yml, subPath: config.yml, readOnly: true}
            - {name: tmp, mountPath: /tmp}
      volumes:
        - name: data
          persistentVolumeClaim: {claimName: registry-data}
        - name: config
          configMap: {name: registry-config}
        - name: tmp
          emptyDir: {sizeLimit: 64Mi}
"@
    $manifestFile = Join-Path $OutputDirectory "$jobName.yaml"
    $jobManifest | Set-Content -LiteralPath $manifestFile -Encoding ASCII
    Invoke-Kubectl -Arguments @(
        '-n', 'platform-system', 'delete', 'job', $jobName, '--ignore-not-found=true', '--wait=true'
    ) | Out-Null
    Invoke-Kubectl -Arguments @('apply', '-f', $manifestFile) | Out-Null
    try {
        Invoke-Kubectl -Arguments @(
            '-n', 'platform-system', 'wait', '--for=condition=complete',
            "job/$jobName", '--timeout=620s'
        ) | Out-Null
        $logs = Invoke-Kubectl -Arguments @(
            '-n', 'platform-system', 'logs', "job/$jobName", '--timestamps=true'
        )
        $logs | Set-Content -LiteralPath (Join-Path $OutputDirectory 'latest.log') -Encoding UTF8
    }
    catch {
        $diagnostics = Invoke-Kubectl -Arguments @(
            '-n', 'platform-system', 'describe', 'job', $jobName
        )
        $diagnostics | Set-Content -LiteralPath (Join-Path $OutputDirectory 'failure-describe.txt') -Encoding UTF8
        throw
    }
    finally {
        Invoke-Kubectl -Arguments @(
            '-n', 'platform-system', 'delete', 'job', $jobName, '--ignore-not-found=true', '--wait=true'
        ) | Out-Null
        Remove-Item -LiteralPath $manifestFile -Force -ErrorAction SilentlyContinue
    }
    $succeeded = $true
}
catch {
    Write-MaintenanceEvent -Level error -Event registry_maintenance_failed `
        -Message $_.Exception.Message -Data @{ stack = $_.ScriptStackTrace }
}
finally {
    if ($scaledDown) {
        try {
            Invoke-Kubectl -Arguments @(
                '-n', 'platform-system', 'scale', 'deployment/registry', "--replicas=$originalReplicas"
            ) | Out-Null
            Invoke-Kubectl -Arguments @(
                '-n', 'platform-system', 'rollout', 'status', 'deployment/registry', '--timeout=180s'
            ) | Out-Null
        }
        catch {
            $succeeded = $false
            Write-MaintenanceEvent -Level error -Event registry_recovery_failed `
                -Message $_.Exception.Message -Data @{ stack = $_.ScriptStackTrace }
        }
    }
    Write-MaintenanceEvent -Level $(if ($succeeded) { 'info' } else { 'error' }) `
        -Event registry_maintenance_completed `
        -Message "Controlled Registry maintenance completed; succeeded=$succeeded." `
        -Data @{ succeeded = $succeeded; restored_replicas = $originalReplicas }
}

if (-not $succeeded) {
    exit 1
}
