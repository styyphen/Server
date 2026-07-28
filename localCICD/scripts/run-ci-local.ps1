[CmdletBinding()]
param(
    [ValidateSet("act", "dagger")]
    [string] $Engine = "act",

    [string] $EventName = "pull_request",

    [string] $Workflow = "",

    [string] $Job = "",

    [string] $ContainerArchitecture = "linux/amd64",

    [string] $EventPath = "",

    [string] $ActImage = "catthehacker/ubuntu:act-latest",

    [string] $DaggerArgs = "restore lint build test scan package",

    [switch] $List,

    [switch] $DryRun
)

$ErrorActionPreference = "Stop"

function Resolve-Command {
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required command '$Name' was not found on PATH."
    }

    return $command.Source
}

function Invoke-LoggedCommand {
    param(
        [Parameter(Mandatory)]
        [string] $Executable,

        [Parameter(Mandatory)]
        [string[]] $Arguments
    )

    Write-Host "Running: $Executable $($Arguments -join ' ')"
    if ($DryRun) {
        return
    }

    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE."
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

if ($Engine -eq "act") {
    $act = if ($DryRun) { "act" } else { Resolve-Command "act" }
    $arguments = @(
        $EventName,
        "--container-architecture", $ContainerArchitecture,
        "-P", "ubuntu-latest=$ActImage"
    )

    if ($Workflow) {
        $arguments += @("-W", $Workflow)
    }

    if ($Job) {
        $arguments += @("-j", $Job)
    }

    if ($EventPath) {
        $arguments += @("--eventpath", $EventPath)
    }

    if ($List) {
        $arguments += "--list"
    }

    Invoke-LoggedCommand -Executable $act -Arguments $arguments
    return
}

$dagger = if ($DryRun) { "dagger" } else { Resolve-Command "dagger" }
$daggerArguments = @("call") + ($DaggerArgs -split "\s+" | Where-Object { $_ })
Invoke-LoggedCommand -Executable $dagger -Arguments $daggerArguments
