[CmdletBinding()]
param([switch] $SkipPush)
$ErrorActionPreference = "Stop"
$image = "localhost:5000/node-api:local"
docker build -t $image .
if (-not $SkipPush) {
    docker push $image
}

