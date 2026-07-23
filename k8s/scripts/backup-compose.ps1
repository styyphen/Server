param(
    [Parameter(Mandatory)]
    [string]$OutputDirectory,
    [switch]$PullHelperImage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null

docker info | Out-Null
if ($PullHelperImage) {
    docker pull alpine:3.22
}

$projects = @(
    @{ Name = 'observability'; File = (Join-Path $repoRoot 'docker-compose.yml') },
    @{ Name = 'platform'; File = (Join-Path $repoRoot 'localCICD/docker-compose.yml') }
)

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$manifest = @()
$discoveredVolumes = 0
foreach ($project in $projects) {
    $projectName = (docker compose -f $project.File config --format json | ConvertFrom-Json).name
    $volumeNames = docker volume ls --filter "label=com.docker.compose.project=$projectName" --format '{{.Name}}'
    foreach ($volumeName in $volumeNames) {
        if ([string]::IsNullOrWhiteSpace($volumeName)) { continue }
        $discoveredVolumes++
        $archive = "$($project.Name)-$volumeName-$timestamp.tgz"
        docker run --rm `
            --mount "type=volume,src=$volumeName,dst=/source,readonly" `
            --mount "type=bind,src=$resolvedOutput,dst=/backup" `
            alpine:3.22 tar -czf "/backup/$archive" -C /source .
        $hash = (Get-FileHash (Join-Path $resolvedOutput $archive) -Algorithm SHA256).Hash
        $manifest += [pscustomobject]@{
            project = $project.Name
            volume = $volumeName
            archive = $archive
            sha256 = $hash
        }
    }
}

if ($discoveredVolumes -eq 0) {
    throw 'No Compose-managed volumes were found. No backup was created; start or inspect the Compose projects and try again.'
}

$manifestPath = Join-Path $resolvedOutput "manifest-$timestamp.json"
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Path $manifestPath -Encoding UTF8
foreach ($entry in $manifest) {
    $archivePath = Join-Path $resolvedOutput $entry.archive
    if (-not (Test-Path $archivePath) -or (Get-Item $archivePath).Length -eq 0) {
        throw "Backup verification failed for $archivePath"
    }
}
Write-Host "Backup completed. Manifest: $manifestPath"
Write-Host "Copy this directory to a different physical disk before migration."
