# 01-install-prerequisites.ps1
# Installs everything a freshly formatted Windows machine needs to
# build this template: Git, the Rust toolchain (rustup + stable,
# MSVC host), the Visual Studio Build Tools (C++ workload - the
# linker Rust needs on Windows), the WebView2 runtime, the Tauri
# CLI, and the BEAM toolchain for the backend: Erlang/OTP + Elixir.
#
# -Drive is a PARAMETER on purpose: drive letters change per machine.
# Rust lives on the chosen drive: RUSTUP_HOME = <Drive>:\rust\rustup
# and CARGO_HOME = <Drive>:\rust\cargo (user-level environment).
# rustup-init.exe is verified by EXACT SIZE and SHA256 (official
# .sha256 file) before it runs. The Build Tools are system-level
# (winget installs them in the default location). Everything silent.
#
# Usage (PowerShell):
#   .\01-install-prerequisites.ps1 -Drive 'F'
#
# Requires: Windows 10/11 x64, internet access and sufficient free space.
# If WinGet is absent, provision pinned Microsoft App Installer packages.
# Prefer an INTERNAL drive for the Rust and BEAM homes.

param(
    [Parameter(Mandatory = $true)]
    [string]$Drive
)

$ErrorActionPreference = 'Stop'
if ($Drive -notmatch '^[A-Za-z]$') { throw 'Drive must be one drive letter.' }
$downloadRoot = Join-Path $env:TEMP ('tce-prerequisites-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $downloadRoot -ErrorAction Stop | Out-Null
try {

$RustupHome = "${Drive}:\rust\rustup"
$CargoHome = "${Drive}:\rust\cargo"


# Official Microsoft WinGet v1.29.380; exact release asset digests and
# architecture-specific dependencies. No Store account, unsigned package,
# developer mode, policy change or signature-validation bypass is required.
function Get-PinnedFile([string]$Url,[string]$Path,[long]$Size,[string]$Sha256) {
    & curl.exe --fail --location --silent --show-error --max-time 600 --output $Path $Url
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Url" }
    if ((Get-Item -LiteralPath $Path).Length -ne $Size) { throw 'Pinned asset size mismatch.' }
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $actual = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose(); $stream.Dispose() }
    if ($actual -ne $Sha256) { throw 'Pinned asset SHA256 mismatch.' }
    Write-Host "Verified $([IO.Path]::GetFileName($Path))"
}

function Find-RegisteredWinGet {
    $pkg = @(Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction Stop |
        Where-Object { $_.PackageFamilyName -eq 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -and $_.Status -eq 'Ok' })
    if ($pkg.Count -ne 1) { return $null }
    $exe = Join-Path $pkg[0].InstallLocation 'winget.exe'
    if (Test-Path -LiteralPath $exe -PathType Leaf) { return $exe }
    return $null
}

$wingetExe = Find-RegisteredWinGet
if (-not $wingetExe) {
    if (-not [Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
        throw 'The pinned WinGet bootstrap supports native Windows x64 only.'
    }
    if ([Environment]::OSVersion.Version.Build -lt 17763) { throw 'Unsupported Windows build.' }
    Write-Host 'WinGet absent; provisioning pinned Microsoft App Installer.'
    $base = 'https://github.com/microsoft/winget-cli/releases/download/v1.29.380/'
    $depsZip = Join-Path $downloadRoot 'DesktopAppInstaller_Dependencies.zip'
    $bundle = Join-Path $downloadRoot 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
    Get-PinnedFile ($base+'DesktopAppInstaller_Dependencies.zip') $depsZip 97760717 'ba875afe9d190f61218985ac0292a99d1db710bf93e13c68944ca9d89f0d82d1'
    Get-PinnedFile ($base+'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle') $bundle 217276577 '65dea9c01ce08ee7b763366b27c0e651f97db857c11ca9b9c301826c10092f2e'
    $depsRoot = Join-Path $downloadRoot 'dependencies'
    New-Item -ItemType Directory -Path $depsRoot -ErrorAction Stop | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($depsZip)
    $required = @(
        'Microsoft.VCLibs.140.00_14.0.33519.0_x64.appx',
        'Microsoft.VCLibs.140.00.UWPDesktop_14.0.33728.0_x64.appx',
        'Microsoft.WindowsAppRuntime.1.8_8000.616.304.0_x64.appx'
    )
    $dependencyPaths = @()
    try {
        foreach ($name in $required) {
            $entry = @($zip.Entries | Where-Object { $_.FullName -ceq ('x64/'+$name) })
            if ($entry.Count -ne 1 -or $entry[0].Length -le 0 -or $entry[0].Length -gt 200MB) {
                throw "Missing, ambiguous or oversized pinned dependency: $name"
            }
            $target = Join-Path $depsRoot $name
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry[0],$target,$false)
            $dependencyPaths += $target
        }
    } finally { $zip.Dispose() }
    # Windows AppX deployment enforces signature and publisher trust.
    Add-AppxPackage -Path $bundle -DependencyPath $dependencyPaths -ErrorAction Stop
    $wingetExe = Find-RegisteredWinGet
    if (-not $wingetExe) { throw 'App Installer was not registered for this user.' }
}
& $wingetExe --version
if ($LASTEXITCODE -ne 0) { throw 'WinGet version check failed.' }
Write-Host 'WinGet verified and ready.'

Write-Host 'Installing Git...'
& $wingetExe install --source winget --disable-interactivity --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements
if ($LASTEXITCODE -ne 0) { throw "Git install failed (winget exit $LASTEXITCODE)." }

Write-Host 'Installing Python (release verification tooling)...'
& $wingetExe install --source winget --disable-interactivity --id Python.Python.3.12 -e --silent --accept-source-agreements --accept-package-agreements
if ($LASTEXITCODE -ne 0) { throw "Python install failed (winget exit $LASTEXITCODE)." }
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
Write-Host 'Installing Visual Studio Build Tools (C++ workload)...'
& $wingetExe install --source winget --disable-interactivity --id Microsoft.VisualStudio.2022.BuildTools -e --silent --accept-source-agreements --accept-package-agreements --override '--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
if ($LASTEXITCODE -ne 0) { throw "Build Tools install failed (winget exit $LASTEXITCODE)." }

Write-Host 'Installing the WebView2 runtime...'
& $wingetExe install --source winget --disable-interactivity --id Microsoft.EdgeWebView2Runtime -e --silent --accept-source-agreements --accept-package-agreements
if ($LASTEXITCODE -ne 0) {
    # A failed installer is not proof that a runtime exists.
    $roots = @(
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients',
        'HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients',
        'HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients'
    )
    $runtime = foreach ($root in $roots) {
        if (Test-Path -LiteralPath $root) {
            Get-ChildItem -LiteralPath $root | ForEach-Object {
                $entry = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction Stop
                if ($entry.name -eq 'Microsoft Edge WebView2 Runtime' -and $entry.pv -and $entry.pv -ne '0.0.0.0') { $entry }
            }
        }
    }
    if (-not $runtime) { throw 'WebView2 runtime installation failed and no installed runtime was found.' }
}

$RustupUrl = 'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe'
$ExactSize = 12839424
$ExactSha256 = '38027d51d69a5d05493627a0634dbea52d6cd793c8f072d2373d3f4163eec7db'
$init = Join-Path $downloadRoot 'rustup-init.exe'
if ((Test-Path $init) -and (Get-Item $init).Length -ne $ExactSize) { Remove-Item $init -Force }
if (-not (Test-Path $init)) {
    Write-Host 'Downloading rustup-init.exe...'
    & curl.exe -L --fail -o $init $RustupUrl
    if ($LASTEXITCODE -ne 0) { throw "rustup-init download failed (curl exit $LASTEXITCODE)." }
}
if ((Get-Item $init).Length -ne $ExactSize) { throw 'rustup-init size mismatch. Aborting.' }
$sha = (certutil -hashfile $init SHA256 | Select-Object -Index 1).Trim().ToLower()
if ($sha -ne $ExactSha256) { throw "rustup-init SHA256 mismatch ($sha). Aborting." }
Write-Host 'rustup-init verified: exact size and SHA256.'

[Environment]::SetEnvironmentVariable('RUSTUP_HOME', $RustupHome, 'User')
[Environment]::SetEnvironmentVariable('CARGO_HOME', $CargoHome, 'User')
$env:RUSTUP_HOME = $RustupHome
$env:CARGO_HOME = $CargoHome
Write-Host "Installing Rust (stable, MSVC) into $RustupHome / $CargoHome ..."
& $init -y --default-toolchain 1.100.0 --profile minimal --no-modify-path
if ($LASTEXITCODE -ne 0) { throw "rustup install failed (exit $LASTEXITCODE)." }

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$CargoHome\bin*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$CargoHome\bin", 'User')
}
$env:Path = "$env:Path;$CargoHome\bin"

