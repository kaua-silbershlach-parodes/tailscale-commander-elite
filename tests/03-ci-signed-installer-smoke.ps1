# Hosted-runner-only signed NSIS smoke test. Never uses production secrets.
# Run AFTER unsigned tests/build. The checked-out config remains unchanged.
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or $env:RUNNER_OS -ne 'Windows') {
    throw 'This test is restricted to disposable GitHub-hosted Windows runners.'
}
if ($env:TAURI_SIGNING_PRIVATE_KEY -or $env:TAURI_SIGNING_PRIVATE_KEY_PASSWORD -or $env:TAURI_SIGNING_PRIVATE_KEY_PATH) {
    throw 'Unexpected signing credentials in test environment.'
}
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tauri = Join-Path $repo 'src-tauri'
$config = Join-Path $tauri 'tauri.conf.json'
$conf = Get-Content -LiteralPath $config -Raw | ConvertFrom-Json
$version = $conf.version
if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { throw 'Invalid candidate version.' }
if ($conf.productName -ne 'Tailscale Commander Elite' -or $conf.bundle.windows.nsis.installMode -ne 'currentUser') {
    throw 'Unexpected installation scope.'
}
$install = Join-Path $env:LOCALAPPDATA $conf.productName
$bundle = Join-Path $tauri 'target\release\bundle\nsis'
if ((Test-Path -LiteralPath $install) -or (Test-Path -LiteralPath $bundle)) {
    throw 'Test requires a clean install and bundle directory.'
}
$temp = Join-Path $env:RUNNER_TEMP ('tce-install-test-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
$originalPath = $env:Path
$proc = $null
$installedByTest = $false
try {
    $bin = Join-Path $temp 'verifier'
    & python (Join-Path $repo 'tools\bootstrap_minisign_windows.py') --bin-dir $bin
    if ($LASTEXITCODE -ne 0) { throw 'Windows verifier provisioning failed.' }
    $env:Path = "$bin;$env:Path"
    & cargo install tauri-cli --version 2.12.6 --locked
    if ($LASTEXITCODE -ne 0) { throw 'Tauri CLI install failed.' }
    $key = Join-Path $temp 'test.key'
    Push-Location $tauri
    try {
        & cargo tauri signer generate --ci -w $key
        if ($LASTEXITCODE -ne 0) { throw 'Ephemeral key generation failed.' }
        $publicKey = (Get-Content -LiteralPath "$key.pub" -Raw).Trim()
        if (-not $publicKey -or $publicKey -eq $conf.plugins.updater.pubkey) { throw 'Invalid ephemeral key.' }
        $conf.plugins.updater.pubkey = $publicKey
        $testConfig = Join-Path $temp 'candidate-config.json'
        $conf | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $testConfig -Encoding utf8
        $env:TAURI_SIGNING_PRIVATE_KEY = $key
        $env:TAURI_SIGNING_PRIVATE_KEY_PASSWORD = ''
        & cargo tauri build --ci --bundles nsis --config $testConfig -- --locked
        if ($LASTEXITCODE -ne 0) { throw 'Ephemeral signed bundle build failed.' }
    } finally {
        Remove-Item Env:TAURI_SIGNING_PRIVATE_KEY -ErrorAction SilentlyContinue
        Remove-Item Env:TAURI_SIGNING_PRIVATE_KEY_PASSWORD -ErrorAction SilentlyContinue
        Pop-Location
    }
    $setup = Get-Item -LiteralPath (Join-Path $bundle "Tailscale Commander Elite_$($version)_x64-setup.exe") -ErrorAction Stop
    $sig = Get-Item -LiteralPath "$($setup.FullName).sig" -ErrorAction Stop
    $artifactLock = [IO.File]::Open($setup.FullName, 'Open', 'Read', 'Read')
    $signatureLock = $null
    try {
        $signatureLock = [IO.File]::Open($sig.FullName, 'Open', 'Read', 'Read')
        & python (Join-Path $repo 'tools\verify_release.py') --config $testConfig artifact $setup.FullName $sig.FullName
        if ($LASTEXITCODE -ne 0) { throw 'Ephemeral installer signature rejected.' }
        $installedByTest = $true
        $installer = Start-Process -FilePath $setup.FullName -ArgumentList '/S' -Wait -PassThru
        if ($installer.ExitCode -ne 0) { throw "Installer exit $($installer.ExitCode)" }
    } finally {
        if ($signatureLock) { $signatureLock.Dispose() }
        $artifactLock.Dispose()
    }
    $app = Get-Item -LiteralPath (Join-Path $install 'tailscale-commander-elite.exe') -ErrorAction Stop
    if ($app.VersionInfo.FileVersion -notin @($version,"$version.0")) { throw 'Installed version mismatch.' }
    $proc = Start-Process -FilePath $app.FullName -PassThru
    Start-Sleep -Seconds 10
    if (-not (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) { throw 'Installed application did not remain running.' }
    Write-Output "SIGNED NSIS CANDIDATE SMOKE PASSED: $version (ephemeral key, not production)"
} finally {
    $env:Path = $originalPath
    try {
        if ($proc -and (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            $proc.WaitForExit()
        }
        if ($installedByTest -and (Test-Path -LiteralPath $install)) {
            $uninstaller = @(Get-ChildItem -LiteralPath $install -Filter 'uninstall*.exe' -File)
            if ($uninstaller.Count -ne 1) { throw 'Expected exactly one test uninstaller.' }
            $u = Start-Process -FilePath $uninstaller[0].FullName -ArgumentList '/S' -Wait -PassThru
            if ($u.ExitCode -ne 0 -or (Test-Path -LiteralPath (Join-Path $install 'tailscale-commander-elite.exe'))) {
                throw 'Candidate uninstall failed.'
            }
            Write-Output 'CANDIDATE UNINSTALL PASSED'
        }
    } finally {
        # The directory was created uniquely for this test and holds only test material.
        Remove-Item -LiteralPath $temp -Recurse -Force
    }
}
