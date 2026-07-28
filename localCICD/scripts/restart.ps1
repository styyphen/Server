param(
    [switch]$Pull
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$ComposeFile = Join-Path $Root 'docker-compose.yml'
$EnvFile = Join-Path $Root '.env'
$DefaultEnvFile = Join-Path $Root '.env.example'
$SelectedEnvFile = if (Test-Path $EnvFile) { $EnvFile } else { $DefaultEnvFile }

if ($Pull) {
    docker compose --env-file $SelectedEnvFile -f $ComposeFile pull
}

docker compose --env-file $SelectedEnvFile -f $ComposeFile up -d --force-recreate
