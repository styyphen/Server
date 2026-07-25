[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('azurite', 'fake-gcs', 'localstack', 'sonarqube')]
    [string]$Name,

    [Parameter(Mandatory)]
    [ValidateSet('start', 'stop', 'status', 'test', 'accept')]
    [string]$Action,

    [string]$KubectlPath = 'D:\HyperV\tools\kubectl-v1.36.1.exe',
    [string]$KubeconfigPath = 'D:\HyperV\credentials\k3s-admin.yaml',
    [int]$TimeoutSeconds = 600
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$namespace = 'cloud-emulators'
$startedForAcceptance = $false

$addons = @{
    'azurite' = @{
        Workloads = @('deployment/azurite')
        Test = @'
code="$(curl --retry 15 --retry-connrefused --retry-delay 1 -sS -o /tmp/response -w '%{http_code}' 'http://azurite:10000/devstoreaccount1?comp=list')"
case "$code" in 200|400|403) ;; *) cat /tmp/response; exit 1 ;; esac
echo "Azurite Blob endpoint accepted a storage API request with HTTP ${code}."
'@
    }
    'fake-gcs' = @{
        Workloads = @('deployment/fake-gcs')
        Test = @'
code="$(curl --retry 15 --retry-connrefused --retry-delay 1 -sS -o /tmp/create -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
  --data '{"name":"phase-g-acceptance"}' 'http://fake-gcs:4443/storage/v1/b?project=phase-g')"
case "$code" in 200|409) ;; *) cat /tmp/create; exit 1 ;; esac
curl -fsS 'http://fake-gcs:4443/storage/v1/b?project=phase-g' | grep -q 'phase-g-acceptance'
echo "fake GCS bucket create/list acceptance passed."
'@
    }
    'localstack' = @{
        Workloads = @('deployment/localstack')
        Test = @'
curl -fsS 'http://localstack:4566/_localstack/health' | grep -q '"s3"'
echo "LocalStack health and S3 service acceptance passed."
'@
    }
    'sonarqube' = @{
        Workloads = @('statefulset/sonarqube-postgresql', 'deployment/sonarqube')
        Test = @'
curl -fsS 'http://sonarqube:9000/api/system/status' | grep -Eq '"status":"(UP|DB_MIGRATION_NEEDED|DB_MIGRATION_RUNNING)"'
echo "SonarQube system API acceptance passed."
'@
    }
}

function Write-AddonEvent {
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
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$AllowFailure
    )
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & $KubectlPath --kubeconfig $KubeconfigPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "kubectl $($Arguments -join ' ') failed: $($output -join [Environment]::NewLine)"
    }
    $output
}

function Get-AddonStates {
    $json = (Invoke-Kubectl -Arguments @(
        '-n', $namespace, 'get', 'deployment,statefulset',
        '-l', 'platform.dev.home.arpa/addon', '-o', 'json'
    )) -join "`n"
    $objects = $json | ConvertFrom-Json
    @($objects.items | ForEach-Object {
        $readyProperty = $_.status.PSObject.Properties['readyReplicas']
        $readyReplicas = if ($null -eq $readyProperty) { 0 } else { [int]$readyProperty.Value }
        [pscustomobject]@{
            addon = $_.metadata.labels.'platform.dev.home.arpa/addon'
            kind = $_.kind
            name = $_.metadata.name
            desired = [int]$_.spec.replicas
            ready = $readyReplicas
        }
    })
}