$rustc = & rustc --version
if ($LASTEXITCODE -ne 0) { throw 'rustc version check failed.' }
$cargo = & cargo --version
if ($LASTEXITCODE -ne 0) { throw 'cargo version check failed.' }
Write-Host "Rust OK: $rustc | $cargo"

Write-Host 'Installing the Tauri CLI (compiles from source, takes a few minutes)...'
& cargo install tauri-cli --version 2.12.6 --locked
if ($LASTEXITCODE -ne 0) { throw "tauri-cli install failed (exit $LASTEXITCODE)." }
$tauri = & cargo tauri --version
if ($LASTEXITCODE -ne 0) { throw 'Tauri CLI version check failed.' }
Write-Host "Tauri CLI OK: $tauri"

# --- Erlang/OTP 29.1.2 (the BEAM the Elixir backend runs on) ---
# Pin the official GitHub release asset SHA-256, exact size and Authenticode.
$ErlDir = "${Drive}:\erlang"
$ErlExe = Join-Path $downloadRoot 'otp_win64_29.1.2.exe'
$ErlSize = 155770072
if ((Test-Path $ErlExe) -and (Get-Item $ErlExe).Length -ne $ErlSize) { Remove-Item $ErlExe -Force }
if (-not (Test-Path $ErlExe)) {
    Write-Host 'Downloading Erlang/OTP 29.1.2...'
    & curl.exe -L --fail -o $ErlExe 'https://github.com/erlang/otp/releases/download/OTP-29.1.2/otp_win64_29.1.2.exe'
    if ($LASTEXITCODE -ne 0) { throw "Erlang download failed (curl exit $LASTEXITCODE)." }
}
if ((Get-Item $ErlExe).Length -ne $ErlSize) { throw 'Erlang installer size mismatch. Aborting.' }
$ErlSha256 = '38297ee6fa8cafbc016cb187ebda30f7bdae85618415d9dbbbe413e9b9e27a4e'
$erlHash = (certutil -hashfile $ErlExe SHA256 | Select-Object -Index 1).Trim().ToLower()
if ($LASTEXITCODE -ne 0 -or $erlHash -ne $ErlSha256) { throw 'Erlang installer SHA256 mismatch.' }
$sigStatus = (Get-AuthenticodeSignature $ErlExe).Status
if ($sigStatus -ne 'Valid') { throw "Erlang installer Authenticode signature is $sigStatus. Aborting." }
Write-Host 'Erlang installer verified: exact size, official host. Installing silently...'
$erlInstaller = Start-Process $ErlExe -ArgumentList '/S', "/D=$ErlDir" -Wait -PassThru
if ($erlInstaller.ExitCode -ne 0) { throw "Erlang install failed ($($erlInstaller.ExitCode))." }
$erlBin = $null
$deadline = (Get-Date).AddSeconds(240)
while (-not $erlBin) {
    $found = Get-ChildItem $ErlDir -Recurse -Filter 'erl.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $erlBin = $found.DirectoryName }
    elseif ((Get-Date) -gt $deadline) { throw 'Erlang install incomplete: erl.exe not found.' }
    else { Start-Sleep -Seconds 5 }
}
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$erlBin*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$erlBin", 'User')
}
$env:Path = "$env:Path;$erlBin"
$otp = & erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().'
Write-Host "Erlang OK: OTP $otp (bin at $erlBin)"

