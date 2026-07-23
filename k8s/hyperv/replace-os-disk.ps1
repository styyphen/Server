param(
    [string]$VmName = 'local-k3s-server',
    [string]$SourceVhd = 'D:\HyperV\local-k3s-server\ubuntu-k3s.vhd',
    [string]$NewVhdx = 'D:\HyperV\local-k3s-server\ubuntu-k3s-azure-seeded.vhdx',
    [string]$ResultPath = 'D:\HyperV\replace-os-disk-result.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $vm = Get-VM -Name $VmName -ErrorAction Stop
    if ($vm.State -ne 'Off') {
        Stop-VM -Name $VmName -Force -TurnOff
    }
    if (-not (Test-Path -LiteralPath $NewVhdx)) {
        Convert-VHD -Path $SourceVhd -DestinationPath $NewVhdx -VHDType Dynamic
        Resize-VHD -Path $NewVhdx -SizeBytes 150GB
    }
    $currentDisk = Get-VMHardDiskDrive -VMName $VmName | Select-Object -First 1
    if (-not $currentDisk) {
        throw "VM '$VmName' has no current OS disk."
    }
    Remove-VMHardDiskDrive -VMHardDiskDrive $currentDisk
    Add-VMHardDiskDrive -VMName $VmName -ControllerType IDE -ControllerNumber 0 `
        -ControllerLocation 0 -Path $NewVhdx
    Start-VM -Name $VmName | Out-Null

    $report = [ordered]@{
        succeeded = $true
        state = (Get-VM -Name $VmName).State.ToString()
        disk = (Get-VMHardDiskDrive -VMName $VmName | Select-Object -First 1).Path
    }
} catch {
    $report = [ordered]@{
        succeeded = $false
        error = $_.Exception.Message
        stack = $_.ScriptStackTrace
    }
}

$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
if (-not $report.succeeded) {
    exit 1
}
