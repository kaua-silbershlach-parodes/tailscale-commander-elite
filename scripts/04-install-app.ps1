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
$BundleDir = Join-Path $WorkFolder 'tailscale-commander-elite\src-tauri\target\release\bundle\nsis'

$setup = Get-ChildItem $BundleDir -Filter '*setup*.exe' |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $setup) { throw 'No Setup.exe found. Run script 03 first.' }
$sig = Get-Item "$($setup.FullName).sig" -ErrorAction SilentlyContinue
if (-not $sig) { throw "Setup has no paired signature: $($setup.Name). Refusing to install." }
$hash = (Get-FileHash $setup.FullName -Algorithm SHA256).Hash
Write-Host "Setup verified: paired signature present, SHA256 $hash"

Write-Host "Installing silently: $($setup.FullName)"
$installer = Start-Process $setup.FullName -ArgumentList '/S' -Wait -PassThru
if ($installer.ExitCode -ne 0) { throw "Installer failed (exit $($installer.ExitCode))." }

$installDir = Join-Path $env:LOCALAPPDATA 'Tailscale Commander Elite'
$appExe = Join-Path $installDir 'tailscale-commander-elite.exe'
$deadline = (Get-Date).AddSeconds(90)
while (-not (Test-Path $appExe)) {
    if ((Get-Date) -gt $deadline) { throw "Install incomplete: $appExe not found." }
    Start-Sleep -Seconds 3
}

$version = (Get-Item $appExe).VersionInfo.FileVersion
if (-not $version) { throw 'Installed exe has no readable FileVersion.' }
Write-Host "INSTALL OK: version $version at $installDir"
