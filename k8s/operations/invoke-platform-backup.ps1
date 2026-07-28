[CmdletBinding()]
param(
    [string]$KubectlPath = 'kubectl',
    [string]$KubeconfigPath = '/etc/rancher/k3s/k3s.yaml',
    [string]$BackupRoot = './.local/server-platform/backups',
    [int]$RetentionDays = 14,
    [int]$MaximumBackups = 14
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$startedAt = Get-Date
$timestamp = $startedAt.ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$backupPath = Join-Path $BackupRoot "daily-$timestamp"
$stagingPath = Join-Path $backupPath 'staging'
$steps = [System.Collections.Generic.List[object]]::new()

function Write-BackupEvent {
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

function Get-ReadyPodName {
    param(
        [Parameter(Mandatory)][string]$Namespace,
        [Parameter(Mandatory)][string]$Selector
    )

    $json = (Invoke-Kubectl -Arguments @(
        '-n', $Namespace, 'get', 'pod', '-l', $Selector, '-o', 'json'
    )) -join "`n"
    $pods = $json | ConvertFrom-Json
    $readyPod = @($pods.items | Where-Object {
        $_.status.phase -eq 'Running' -and
        @($_.status.containerStatuses).Count -gt 0 -and
        @($_.status.containerStatuses | Where-Object { -not $_.ready }).Count -eq 0
    } | Sort-Object { $_.metadata.creationTimestamp } -Descending | Select-Object -First 1)

    if ($readyPod.Count -ne 1) {
        throw "No Running and Ready pod matched '$Selector' in namespace '$Namespace'."
    }
    $readyPod[0].metadata.name
}

function Complete-Step {
    param([string]$Name, [string]$Artifact)
    $steps.Add([pscustomobject]@{ name = $Name; status = 'passed'; artifact = $Artifact })
    Write-BackupEvent -Level info -Event backup_step_completed `
        -Message "Backup step '$Name' completed." -Data @{ artifact = $Artifact }
}

try {
    if ($RetentionDays -lt 1 -or $MaximumBackups -lt 1) {
        throw 'RetentionDays and MaximumBackups must both be at least 1.'
    }
    if (-not (Get-Command $KubectlPath -ErrorAction SilentlyContinue)) {
        throw "kubectl was not found at '$KubectlPath'."
    }
    if (-not (Test-Path -LiteralPath $KubeconfigPath -PathType Leaf)) {
        throw "Kubeconfig was not found at '$KubeconfigPath'."
    }

    New-Item -ItemType Directory -Path $stagingPath -Force | Out-Null
    Set-Location -LiteralPath $backupPath
    Write-BackupEvent -Level info -Event platform_backup_started `
        -Message 'Daily logical platform backup started.' -Data @{ backup = $backupPath }

    $giteaPod = Get-ReadyPodName -Namespace platform-system `
        -Selector 'app.kubernetes.io/name=gitea'
    $remoteDump = "/tmp/gitea-$timestamp.tar.gz"
    Invoke-Kubectl -Arguments @(
        '-n', 'platform-system', 'exec', $giteaPod, '--',
        'gitea', 'dump', '--quiet', '--type', 'tar.gz', '--tempdir', '/tmp', '--file', $remoteDump
    ) | Out-Null
    try {
        Invoke-Kubectl -Arguments @(
            '-n', 'platform-system', 'cp',
            "${giteaPod}:${remoteDump}", 'gitea.tar.gz'
        ) | Out-Null
    }
    finally {
        Invoke-Kubectl -Arguments @(
            '-n', 'platform-system', 'exec', $giteaPod, '--', 'rm', '-f', $remoteDump
        ) | Out-Null
    }
    Complete-Step -Name gitea -Artifact 'gitea.tar.gz'

    $registryPod = Get-ReadyPodName -Namespace platform-system `
        -Selector 'app.kubernetes.io/name=registry'
    $registryStaging = Join-Path $stagingPath 'registry'
    Invoke-Kubectl -Arguments @(
        '-n', 'platform-system', 'cp',
        "${registryPod}:/var/lib/registry/.", 'staging/registry'
    ) | Out-Null
    Compress-Archive -Path (Join-Path $registryStaging '*') `
        -DestinationPath (Join-Path $backupPath 'registry.zip') -CompressionLevel Optimal
    Complete-Step -Name registry -Artifact 'registry.zip'

    $grafanaPod = Get-ReadyPodName -Namespace observability `
        -Selector 'app.kubernetes.io/name=grafana'
    $grafanaStaging = Join-Path $stagingPath 'grafana'
    Invoke-Kubectl -Arguments @(
        '-n', 'observability', 'cp',
        "${grafanaPod}:/var/lib/grafana/.", 'staging/grafana'
    ) | Out-Null
    Compress-Archive -Path (Join-Path $grafanaStaging '*') `
        -DestinationPath (Join-Path $backupPath 'grafana.zip') -CompressionLevel Optimal
    Complete-Step -Name grafana -Artifact 'grafana.zip'

    $clusterObjects = Invoke-Kubectl -Arguments @(
        'get', 'namespaces,resourcequotas,limitranges,networkpolicies,serviceaccounts,roles,rolebindings,configmaps,secrets,services,ingresses,deployments,statefulsets,daemonsets,persistentvolumeclaims',
        '-A', '-o', 'json'
    )
    $clusterObjects -join "`n" |
        Set-Content -LiteralPath (Join-Path $backupPath 'cluster-objects.json') -Encoding UTF8
    Complete-Step -Name cluster_objects -Artifact 'cluster-objects.json'

    Remove-Item -LiteralPath $stagingPath -Recurse -Force
    $artifactFiles = @(Get-ChildItem -LiteralPath $backupPath -File)
    $hashes = @($artifactFiles | ForEach-Object {
        $hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
        [ordered]@{ file = $_.Name; bytes = $_.Length; sha256 = $hash.Hash.ToLowerInvariant() }
    })
    $manifest = [ordered]@{
        schema_version = 1
        succeeded = $true
        started_at = $startedAt.ToUniversalTime().ToString('o')
        completed_at = (Get-Date).ToUniversalTime().ToString('o')
        backup_path = $backupPath
        retention_days = $RetentionDays
        maximum_backups = $MaximumBackups
        steps = $steps
        artifacts = $hashes
        contains_secrets = $true
    }
    $manifest | ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath (Join-Path $backupPath 'manifest.json') -Encoding UTF8

    $resolvedRoot = [System.IO.Path]::GetFullPath($BackupRoot).TrimEnd('\')
    $candidates = @(Get-ChildItem -LiteralPath $resolvedRoot -Directory -Filter 'daily-*' |
        Sort-Object LastWriteTime -Descending)
    $cutoff = (Get-Date).AddDays(-$RetentionDays)
    $expired = @($candidates | Where-Object { $_.LastWriteTime -lt $cutoff })
    $overflow = @($candidates | Select-Object -Skip $MaximumBackups)
    $removed = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($candidate in @($expired) + @($overflow)) {
        $resolvedCandidate = [System.IO.Path]::GetFullPath($candidate.FullName)
        if (-not $resolvedCandidate.StartsWith("$resolvedRoot\", [StringComparison]::OrdinalIgnoreCase) -or
            $candidate.Name -notmatch '^daily-\d{8}T\d{6}Z$') {
            throw "Refusing to remove unexpected backup path '$resolvedCandidate'."
        }
        if ($resolvedCandidate -ne $backupPath -and $removed.Add($resolvedCandidate)) {
            Remove-Item -LiteralPath $resolvedCandidate -Recurse -Force
            Write-BackupEvent -Level info -Event expired_backup_removed `
                -Message 'Expired daily backup removed.' -Data @{ backup = $resolvedCandidate }
        }
    }

    Write-BackupEvent -Level info -Event platform_backup_completed `
        -Message "Daily logical platform backup completed: $backupPath" `
        -Data @{ backup = $backupPath; artifacts = $hashes.Count; removed = $removed.Count }
}
catch {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    $failure = [ordered]@{
        schema_version = 1
        succeeded = $false
        started_at = $startedAt.ToUniversalTime().ToString('o')
        completed_at = (Get-Date).ToUniversalTime().ToString('o')
        backup_path = $backupPath
        error = $_.Exception.Message
        stack = $_.ScriptStackTrace
        steps = $steps
    }
    $failure | ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath (Join-Path $backupPath 'failure.json') -Encoding UTF8
    Write-BackupEvent -Level error -Event platform_backup_failed `
        -Message $_.Exception.Message -Data @{ backup = $backupPath; stack = $_.ScriptStackTrace }
    exit 1
}
