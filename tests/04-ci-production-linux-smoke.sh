#!/usr/bin/env bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true && "${RUNNER_ENVIRONMENT:-}" == github-hosted && "${RUNNER_OS:-}" == Linux ]]
[[ -z "${TAURI_SIGNING_PRIVATE_KEY:-}" && -z "${TAURI_SIGNING_PRIVATE_KEY_PASSWORD:-}" && -z "${TAURI_SIGNING_PRIVATE_KEY_PATH:-}" ]]
cd "$(dirname "$0")/.."
config="${1:-src-tauri/tauri.conf.json}"
version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$config")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
tmp=$(mktemp -d "${RUNNER_TEMP:?}/tce-linux-release.XXXXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
/usr/bin/python3 tools/bootstrap_minisign.py --bin-dir "$tmp/verifier"
export PATH="$tmp/verifier:$PATH"
shopt -s nullglob
debs=(src-tauri/target/release/bundle/deb/*.deb)
images=(src-tauri/target/release/bundle/appimage/*.AppImage)
[[ ${#debs[@]} -eq 1 && ${#images[@]} -eq 1 ]]
deb="${debs[0]}"
image="${images[0]}"
python3 tools/verify_release.py --config "$config" artifact "$deb" "$deb.sig"
python3 tools/verify_release.py --config "$config" artifact "$image" "$image.sig"
[[ "$(dpkg-deb -f "$deb" Version)" == "$version" ]]
[[ "$(dpkg-deb -f "$deb" Architecture)" == amd64 ]]
mkdir "$tmp/deb"
dpkg-deb -x "$deb" "$tmp/deb"
[[ -x "$tmp/deb/usr/bin/tailscale-commander-elite" ]]
# Extraction is confined to this temporary directory; no system package installed.
image=$(realpath "$image")
(cd "$tmp"; "$image" --appimage-extract >/dev/null)
[[ -x "$tmp/squashfs-root/AppRun" ]]
[[ -x "$tmp/squashfs-root/usr/bin/tailscale-commander-elite" ]]
# Launch both exact verified payloads under a disposable virtual display.
for exe in "$tmp/deb/usr/bin/tailscale-commander-elite" "$tmp/squashfs-root/AppRun"; do
  rc=0
  timeout --kill-after=3s 10s xvfb-run -a "$exe" || rc=$?
  [[ "$rc" -eq 124 ]]
done
echo "SIGNED LINUX BUNDLES: signatures, package metadata, extraction and process liveness passed"
