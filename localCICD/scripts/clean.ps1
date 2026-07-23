param(
    [switch]$Volumes
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$ComposeFile = Join-Path $Root 'docker-compose.yml'
$EnvFile = Join-Path $Root '.env'
$DefaultEnvFile = Join-Path $Root '.env.example'
$SelectedEnvFile = if (Test-Path $EnvFile) { $EnvFile } else { $DefaultEnvFile }

if ($Volumes) {
    $confirmation = Read-Host "This removes platform containers and named volumes. Type 'delete volumes' to continue"
    if ($confirmation -ne 'delete volumes') {
        Write-Host "Clean cancelled."
        exit 0
    }

    docker compose --env-file $SelectedEnvFile -f $ComposeFile down --volumes --remove-orphans
} else {
    docker compose --env-file $SelectedEnvFile -f $ComposeFile down --remove-orphans
}
