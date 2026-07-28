[CmdletBinding()]
param(
    [string]$KubectlPath = 'kubectl',
    [string]$KubeconfigPath = '/etc/rancher/k3s/k3s.yaml',
    [string]$OutputDirectory = './.local/server-platform/operations/health',
    [double]$MinimumNodeFreePercent = 15,
    [int]$ReportRetentionDays = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$checks = [System.Collections.Generic.List[object]]::new()
$startedAt = Get-Date

function Write-HealthEvent {
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

function Add-HealthCheck {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$Passed,
        [Parameter(Mandatory)][string]$Message,
        [hashtable]$Evidence = @{}
    )

    $status = if ($Passed) { 'passed' } else { 'failed' }
    $checks.Add([pscustomobject]@{
        name = $Name
        status = $status
        message = $Message
        evidence = $Evidence
    })
    Write-HealthEvent -Level $(if ($Passed) { 'info' } else { 'error' }) `
        -Event "health_check_$status" -Message $Message `
        -Data (@{ check = $Name } + $Evidence)
}

function Invoke-KubectlJson {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $output = & $KubectlPath --kubeconfig $KubeconfigPath @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "kubectl $($Arguments -join ' ') failed: $($output -join [Environment]::NewLine)"
    }
    ($output -join "`n") | ConvertFrom-Json
}

