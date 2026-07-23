param(
    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'reports'),
    [int]$SampleSeconds = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$output = Join-Path $OutputDirectory "capacity-$timestamp.json"

$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
    Select-Object DeviceID,
        @{Name='SizeGiB'; Expression={[math]::Round($_.Size / 1GB, 2)}},
        @{Name='FreeGiB'; Expression={[math]::Round($_.FreeSpace / 1GB, 2)}}

$dockerAvailable = $false
$dockerInfo = $null
$containerSamples = @()
try {
    $dockerInfo = docker info --format '{{json .}}' | ConvertFrom-Json
    $dockerAvailable = $true
    $first = docker stats --no-stream --format '{{json .}}'
    if ($SampleSeconds -gt 0) {
        Start-Sleep -Seconds $SampleSeconds
    }
    $second = docker stats --no-stream --format '{{json .}}'
    $containerSamples = @($first + $second) | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json }
} catch {
    Write-Warning "Docker metrics were unavailable: $($_.Exception.Message)"
}

$report = [ordered]@{
    measuredAt = (Get-Date).ToUniversalTime().ToString('o')
    host = [ordered]@{
        operatingSystem = $os.Caption
        logicalProcessors = [int]$computer.NumberOfLogicalProcessors
        totalMemoryGiB = [math]::Round($computer.TotalPhysicalMemory / 1GB, 2)
        freeMemoryGiB = [math]::Round($os.FreePhysicalMemory * 1KB / 1GB, 2)
        disks = @($disk)
    }
    docker = [ordered]@{
        available = $dockerAvailable
        cpus = if ($dockerAvailable) { $dockerInfo.NCPU } else { $null }
        memoryGiB = if ($dockerAvailable) { [math]::Round($dockerInfo.MemTotal / 1GB, 2) } else { $null }
        samples = @($containerSamples)
    }
}

$report | ConvertTo-Json -Depth 8 | Set-Content -Path $output -Encoding UTF8
Write-Host "Capacity report written to $output"
Write-Host "Review it before selecting the 8, 16, or 24 GiB deployment tier."
if ($dockerAvailable -and $containerSamples.Count -eq 0) {
    Write-Warning 'Docker was available, but no running containers were sampled. Start each representative stack and measure again before migration.'
}
if (($disk | Measure-Object FreeGiB -Minimum).Minimum -lt 80) {
    Write-Warning 'A fixed disk has less than 80 GiB free. Add or free storage before creating the planned persistent volumes.'
}
