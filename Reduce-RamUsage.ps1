[CmdletBinding(SupportsShouldProcess)]
param(
    [string[]]$Application = @(
        'chrome',
        'msedge',
        'PhoneExperienceHost'
    ),

    [switch]$Force
)

function Get-MemorySnapshot {
    $os = Get-CimInstance Win32_OperatingSystem

    [pscustomobject]@{
        TotalRAM_GB     = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        AvailableRAM_GB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        UsedRAM_GB      = [math]::Round(
            ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB,
            2
        )
    }
}

function Get-ApplicationMemory {
    param([string[]]$Names)

    Get-Process -ErrorAction SilentlyContinue |
        Where-Object Name -In $Names |
        Group-Object Name |
        ForEach-Object {
            [pscustomobject]@{
                Name      = $_.Name
                Processes = $_.Count
                RAM_MB    = [math]::Round(
                    ($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB
                )
            }
        } |
        Sort-Object RAM_MB -Descending
}

Write-Host "`nMemory before:" -ForegroundColor Cyan
Get-MemorySnapshot | Format-Table -AutoSize

$running = Get-ApplicationMemory -Names $Application

if (-not $running) {
    Write-Host "None of the selected optional applications are running."
    return
}

Write-Host "Optional applications currently using RAM:" -ForegroundColor Cyan
$running | Format-Table -AutoSize

Write-Warning "Closing applications can discard unsaved work and close browser windows."

foreach ($name in $running.Name) {
    $processes = Get-Process -Name $name -ErrorAction SilentlyContinue
    if (-not $processes) {
        continue
    }

    $shouldClose = $Force
    if (-not $Force) {
        $answer = Read-Host "Close all '$name' processes? [y/N]"
        $shouldClose = $answer -match '^(y|yes)$'
    }

    if ($shouldClose -and $PSCmdlet.ShouldProcess($name, 'Close application processes')) {
        $processes | Stop-Process -ErrorAction Continue
    }
}

Start-Sleep -Seconds 2

Write-Host "`nMemory after:" -ForegroundColor Cyan
Get-MemorySnapshot | Format-Table -AutoSize

Write-Host @"
Windows cache, memory compression, Defender, Registry, and Explorer were left alone.
Available RAM may not change immediately because Windows manages cache automatically.
"@
