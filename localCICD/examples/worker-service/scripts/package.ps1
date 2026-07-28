[CmdletBinding()]
param([switch] $SkipPush)
$ErrorActionPreference = "Stop"
$image = "localhost:5000/worker-service:local"
docker build -t $image .
if (-not $SkipPush) {
    docker push $image
}

