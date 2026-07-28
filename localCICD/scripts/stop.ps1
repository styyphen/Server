param(
    [switch]$Down
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$ComposeFile = Join-Path $Root 'docker-compose.yml'
$EnvFile = Join-Path $Root '.env'
$DefaultEnvFile = Join-Path $Root '.env.example'
$SelectedEnvFile = if (Test-Path $EnvFile) { $EnvFile } else { $DefaultEnvFile }

if ($Down) {
    docker compose --env-file $SelectedEnvFile -f $ComposeFile down
} else {
    docker compose --env-file $SelectedEnvFile -f $ComposeFile stop
}
