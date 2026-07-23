param(
    [switch]$Pull
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$ComposeFile = Join-Path $Root 'docker-compose.yml'
$EnvFile = Join-Path $Root '.env'
$DefaultEnvFile = Join-Path $Root '.env.example'

if (-not (Test-Path $ComposeFile)) {
    throw "Compose file not found: $ComposeFile"
}

$SelectedEnvFile = if (Test-Path $EnvFile) { $EnvFile } else { $DefaultEnvFile }

if ($Pull) {
    docker compose --env-file $SelectedEnvFile -f $ComposeFile pull
}

docker compose --env-file $SelectedEnvFile -f $ComposeFile up -d

Write-Host "Local cloud dev platform is starting."
Write-Host "Gitea:      http://localhost:3000"
Write-Host "Registry:   http://localhost:5000"
Write-Host "LocalStack: http://localhost:4566"
Write-Host "Azurite:    http://localhost:10000"
Write-Host "fake GCS:   http://localhost:4443"
Write-Host "SonarQube:  http://localhost:9000"
