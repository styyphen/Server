[CmdletBinding()]
param(
    [string]$BackupRoot = './.local/server-platform/backups',
    [string]$BackupPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-VerificationEvent {
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
    } | ConvertTo-Json -Depth 6 -Compress
}

if ([string]::IsNullOrWhiteSpace($BackupPath)) {
    $latest = Get-ChildItem -LiteralPath $BackupRoot -Directory -Filter 'daily-*' |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($null -eq $latest) {
        throw "No daily backup exists under '$BackupRoot'."
    }
    $BackupPath = $latest.FullName
}

$resolvedBackup = (Resolve-Path -LiteralPath $BackupPath).Path
$manifestPath = Join-Path $resolvedBackup 'manifest.json'
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) "platform-backup-test-$([guid]::NewGuid().ToString('N'))"

try {
    Write-VerificationEvent -Level info -Event backup_verification_started `
        -Message 'Platform backup integrity verification started.' -Data @{ backup = $resolvedBackup }
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    if (-not $manifest.succeeded) {
        throw 'Backup manifest reports failure.'
    }
    foreach ($artifact in $manifest.artifacts) {
        $artifactPath = Join-Path $resolvedBackup $artifact.file
        $actual = Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256
        if ($actual.Hash -ne $artifact.sha256) {
            throw "SHA256 mismatch for '$($artifact.file)'."
        }
    }

    New-Item -ItemType Directory -Path $scratch -Force | Out-Null
    $giteaList = & tar.exe -tzf (Join-Path $resolvedBackup 'gitea.tar.gz') 2>&1
    $giteaEntries = $giteaList -join "`n"
    if ($LASTEXITCODE -ne 0 -or $giteaEntries -notmatch '(?m)^gitea-db\.sql$') {
        throw 'Gitea archive is unreadable or lacks gitea-db.sql.'
    }

    $registryRestore = Join-Path $scratch 'registry'
    New-Item -ItemType Directory -Path $registryRestore | Out-Null
    & tar.exe -xf (Join-Path $resolvedBackup 'registry.zip') -C $registryRestore
    if ($LASTEXITCODE -ne 0) {
        throw 'Registry archive extraction failed.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $registryRestore 'docker/registry/v2'))) {
        throw 'Registry archive lacks docker/registry/v2.'
    }

    $grafanaRestore = Join-Path $scratch 'grafana'
    New-Item -ItemType Directory -Path $grafanaRestore | Out-Null
    & tar.exe -xf (Join-Path $resolvedBackup 'grafana.zip') -C $grafanaRestore
    if ($LASTEXITCODE -ne 0) {
        throw 'Grafana archive extraction failed.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $grafanaRestore 'grafana.db'))) {
        throw 'Grafana archive lacks grafana.db.'
    }

    $cluster = Get-Content -Raw -LiteralPath (Join-Path $resolvedBackup 'cluster-objects.json') |
        ConvertFrom-Json
    if ($cluster.kind -ne 'List' -or $cluster.items.Count -lt 1) {
        throw 'Cluster object export is empty or invalid.'
    }

    Write-VerificationEvent -Level info -Event backup_verification_completed `
        -Message 'Hashes and isolated archive extraction passed.' `
        -Data @{ backup = $resolvedBackup; artifacts = $manifest.artifacts.Count; objects = $cluster.items.Count }
}
catch {
    Write-VerificationEvent -Level error -Event backup_verification_failed `
        -Message $_.Exception.Message -Data @{ backup = $resolvedBackup; stack = $_.ScriptStackTrace }
    exit 1
}
finally {
    if (Test-Path -LiteralPath $scratch) {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
