[CmdletBinding()]
param([switch] $SkipPush)
$ErrorActionPreference = "Stop"
$image = "localhost:5000/__PROJECT_SLUG__:local"
docker build -t $image .
if (-not $SkipPush) {
    docker push $image
}
