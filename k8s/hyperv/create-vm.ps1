param(
    [string]$VmName = 'local-k3s-server',
    [string]$VmRoot = 'D:\HyperV\local-k3s-server',
    [string]$SourceArchive = 'D:\HyperV\images\ubuntu-24.04-server-cloudimg-amd64-azure.vhd.tar.gz',
    [string]$SeedIso = 'D:\HyperV\seed\k3s-seed.iso',
    [string]$SwitchName,
    [string]$ResultPath = 'D:\HyperV\local-k3s-server-result.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
    throw 'Hyper-V PowerShell tools are required.'
}
if (Get-VM -Name $VmName -ErrorAction SilentlyContinue) {
    throw "VM '$VmName' already exists; refusing to overwrite it."
}
foreach ($requiredPath in @($SourceArchive, $SeedIso)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required file does not exist: $requiredPath"
    }
}
if (Test-Path -LiteralPath $VmRoot) {
    $existing = Get-ChildItem -LiteralPath $VmRoot -Force
    if ($existing) {
        throw "VM directory is not empty; refusing to overwrite it: $VmRoot"
    }
}

if (-not $SwitchName) {
    $preferred = Get-VMSwitch | Where-Object SwitchType -eq External | Select-Object -First 1
    if (-not $preferred) {
        $preferred = Get-VMSwitch -Name 'Default Switch' -ErrorAction SilentlyContinue
    }
    if (-not $preferred) {
        throw 'No external or Default Switch is available.'
    }
    $SwitchName = $preferred.Name
}

New-Item -ItemType Directory -Path $VmRoot -Force | Out-Null
tar -xf $SourceArchive -C $VmRoot
$sourceVhd = Join-Path $VmRoot 'livecd.ubuntu-cpc.azure.vhd'
if (-not (Test-Path -LiteralPath $sourceVhd)) {
    throw "Expected VHD was not extracted: $sourceVhd"
}
$vmVhd = Join-Path $VmRoot 'ubuntu-k3s.vhd'
Move-Item -LiteralPath $sourceVhd -Destination $vmVhd
Resize-VHD -Path $vmVhd -SizeBytes 150GB

New-VM -Name $VmName -Generation 1 -MemoryStartupBytes 8GB -VHDPath $vmVhd `
    -Path $VmRoot -SwitchName $SwitchName | Out-Null
Set-VMMemory -VMName $VmName -DynamicMemoryEnabled $true `
    -MinimumBytes 4GB -StartupBytes 8GB -MaximumBytes 10GB
Set-VMProcessor -VMName $VmName -Count 6
Set-VM -Name $VmName -AutomaticStartAction Start -AutomaticStartDelay 15 `
    -AutomaticStopAction ShutDown -AutomaticCheckpointsEnabled $false
Set-VMNetworkAdapter -VMName $VmName -DhcpGuard On -RouterGuard On
Add-VMDvdDrive -VMName $VmName -Path $SeedIso
Set-VMBios -VMName $VmName -StartupOrder @('IDE', 'CD', 'LegacyNetworkAdapter', 'Floppy')
Start-VM -Name $VmName | Out-Null

$result = Get-VM -Name $VmName |
    Select-Object Name, State, Generation, ProcessorCount, MemoryAssigned, Path
$result | ConvertTo-Json | Set-Content -LiteralPath $ResultPath -Encoding UTF8
$result
