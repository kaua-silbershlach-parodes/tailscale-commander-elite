#!/usr/bin/env bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true && "${RUNNER_ENVIRONMENT:-}" == github-hosted && "${RUNNER_OS:-}" == Linux ]]
[[ -z "${TAURI_SIGNING_PRIVATE_KEY:-}" && -z "${TAURI_SIGNING_PRIVATE_KEY_PASSWORD:-}" && -z "${TAURI_SIGNING_PRIVATE_KEY_PATH:-}" ]]
cd "$(dirname "$0")/.."
root="$PWD"
[[ ! -d src-tauri/target/release/bundle/deb && ! -d src-tauri/target/release/bundle/appimage ]]
tmp=$(mktemp -d "${RUNNER_TEMP:?}/tce-linux-candidate.XXXXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
[[ "$(cargo tauri --version)" == "tauri-cli 2.12.6" ]]
(
  cd src-tauri
  cargo tauri signer generate --ci -w "$tmp/test.key"
  python3 - "$tmp/test.key.pub" "$tmp/test-config.json" <<'PY'
import json, pathlib, sys
c=json.loads(pathlib.Path('tauri.conf.json').read_text())
pub=pathlib.Path(sys.argv[1]).read_text().strip()
assert pub and pub != c['plugins']['updater']['pubkey']
c['plugins']['updater']['pubkey']=pub
pathlib.Path(sys.argv[2]).write_text(json.dumps(c))
PY
  TAURI_SIGNING_PRIVATE_KEY="$tmp/test.key" TAURI_SIGNING_PRIVATE_KEY_PASSWORD='' cargo tauri build --ci --bundles deb,appimage --config "$tmp/test-config.json" -- --locked
)
bash "$root/tests/04-ci-production-linux-smoke.sh" "$tmp/test-config.json"
echo 'Ephemeral-key Linux candidate validation passed; not production signing.'