function Stop-Addon {
    $workloads = @($addons[$Name].Workloads)
    [array]::Reverse($workloads)
    foreach ($workload in $workloads) {
        Invoke-Kubectl -Arguments @('-n', $namespace, 'scale', $workload, '--replicas=0') | Out-Null
    }
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $remaining = @(Get-AddonStates | Where-Object { $_.addon -eq $Name -and $_.ready -gt 0 })
        if ($remaining.Count -eq 0) { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    if ($remaining.Count -gt 0) {
        throw "Add-on '$Name' did not return to zero Ready replicas within $TimeoutSeconds seconds."
    }
    Write-AddonEvent -Level info -Event addon_stopped `
        -Message "Add-on '$Name' is at zero replicas." -Data @{ addon = $Name }
}

function Start-Addon {
    $activeOthers = @(Get-AddonStates | Where-Object { $_.addon -ne $Name -and $_.desired -gt 0 })
    if ($activeOthers.Count -gt 0) {
        throw "Another add-on is active: $(($activeOthers | ForEach-Object { "$($_.addon)/$($_.name)" }) -join ', ')."
    }
    foreach ($workload in $addons[$Name].Workloads) {
        Invoke-Kubectl -Arguments @('-n', $namespace, 'scale', $workload, '--replicas=1') | Out-Null
        Invoke-Kubectl -Arguments @(
            '-n', $namespace, 'rollout', 'status', $workload, "--timeout=${TimeoutSeconds}s"
        ) | Out-Null
    }
    Write-AddonEvent -Level info -Event addon_ready `
        -Message "Add-on '$Name' is Ready." -Data @{ addon = $Name }
}

function Test-Addon {
    $jobName = "addon-$Name-acceptance"
    $testScript = $addons[$Name].Test
    $job = @"
apiVersion: batch/v1
kind: Job
metadata:
  name: $jobName
  namespace: $namespace
spec:
  activeDeadlineSeconds: 180
  backoffLimit: 0
  ttlSecondsAfterFinished: 600
  template:
    metadata:
      labels:
        app.kubernetes.io/name: addon-acceptance
        platform.dev.home.arpa/addon-client: "true"
    spec:
      automountServiceAccountToken: false
      restartPolicy: Never
      securityContext:
        runAsNonRoot: true
        runAsUser: 100
        runAsGroup: 100
        seccompProfile: {type: RuntimeDefault}
      containers:
        - name: acceptance
          image: docker.io/curlimages/curl:8.12.1
          command: [/bin/sh, -c]
          args:
            - |
$($testScript -split "`n" | ForEach-Object { "              $_" } | Out-String)
          resources:
            requests: {cpu: 10m, memory: 16Mi}
            limits: {cpu: 100m, memory: 64Mi}
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: {drop: [ALL]}
            readOnlyRootFilesystem: true
          volumeMounts:
            - {name: tmp, mountPath: /tmp}
      volumes:
        - name: tmp
          emptyDir: {sizeLimit: 16Mi}
"@
    $manifestPath = Join-Path $env:TEMP "$jobName.yaml"
    $job | Set-Content -LiteralPath $manifestPath -Encoding ASCII
    Invoke-Kubectl -Arguments @(
        '-n', $namespace, 'delete', 'job', $jobName, '--ignore-not-found=true', '--wait=true'
    ) | Out-Null
    try {
        Invoke-Kubectl -Arguments @('apply', '-f', $manifestPath) | Out-Null
        $deadline = (Get-Date).AddSeconds([math]::Min($TimeoutSeconds, 200))
        do {
            Start-Sleep -Seconds 2
            $jobJson = (Invoke-Kubectl -Arguments @(
                '-n', $namespace, 'get', 'job', $jobName, '-o', 'json'
            )) -join "`n"
            $jobState = $jobJson | ConvertFrom-Json
            $succeededProperty = $jobState.status.PSObject.Properties['succeeded']
            $failedProperty = $jobState.status.PSObject.Properties['failed']
            $jobSucceeded = $null -ne $succeededProperty -and [int]$succeededProperty.Value -gt 0
            $jobFailed = $null -ne $failedProperty -and [int]$failedProperty.Value -gt 0
        } while (-not $jobSucceeded -and -not $jobFailed -and (Get-Date) -lt $deadline)
        if (-not $jobSucceeded) {
            throw "Acceptance Job '$jobName' failed or timed out."
        }
        $logs = Invoke-Kubectl -Arguments @('-n', $namespace, 'logs', "job/$jobName", '--timestamps=true')
        $logs
        Write-AddonEvent -Level info -Event addon_acceptance_passed `
            -Message "Add-on '$Name' acceptance passed." -Data @{ addon = $Name }
    }
    catch {
        Invoke-Kubectl -Arguments @(
            '-n', $namespace, 'logs', "job/$jobName", '--all-containers=true', '--timestamps=true'
        ) -AllowFailure
        Invoke-Kubectl -Arguments @('-n', $namespace, 'describe', 'job', $jobName) -AllowFailure
        Invoke-Kubectl -Arguments @(
            '-n', $namespace, 'get', 'events', '--sort-by=.lastTimestamp'
        ) -AllowFailure
        throw
    }
    finally {
        Invoke-Kubectl -Arguments @(
            '-n', $namespace, 'delete', 'job', $jobName, '--ignore-not-found=true', '--wait=true'
        ) -AllowFailure | Out-Null
        Remove-Item -LiteralPath $manifestPath -Force -ErrorAction SilentlyContinue
    }
}

try {
    Write-AddonEvent -Level info -Event addon_action_started `
        -Message "Add-on action started: $Action $Name." -Data @{ addon = $Name; action = $Action }
    switch ($Action) {
        'start' { Start-Addon }
        'stop' { Stop-Addon }
        'status' {
            $states = @(Get-AddonStates | Where-Object { $_.addon -eq $Name })
            $states | ConvertTo-Json -Compress
        }
        'test' { Test-Addon }
        'accept' {
            $startedForAcceptance = $true
            Start-Addon
            Test-Addon
        }
    }
}
catch {
    Write-AddonEvent -Level error -Event addon_action_failed `
        -Message $_.Exception.Message -Data @{ addon = $Name; action = $Action; stack = $_.ScriptStackTrace }
    Invoke-Kubectl -Arguments @(
        '-n', $namespace, 'logs', '-l', "platform.dev.home.arpa/addon=$Name",
        '--all-containers=true', '--prefix=true', '--tail=200'
    ) -AllowFailure
    Invoke-Kubectl -Arguments @(
        '-n', $namespace, 'get', 'pods', '-l', "platform.dev.home.arpa/addon=$Name", '-o', 'wide'
    ) -AllowFailure
    exit 1
}
finally {
    if ($Action -eq 'accept' -and $startedForAcceptance) {
        try {
            Stop-Addon
        }
        catch {
            Write-AddonEvent -Level error -Event addon_cleanup_failed `
                -Message $_.Exception.Message -Data @{ addon = $Name; stack = $_.ScriptStackTrace }
        }
    }
}
