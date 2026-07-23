param(
    [int]$TimeoutSeconds = 3
)

$ErrorActionPreference = 'Stop'

function Test-HttpEndpoint {
    param(
        [string]$Name,
        [string]$Uri,
        [int[]]$AllowedStatusCodes = @(200)
    )

    try {
        $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec $TimeoutSeconds -Method Get -SkipHttpErrorCheck
        if ($AllowedStatusCodes -contains [int]$response.StatusCode) {
            [pscustomobject]@{ Name = $Name; Status = 'Healthy'; Detail = "$($response.StatusCode) $Uri" }
            return
        }

        [pscustomobject]@{ Name = $Name; Status = 'Unhealthy'; Detail = "$($response.StatusCode) $Uri" }
    } catch {
        [pscustomobject]@{ Name = $Name; Status = 'Unhealthy'; Detail = $_.Exception.Message }
    }
}

$checks = @(
    @{ Name = 'Gitea'; Uri = 'http://localhost:3000/api/healthz'; Allowed = @(200) }
    @{ Name = 'Registry'; Uri = 'http://localhost:5000/v2/'; Allowed = @(200) }
    @{ Name = 'LocalStack'; Uri = 'http://localhost:4566/_localstack/health'; Allowed = @(200) }
    @{ Name = 'Azurite Blob'; Uri = 'http://localhost:10000/devstoreaccount1?comp=list'; Allowed = @(200, 400, 403) }
    @{ Name = 'fake-gcs-server'; Uri = 'http://localhost:4443/storage/v1/b'; Allowed = @(200) }
    @{ Name = 'SonarQube'; Uri = 'http://localhost:9000/api/system/status'; Allowed = @(200) }
)

$results = foreach ($check in $checks) {
    Test-HttpEndpoint -Name $check.Name -Uri $check.Uri -AllowedStatusCodes $check.Allowed
}

$results | Format-Table -AutoSize

if ($results.Status -contains 'Unhealthy') {
    exit 1
}