# --- Elixir 1.20.5 (precompiled for OTP 29) ---
$ExZip = Join-Path $downloadRoot 'elixir-otp-29.zip'
$ExSize = 8643796
$ExSha256 = 'f424d6f0bb710a1d4898f2645d8ad6cab3f5eab8d71848c0dda2579d3a8e8a06'
if ((Test-Path $ExZip) -and (Get-Item $ExZip).Length -ne $ExSize) { Remove-Item $ExZip -Force }
if (-not (Test-Path $ExZip)) {
    Write-Host 'Downloading Elixir 1.20.5...'
    & curl.exe -L --fail -o $ExZip 'https://github.com/elixir-lang/elixir/releases/download/v1.20.5/elixir-otp-29.zip'
    if ($LASTEXITCODE -ne 0) { throw "Elixir download failed (curl exit $LASTEXITCODE)." }
}
if ((Get-Item $ExZip).Length -ne $ExSize) { throw 'Elixir zip size mismatch. Aborting.' }
$exSha = (certutil -hashfile $ExZip SHA256 | Select-Object -Index 1).Trim().ToLower()
if ($exSha -ne $ExSha256) { throw "Elixir zip SHA256 mismatch ($exSha). Aborting." }
Write-Host 'Elixir zip verified: exact size and SHA256.'
$ExDir = "${Drive}:\elixir"
$staging = Join-Path "${Drive}:\" ('elixir-staging-' + [Guid]::NewGuid().ToString('N'))
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Force -Path $staging | Out-Null
& tar.exe -xf $ExZip -C $staging
if ($LASTEXITCODE -ne 0) { throw 'Elixir extraction failed.' }
$bat = Get-ChildItem $staging -Recurse -Filter 'elixir.bat' | Select-Object -First 1
if (-not $bat) { throw 'elixir.bat not found in the extracted zip.' }
$backup = $null
if (Test-Path $ExDir) {
    $backup = $ExDir + '.backup-' + [Guid]::NewGuid().ToString('N')
    Move-Item $ExDir $backup
}
try { Move-Item $bat.Directory.Parent.FullName $ExDir } catch {
    if ($backup -and -not (Test-Path $ExDir)) { Move-Item $backup $ExDir }
    throw
}
Remove-Item $staging -Recurse -Force
if ($backup) { Write-Host "Prior Elixir retained at $backup" }
$exBin = Join-Path $ExDir 'bin'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$exBin*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$exBin", 'User')
}
$env:Path = "$env:Path;$exBin"
$exVer = & elixir --version
if ($LASTEXITCODE -ne 0) { throw 'Elixir version check failed.' }
Write-Host "Elixir OK: $($exVer | Select-Object -Last 1)"

Write-Host 'PREREQUISITES OK: Git, Build Tools, WebView2, Rust, the Tauri CLI, Erlang/OTP and Elixir are installed.'
} finally {
    # Only delete the uniquely named temporary download directory created above.
    if (Test-Path -LiteralPath $downloadRoot) { Remove-Item -LiteralPath $downloadRoot -Recurse -Force }
}
