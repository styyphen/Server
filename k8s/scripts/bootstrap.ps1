param(
    [string]$Overlay = (Join-Path (Split-Path -Parent $PSScriptRoot) 'overlays/single-server'),
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw 'kubectl is required.'
}

$rendered = kubectl kustomize $Overlay
if (-not $rendered) {
    throw "Kustomize produced no resources from $Overlay"
}

if (-not $Apply) {
    Write-Host $rendered
    Write-Host "`nDry run only. Re-run with -Apply to change the connected cluster."
    exit 0
}

kubectl cluster-info | Out-Null
$rendered | kubectl apply --server-side --field-manager=local-platform-bootstrap -f -
Write-Host 'Baseline namespaces, quotas, limits, and network policies applied.'
