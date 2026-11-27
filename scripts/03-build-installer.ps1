# 03-build-installer.ps1
# Builds the NSIS installer only after release preflight and strict audit.
# Requires an existing, restricted signing key matching the pinned public key.
# Never generates a replacement key or modifies key directory permissions.
#
# -Drive is a PARAMETER on purpose: drive letters change per machine.
# The work folder defaults to <Drive>:\TailscaleCommanderElite (same rule as
# script 02) and can be overridden with -WorkFolder.
#
# Usage (PowerShell):
#   .\03-build-installer.ps1 -Drive 'F'
#
# Requires: scripts 01 and 02 completed. Outputs in
# <clone>\src-tauri\target\release\bundle\: the NSIS Setup and its
# signature (.sig) - the signed Setup is itself the updater
# artifact. Publishing a release is a separate, deliberate step
# (see the README): upload the Setup, the .sig and a latest.json
# to a GitHub release with GH_TOKEN.

param(
    [Parameter(Mandatory = $true)]
    [string]$Drive,
    [string]$WorkFolder
)

$ErrorActionPreference = 'Stop'
if (-not $WorkFolder) { $WorkFolder = "${Drive}:\TailscaleCommanderElite" }
$Project = Join-Path $WorkFolder 'tailscale-commander-elite'
$TauriDir = Join-Path $Project 'src-tauri'
$Conf = Join-Path $TauriDir 'tauri.conf.json'
if (-not (Test-Path $Conf)) { throw "Project not found at $Project. Run script 02 first." }

& python (Join-Path $Project 'tools\release_preflight.py')
if ($LASTEXITCODE -ne 0) { throw 'Release preflight failed; no signing key accessed.' }
$dirty = & git -C $Project status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Release checkout must be clean.' }
Push-Location $TauriDir
try {
    & python (Join-Path $Project "tools\dependency_policy.py")
    if ($LASTEXITCODE -ne 0) { throw 'Dependency risk policy failed; no signing key accessed.' }
} finally { Pop-Location }
Get-Command minisign -CommandType Application -ErrorAction Stop | Out-Null

$KeyDir = Join-Path $env:USERPROFILE '.tailscale-commander-elite'
$KeyFile = Join-Path $KeyDir 'updater-private.key'
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
function Assert-RestrictedKeyAcl([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Signing key path is a reparse point: $Path" }
    $acl = Get-Acl -LiteralPath $Path
    if ($acl.GetOwner([System.Security.Principal.SecurityIdentifier]).Value -ne $sid) {
        throw "Signing key path has an unexpected owner: $Path"
    }
    foreach ($rule in $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])) {
        if ($rule.AccessControlType -eq 'Allow' -and $rule.IdentityReference.Value -notin @($sid, 'S-1-5-18')) {
            throw "Signing key path grants access to an unexpected principal: $Path"
        }
    }
}
if (-not (Test-Path -LiteralPath $KeyDir -PathType Container)) { throw 'Provision the matching restricted key directory separately.' }
Assert-RestrictedKeyAcl $KeyDir
if (-not (Test-Path -LiteralPath $KeyFile -PathType Leaf)) { throw 'Matching private key must be provisioned separately.' }
Assert-RestrictedKeyAcl $KeyFile
$pubFile = "$KeyFile.pub"
if (-not (Test-Path -LiteralPath $pubFile -PathType Leaf)) { throw 'Matching public key file is missing.' }
Assert-RestrictedKeyAcl $pubFile
$pubKey = (Get-Content -LiteralPath $pubFile -Raw).Trim()
$confJson = Get-Content -LiteralPath $Conf -Raw | ConvertFrom-Json
if (-not $pubKey -or $confJson.plugins.updater.pubkey -ne $pubKey -or $pubKey -eq 'UPDATER_PUBKEY_PLACEHOLDER') {
    throw 'The public key must match the pinned configuration. No key generation or configuration rewrite allowed.'
}

$version = $null
if ((Get-Content $Conf -Raw) -match '"version"\s*:\s*"([^"]+)"') { $version = $Matches[1] }
& python (Join-Path $Project 'tools\bootstrap_tunnel_windows.py') --bundle --bin-dir (Join-Path $Project 'src-tauri\tunnel-runtime')
if ($LASTEXITCODE -ne 0) { throw 'Verified tunnel runtime provisioning failed.' }

Write-Host "Building version $version (cargo tauri build - this compiles the release binary)..."

$env:TAURI_SIGNING_PRIVATE_KEY = (Get-Content $KeyFile -Raw)
try {
    Push-Location $TauriDir
    try {
        & cargo tauri build --bundles nsis -- --locked
        $buildRc = $LASTEXITCODE
    } finally { Pop-Location }
} finally {
    Remove-Item Env:TAURI_SIGNING_PRIVATE_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:TAURI_SIGNING_PRIVATE_KEY_PASSWORD -ErrorAction SilentlyContinue
}
if ($buildRc -ne 0) { throw "Build failed (cargo tauri exit $buildRc)." }

$bundleDir = Join-Path $TauriDir 'target\release\bundle\nsis'
if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { throw 'Invalid build version.' }
$setup = Get-Item -LiteralPath (Join-Path $bundleDir "Tailscale Commander Elite_${version}_x64-setup.exe") -ErrorAction Stop
if (-not $setup) { throw "Missing Setup for version $version in $bundleDir." }
$sig = Get-Item "$($setup.FullName).sig" -ErrorAction SilentlyContinue
if (-not $sig) { throw "Missing signature for $($setup.Name)." }
& python (Join-Path $Project "tools\verify_release.py") --config $Conf artifact $setup.FullName $sig.FullName
if ($LASTEXITCODE -ne 0) { throw "Installer signature verification failed." }
$stream = [IO.File]::OpenRead($setup.FullName)
$sha = [Security.Cryptography.SHA256]::Create()
try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
finally { $sha.Dispose(); $stream.Dispose() }

Write-Host "BUILD OK: $($setup.Name) ($($setup.Length) bytes, SHA256 $hash) + signature, in $bundleDir"
