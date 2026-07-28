param(
    [string]$Overlay = (Join-Path (Split-Path -Parent $PSScriptRoot) 'overlays/single-server'),
    [switch]$Cluster
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$yamlLines = kubectl kustomize $Overlay
if (-not $yamlLines) {
    throw 'Manifest rendering failed.'
}
$yaml = $yamlLines -join "`n"

$requiredKinds = @('Namespace', 'ResourceQuota', 'LimitRange', 'NetworkPolicy')
foreach ($kind in $requiredKinds) {
    if ($yaml -notmatch "(?m)^kind:\s+$([regex]::Escape($kind))\r?$") {
        throw "Rendered manifests do not contain $kind."
    }
}

if ($Cluster) {
    $yamlLines | kubectl apply --dry-run=server -f - | Out-Null
    $node = kubectl get nodes -o json | ConvertFrom-Json
    if ($node.items.Count -ne 1) {
        throw "Expected one Kubernetes node, found $($node.items.Count)."
    }
}

Write-Host 'Kubernetes baseline validation passed.'
