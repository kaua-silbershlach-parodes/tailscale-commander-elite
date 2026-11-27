# 04-install-app.ps1
# Installs the built app SILENTLY (Tauri NSIS Setup with /S):
# per-user, no wizard interaction, no admin rights. Verifies the
# installed layout afterwards, waiting for the installer to finish.
#
# -Drive is a PARAMETER on purpose: drive letters change per machine.
# It only locates the built Setup (work folder defaults to
# <Drive>:\TailscaleCommanderElite, as in scripts 02/03). The app itself
# installs per-user into %LocalAppData%\Tailscale Commander Elite -
# the NSIS per-user layout, not drive-selectable.
#
# Usage (PowerShell):
#   .\04-install-app.ps1 -Drive 'F'
#
# Requires: script 03 completed (the Setup.exe exists).

param(
    [Parameter(Mandatory = $true)]
    [string]$Drive,
    [string]$WorkFolder
)

$ErrorActionPreference = 'Stop'
if (-not $WorkFolder) { $WorkFolder = "${Drive}:\TailscaleCommanderElite" }
$Project = Join-Path $WorkFolder 'tailscale-commander-elite'
$Conf = Join-Path $Project 'src-tauri\tauri.conf.json'
& python (Join-Path $Project 'tools\release_preflight.py')
if ($LASTEXITCODE -ne 0) { throw 'Release preflight failed; no installer executed.' }
$expected = (Get-Content $Conf -Raw | ConvertFrom-Json).version
$BundleDir = Join-Path $Project 'src-tauri\target\release\bundle\nsis'

if ($expected -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { throw 'Invalid expected version.' }
$setup = Get-Item -LiteralPath (Join-Path $BundleDir "Tailscale Commander Elite_${expected}_x64-setup.exe") -ErrorAction Stop
if (-not $setup) { throw 'No Setup.exe found. Run script 03 first.' }
$sig = Get-Item "$($setup.FullName).sig" -ErrorAction SilentlyContinue
if (-not $sig) { throw "Setup has no paired signature: $($setup.Name). Refusing to install." }
# Keep both verified files open without write/delete sharing until execution finishes.
$artifactLock = [IO.File]::Open($setup.FullName, 'Open', 'Read', 'Read')
$signatureLock = $null
try {
    $signatureLock = [IO.File]::Open($sig.FullName, 'Open', 'Read', 'Read')
    & python (Join-Path $Project "tools\verify_release.py") --config $Conf artifact $setup.FullName $sig.FullName
    if ($LASTEXITCODE -ne 0) { throw "Installer signature verification failed." }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = [BitConverter]::ToString($sha.ComputeHash($artifactLock)).Replace('-', '').ToLower() }
    finally { $sha.Dispose() }
    Write-Host "Setup verified: cryptographic signature valid, SHA256 $hash"
    $installer = Start-Process $setup.FullName -ArgumentList '/S' -Wait -PassThru
    if ($installer.ExitCode -ne 0) { throw "Installer failed (exit $($installer.ExitCode))." }
} finally {
    if ($signatureLock) { $signatureLock.Dispose() }
    $artifactLock.Dispose()
}

$installDir = Join-Path $env:LOCALAPPDATA 'Tailscale Commander Elite'
$appExe = Join-Path $installDir 'tailscale-commander-elite.exe'
$deadline = (Get-Date).AddSeconds(90)
while (-not (Test-Path $appExe)) {
    if ((Get-Date) -gt $deadline) { throw "Install incomplete: $appExe not found." }
    Start-Sleep -Seconds 3
}

$version = (Get-Item $appExe).VersionInfo.FileVersion
if (-not $version) { throw 'Installed exe has no readable FileVersion.' }
if ($version -notin @($expected, "$expected.0")) { throw "Installed version $version differs from $expected." }
Write-Host "INSTALL OK: version $version at $installDir"
