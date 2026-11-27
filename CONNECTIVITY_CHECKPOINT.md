# Secure MCP and Tailscale integration — development checkpoint

This local feature branch is separate from the reviewed 1.2.2 main tree. It is not a signed release or a claim of full tool parity.

## Source inventory and migration decisions

The original GPT Commander 1.2.0 is preserved. Its live source modules, not backup copies, informed this migration.

| Source module | Feature | Status |
| --- | --- | --- |
| network.js | Local Tailscale status, addresses, hostname, login and public IP | Native status, hostname, MagicDNS and Tailscale IPv4/IPv6 implemented. No public IP lookup or external login automation. |
| mcp-tunnel.js | Tunnel ID, protected credential, local authenticated MCP endpoint, client readiness | Native Windows vault, local ID suggestion, verified runtime, explicit start/stop and readiness implemented. Existing Electron credential remains in its original vault; manual re-entry into the new vault is required. |
| mcp-server.js | JSON-RPC and tools discovery | Bounded authenticated local HTTP transport, initialize, ping, tools/list, tools/call, empty resources/prompts. Protocol interoperability still requires live connector testing. |
| mcp-system.js, mcp-pagination.js | Metadata, read, pagination, hash, search, project management | system_info implemented with minimized output. Filesystem tools pending explicit locally approved roots, secret filtering, link-race handling and negative tests. |
| mcp-workspace.js | Inspect, read/edit, process start/stop | Not exposed. Local grants and execution review required before enabling. |
| mcp-project.js | Protech-specific server operations | Not copied; unrelated project-specific service. |
| mcp-browser.js, browser.js, dom-inspector.js, workflow modules | Browser tabs, DOM, page actions, workflows | Deferred until a dedicated browser scope and permission model are designed; no ChatGPT WebView added. |
| session-persistence.js, cookie-import.js, LinkedIn-specific files | Browser session and LinkedIn features | Not imported. LinkedIn belongs to [Career AI Leadership Elite](https://github.com/kaua-silbershlach-parodes/career-ai-leadership-elite). No change to that repository. |

## Storage and trust boundaries

- Windows Credential Manager generic record, per current Windows user, local-machine persistence, independent of the installer directory. It holds the tunnel ID and runtime credential; the renderer receives only ID and a credential-present flag, never the saved key.
- Existing GPT Commander ID is suggested from its local ID file. No ID, API key, tailnet addresses, or machine-specific data are hardcoded or committed. The original encrypted credential is not decrypted or copied by this checkpoint.
- Tailscale status comes from its installed Windows CLI at a fixed Program Files path. The last successful local snapshot is saved in a separate Windows credential-vault record with its observation time. A cached snapshot is explicitly marked unverified and never presented as a live connection. Only this device's status, hostname, MagicDNS and validated IP addresses are returned. Peer lists, auth URLs and environment are excluded. Tailscale login and settings are not modified.
- OpenAI tunnel-client v0.0.21 Windows amd64: official archive SHA-256 `2faf80ae62b58485fcef534cd3f78cd8b82e71cb04d14c2a5c73dbb4eb6c575a`, executable SHA-256 `e0b2f25d08f24a4ddb7a04f3d43b62f88d4b18a5b20f2e478295cd8f353f21e5`. The executable originally found in GPT Commander matched the independently downloaded official artifact. The executable is provisioned outside the installation tree and checked again before execution.
- The client uses outbound HTTPS, no inbound public listener; local MCP binds IPv4 loopback on an ephemeral port with a random bearer token. Credential passed via child environment reference, not command arguments. No automatic connection; stop another client using the same tunnel ID before explicitly connecting.
- MCP tools exposed initially: system_info and tailscale_status. No browser, file read/write, shell, or process execution tools exposed. No LinkedIn functions. No ChatGPT embedded in the interface.
- On Windows, a Job Object is configured to terminate the tunnel process when the controlling handle closes. Local controls can stop the tunnel and remove the stored credential. Readiness is a local status signal, not independent proof of ChatGPT connector identity.
- Windows-only connectivity implementation; on other operating systems this feature reports unsupported. Existing platform build/release policy remains separate.

## Provision and validate locally

From the repository root on Windows:

```powershell
python tools/bootstrap_tunnel_windows.py --bin-dir (Join-Path $env:LOCALAPPDATA 'com.aeliteestrangeira.tailscalecommanderelite\bin')
cd src-tauri
cargo test --locked
cargo build --locked
```

Run the development executable in an isolated test session. Enter the runtime key locally; do not paste it into a chat or source file. Save, close and reopen to validate persistence; click Connect, then Test tunnel readiness. Configure a custom ChatGPT plugin with the approved tunnel ID and verify discovery and the two read-only calls. A successful local health probe is not sufficient for end-to-end approval.

Official documentation: https://developers.openai.com/api/docs/guides/secure-mcp-tunnels and https://github.com/openai/tunnel-client/releases/tag/v0.0.21.

## Remaining gates

Do not push or publish until native compile and tests, actual local UI, cross-process credential persistence, connection to OpenAI, ChatGPT connector discovery/calls, permission review, update regression, Ubuntu compatibility, full source re-review and candidate CI are evidenced. Do not reuse the earlier release authorization for this changed feature scope. No release of 1.2.2 or new version is implied by this checkpoint.

## Local evidence — first connectivity checkpoint

- Tailscale 1.104.6 installed and running; live native Rust status test passed, self addresses and MagicDNS observed without publishing their values.
- 10 regular native Rust tests passed; the additional device-specific live Tailscale test passed separately. Debug application build passed with the locked dependency graph.
- Existing seven JavaScript updater tests passed; new connection script passed syntax check.
- Original client binary and independently downloaded official OpenAI artifact had the same SHA-256. The verified binary was provisioned in local app data without overwriting a different binary or starting the tunnel.
- The development window launched and the process remained alive. UI Automation did not locate the WebView controls; this is not an interactive UI pass. The development process was stopped.
- The vault roundtrip used a synthetic credential and a separate test record that was removed afterward. Actual runtime key was not migrated; no outbound tunnel or ChatGPT connector call has been validated.
- No push, merge, tag, release, installation over the existing application, or change to GPT Commander or the LinkedIn project.
