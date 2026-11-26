# 02-clone-and-check.ps1
# Clones this repository (or updates an existing clone) and runs
# cargo check on the Rust shell. Passes when the whole crate graph
# type-checks on this machine.
#
# -Drive is a PARAMETER on purpose: drive letters change per machine.
# The work folder defaults to <Drive>:\TailscaleCommanderElite and can be
# overridden with -WorkFolder.
#
# Usage (PowerShell):
#   .\02-clone-and-check.ps1 -Drive 'F'
#
# Requires: script 01 completed (Git + Rust).

param(
    [Parameter(Mandatory = $true)]
    [string]$Drive,
    [string]$WorkFolder
)

$ErrorActionPreference = 'Stop'
if (-not $WorkFolder) { $WorkFolder = "${Drive}:\TailscaleCommanderElite" }
$RepoUrl = 'https://github.com/kaua-silbershlach-parodes/tailscale-commander-elite.git'
$Project = Join-Path $WorkFolder 'tailscale-commander-elite'

New-Item -ItemType Directory -Force -Path $WorkFolder | Out-Null

if (Test-Path (Join-Path $Project '.git')) {
    $origin = & git -C $Project remote get-url origin
    if ($origin -ne $RepoUrl) { throw "Unexpected origin: $origin" }
    $dirty = & git -C $Project status --porcelain
    if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Existing clone is not clean. Refusing to pull.' }
    Write-Host 'Existing clone found. Pulling...'
    & git -C $Project pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw "git pull failed (exit $LASTEXITCODE)." }
} else {
    Write-Host 'Cloning the repository...'
    & git clone $RepoUrl $Project
    if ($LASTEXITCODE -ne 0) { throw "git clone failed (exit $LASTEXITCODE)." }
}

Write-Host 'Type-checking the Rust shell (cargo check)...'
& cargo check --locked --manifest-path (Join-Path $Project 'src-tauri\Cargo.toml')
if ($LASTEXITCODE -ne 0) { throw "cargo check failed (exit $LASTEXITCODE)." }

if (Get-Command mix -ErrorAction SilentlyContinue) {
    Write-Host 'Running backend tests (mix test)...'
    Push-Location (Join-Path $Project 'backend')
    $priorPort = $env:TAILSCALE_COMMANDER_ELITE_BACKEND_PORT
    try {
        $env:TAILSCALE_COMMANDER_ELITE_BACKEND_PORT = '0'
        & mix test
        if ($LASTEXITCODE -ne 0) { throw "mix test failed (exit $LASTEXITCODE)." }
    } finally {
        if ($null -eq $priorPort) { Remove-Item Env:TAILSCALE_COMMANDER_ELITE_BACKEND_PORT -ErrorAction SilentlyContinue }
        else { $env:TAILSCALE_COMMANDER_ELITE_BACKEND_PORT = $priorPort }
        Pop-Location
    }
} else {
    throw 'mix not found: mandatory backend tests cannot run (run script 01).'
}

Write-Host "CHECK OK: $Project compiles clean on this machine."
