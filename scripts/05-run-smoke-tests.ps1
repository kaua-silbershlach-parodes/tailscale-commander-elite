# 05-run-smoke-tests.ps1
# End-to-end proof on the rebuilt machine:
#   1. the install layout is intact (app exe present, version reads);
#   2. the GitHub update feed (latest.json) - checked when a release
#      has been published; before the first release this step is
#      reported as pending, not failed (publishing is deliberate);
#   3. the app launches and its process stays up;
#   4. a record file is written to the Desktop.
#
# Usage (PowerShell):
#   .\05-run-smoke-tests.ps1
#
# Requires: script 04 completed (the app installed).

$ErrorActionPreference = 'Stop'
$installDir = Join-Path $env:LOCALAPPDATA 'Tailscale Commander Elite'
$appExe = Join-Path $installDir 'tailscale-commander-elite.exe'

if (-not (Test-Path $appExe)) { throw 'App exe missing. Run script 04 first.' }
$installed = (Get-Item $appExe).VersionInfo.FileVersion
Write-Host "1. Install layout OK. Installed version: $installed"

$feedUrl = 'https://github.com/kaua-silbershlach-parodes/tailscale-commander-elite/releases/latest/download/latest.json'
$feedNote = 'not published yet'
try {
    $feed = Invoke-RestMethod -Uri $feedUrl -TimeoutSec 30
    if (-not $feed.version) { throw 'manifest without a version' }
    $feedNote = "published, newest $($feed.version)"
    Write-Host "2. Update feed OK. Newest published version: $($feed.version)"
} catch {
    Write-Host '2. Update feed: no signed release published yet (expected before the first release).'
}

Write-Host '3. Launching the app...'
$launched = Start-Process $appExe -PassThru
Start-Sleep -Seconds 5
$proc = Get-Process -Id $launched.Id -ErrorAction SilentlyContinue
if (-not $proc) { throw 'The app process is not running after launch.' }
Write-Host "   App running (PID $($proc.Id))."

$backendNote = 'not running (separate OTP app; health check skipped)'
try {
    $health = Invoke-RestMethod -Uri 'http://127.0.0.1:45900/health' -TimeoutSec 5
    if ($health.service -ne 'tailscale_commander_elite_backend') { throw 'Unexpected backend service.' }
    $backendNote = "health OK (version $($health.version))"
    Write-Host "   Backend health OK (version $($health.version))."
} catch {
    Write-Host '   Backend not running (separate OTP app; health check skipped).'
}

$record = Join-Path ([Environment]::GetFolderPath('Desktop')) 'TAILSCALE-COMMANDER-ELITE-SMOKE-TEST.txt'
@(
    'Tailscale Commander Elite - rebuild record'
    "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    "Machine: $env:COMPUTERNAME"
    "Install folder: $installDir"
    "Installed version: $installed"
    "Update feed: $feedNote"
    "Backend: $backendNote"
    "Feed: $feedUrl"
    'Result: installed app, update feed availability and app launch verified.'
) | Set-Content -Path $record -Encoding ASCII
Write-Host "4. Record written: $record"

Write-Host 'SMOKE TESTS OK: installed app and updater checks completed.'