try {
    Write-HealthEvent -Level info -Event daily_health_started `
        -Message 'Daily platform health validation started.' `
        -Data @{}

    if (-not (Get-Command $KubectlPath -ErrorAction SilentlyContinue)) {
        throw "kubectl was not found at '$KubectlPath'."
    }
    if (-not (Test-Path -LiteralPath $KubeconfigPath -PathType Leaf)) {
        throw "Kubeconfig was not found at '$KubeconfigPath'."
    }
    if ($ReportRetentionDays -lt 1) {
        throw 'ReportRetentionDays must be at least 1.'
    }

    $nodes = Invoke-KubectlJson -Arguments @('get', 'nodes', '-o', 'json')
    $unreadyNodes = @($nodes.items | Where-Object {
        @($_.status.conditions | Where-Object { $_.type -eq 'Ready' -and $_.status -eq 'True' }).Count -eq 0
    } | ForEach-Object { $_.metadata.name })
    Add-HealthCheck -Name kubernetes_nodes -Passed ($nodes.items.Count -eq 1 -and $unreadyNodes.Count -eq 0) `
        -Message "Kubernetes reports $($nodes.items.Count) node(s); $($unreadyNodes.Count) are not Ready." `
        -Evidence @{ count = $nodes.items.Count; unready = $unreadyNodes }

    $pods = Invoke-KubectlJson -Arguments @('get', 'pods', '-A', '-o', 'json')
    $badPods = @($pods.items | Where-Object {
        if ($_.status.phase -eq 'Succeeded') { return $false }
        if ($_.status.phase -ne 'Running') { return $true }
        @($_.status.containerStatuses | Where-Object { -not $_.ready }).Count -gt 0
    } | ForEach-Object { "$($_.metadata.namespace)/$($_.metadata.name):$($_.status.phase)" })
    Add-HealthCheck -Name kubernetes_pods -Passed ($badPods.Count -eq 0) `
        -Message "Kubernetes reports $($badPods.Count) unhealthy pod(s)." `
        -Evidence @{ unhealthy = $badPods; total = $pods.items.Count }

    $deployments = Invoke-KubectlJson -Arguments @('get', 'deployments', '-A', '-o', 'json')
    $badDeployments = @($deployments.items | Where-Object {
        $availableProperty = $_.status.PSObject.Properties['availableReplicas']
        $available = if ($null -eq $availableProperty) { 0 } else { [int]$availableProperty.Value }
        $available -lt [int]$_.spec.replicas
    } | ForEach-Object {
        $availableProperty = $_.status.PSObject.Properties['availableReplicas']
        $available = if ($null -eq $availableProperty) { 0 } else { [int]$availableProperty.Value }
        "$($_.metadata.namespace)/$($_.metadata.name):$available/$([int]$_.spec.replicas)"
    })
    Add-HealthCheck -Name kubernetes_deployments -Passed ($badDeployments.Count -eq 0) `
        -Message "Kubernetes reports $($badDeployments.Count) unavailable deployment(s)." `
        -Evidence @{ unavailable = $badDeployments; total = $deployments.items.Count }

    $statefulSets = Invoke-KubectlJson -Arguments @('get', 'statefulsets', '-A', '-o', 'json')
    $badStatefulSets = @($statefulSets.items | Where-Object {
        $readyProperty = $_.status.PSObject.Properties['readyReplicas']
        $ready = if ($null -eq $readyProperty) { 0 } else { [int]$readyProperty.Value }
        $ready -lt [int]$_.spec.replicas
    } | ForEach-Object {
        $readyProperty = $_.status.PSObject.Properties['readyReplicas']
        $ready = if ($null -eq $readyProperty) { 0 } else { [int]$readyProperty.Value }
        "$($_.metadata.namespace)/$($_.metadata.name):$ready/$([int]$_.spec.replicas)"
    })
    Add-HealthCheck -Name kubernetes_statefulsets -Passed ($badStatefulSets.Count -eq 0) `
        -Message "Kubernetes reports $($badStatefulSets.Count) unavailable StatefulSet(s)." `
        -Evidence @{ unavailable = $badStatefulSets; total = $statefulSets.items.Count }

    $daemonSets = Invoke-KubectlJson -Arguments @('get', 'daemonsets', '-A', '-o', 'json')
    $badDaemonSets = @($daemonSets.items | Where-Object {
        [int]$_.status.numberReady -lt [int]$_.status.desiredNumberScheduled
    } | ForEach-Object {
        "$($_.metadata.namespace)/$($_.metadata.name):$([int]$_.status.numberReady)/$([int]$_.status.desiredNumberScheduled)"
    })
    Add-HealthCheck -Name kubernetes_daemonsets -Passed ($badDaemonSets.Count -eq 0) `
        -Message "Kubernetes reports $($badDaemonSets.Count) unavailable DaemonSet(s)." `
        -Evidence @{ unavailable = $badDaemonSets; total = $daemonSets.items.Count }

    $claims = Invoke-KubectlJson -Arguments @('get', 'pvc', '-A', '-o', 'json')
    $badClaims = @($claims.items | Where-Object { $_.status.phase -ne 'Bound' } |
        ForEach-Object { "$($_.metadata.namespace)/$($_.metadata.name):$($_.status.phase)" })
    Add-HealthCheck -Name kubernetes_storage -Passed ($badClaims.Count -eq 0) `
        -Message "Kubernetes reports $($badClaims.Count) unbound PVC(s)." `
        -Evidence @{ unbound = $badClaims; total = $claims.items.Count }

    $nodeStatsPath = "/api/v1/nodes/$($nodes.items[0].metadata.name)/proxy/stats/summary"
    $summary = Invoke-KubectlJson -Arguments @('get', "--raw=$nodeStatsPath")
    $nodeFreePercent = [math]::Round((([double]$summary.node.fs.availableBytes / [double]$summary.node.fs.capacityBytes) * 100), 2)
    Add-HealthCheck -Name node_filesystem -Passed ($nodeFreePercent -ge $MinimumNodeFreePercent) `
        -Message "K3s node filesystem has $nodeFreePercent percent free." `
        -Evidence @{ free_percent = $nodeFreePercent; minimum_percent = $MinimumNodeFreePercent }
}
catch {
    Add-HealthCheck -Name health_runner -Passed $false `
        -Message $_.Exception.Message `
        -Evidence @{ stack = $_.ScriptStackTrace }
}
finally {
    $completedAt = Get-Date
    $failedChecks = @($checks | Where-Object { $_.status -eq 'failed' })
    $report = [ordered]@{
        schema_version = 1
        succeeded = ($failedChecks.Count -eq 0)
        started_at = $startedAt.ToUniversalTime().ToString('o')
        completed_at = $completedAt.ToUniversalTime().ToString('o')
        duration_seconds = [math]::Round(($completedAt - $startedAt).TotalSeconds, 3)
        checks = $checks
    }

    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $timestamp = $startedAt.ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $reportPath = Join-Path $OutputDirectory "health-$timestamp.json"
    $latestPath = Join-Path $OutputDirectory 'latest.json'
    $reportJson = $report | ConvertTo-Json -Depth 12
    $reportJson | Set-Content -LiteralPath $reportPath -Encoding UTF8
    $reportJson | Set-Content -LiteralPath $latestPath -Encoding UTF8

    $cutoff = (Get-Date).AddDays(-$ReportRetentionDays)
    Get-ChildItem -LiteralPath $OutputDirectory -Filter 'health-*.json' -File |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force

    Write-HealthEvent -Level $(if ($report.succeeded) { 'info' } else { 'error' }) `
        -Event daily_health_completed `
        -Message "Daily platform health validation completed; report: $reportPath" `
        -Data @{ succeeded = $report.succeeded; failed_checks = $failedChecks.Count; report = $reportPath }

    if (-not $report.succeeded) {
        exit 1
    }
}
