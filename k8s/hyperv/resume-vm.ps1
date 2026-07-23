param(
    [string]$VmName = 'local-k3s-server',
    [string]$VmRoot = 'D:\HyperV\local-k3s-server',
    [string]$SourceVhd = 'D:\HyperV\local-k3s-server\ubuntu-k3s.vhd',
    [string]$SeedIso = 'D:\HyperV\seed\k3s-seed.iso',
    [string]$ResultPath = 'D:\HyperV\local-k3s-server-result.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    if (Get-VM -Name $VmName -ErrorAction SilentlyContinue) {
        throw "VM '$VmName' already exists; refusing to overwrite it."
    }
    foreach ($requiredPath in @($SourceVhd, $SeedIso)) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "Required file does not exist: $requiredPath"
        }
    }

    $vmVhd = Join-Path $VmRoot 'ubuntu-k3s.vhdx'
    if (-not (Test-Path -LiteralPath $vmVhd)) {
        & compact.exe /u /i /q $SourceVhd | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to remove NTFS compression from $SourceVhd"
        }
        & fsutil.exe sparse setflag $SourceVhd 0 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to remove the sparse-file flag from $SourceVhd"
        }
        Convert-VHD -Path $SourceVhd -DestinationPath $vmVhd -VHDType Dynamic
    }
    Resize-VHD -Path $vmVhd -SizeBytes 150GB

    $preferred = Get-VMSwitch -Name 'Default Switch' -ErrorAction SilentlyContinue
    if (-not $preferred) {
        $preferred = Get-VMSwitch | Select-Object -First 1
    }
    if (-not $preferred) {
        throw 'No Hyper-V switch is available.'
    }

    New-VM -Name $VmName -Generation 1 -MemoryStartupBytes 8GB -VHDPath $vmVhd `
        -Path $VmRoot -SwitchName $preferred.Name | Out-Null
    Set-VMMemory -VMName $VmName -DynamicMemoryEnabled $true `
        -MinimumBytes 4GB -StartupBytes 8GB -MaximumBytes 10GB
    Set-VMProcessor -VMName $VmName -Count 6
    Set-VM -Name $VmName -AutomaticStartAction Start -AutomaticStartDelay 15 `
        -AutomaticStopAction ShutDown -AutomaticCheckpointsEnabled $false
    Set-VMNetworkAdapter -VMName $VmName -DhcpGuard On -RouterGuard On
    Add-VMDvdDrive -VMName $VmName -Path $SeedIso
    Set-VMBios -VMName $VmName -StartupOrder @('IDE', 'CD', 'LegacyNetworkAdapter', 'Floppy')
    Start-VM -Name $VmName | Out-Null

    $report = [ordered]@{
        succeeded = $true
        vm = Get-VM -Name $VmName |
            Select-Object Name, State, Generation, ProcessorCount, MemoryAssigned, Path
        network = Get-VMNetworkAdapter -VMName $VmName |
            Select-Object SwitchName, MacAddress, IPAddresses
        disk = Get-VHD -Path $vmVhd |
            Select-Object Path, VhdType, FileSize, Size
    }
} catch {
    $report = [ordered]@{
        succeeded = $false
        error = $_.Exception.Message
        stack = $_.ScriptStackTrace
    }
}

$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
if (-not $report.succeeded) {
    exit 1
}
