# Tailscale Commander Elite

Tailscale Commander Elite is a desktop base by A Elite Estrangeira, built on the Machinery template with a Tauri 2 shell, an Elixir/OTP backend sidecar, and signed auto-updates.

## What is inside

- Tauri 2 desktop app with Windows NSIS installer
- Linux AppImage and .deb release bundles
- Elixir/OTP backend sidecar with a local health endpoint on 127.0.0.1:45900
- Signed auto-updates through the GitHub release feed (`latest.json`)
- English interface with only the template Updates and Backend panels
- GitHub Actions release workflow for Windows and Linux version tags

## Done checklist

- [x] Machinery desktop base applied
- [x] Windows v1.0.0 release published
- [x] Linux AppImage and .deb added to the release feed
- [x] Book 1 read and reviewed by 4 readers
- [x] Backend health endpoint hardened
- [x] Release workflow fixed to install the Tauri CLI
- [x] v1.1.1 published with Windows and Linux assets
- [x] Whole project re-read against book 1; missed hardening applied in v1.2.0

## Book improvements applied

Book 1 was applied only where it hardens code that already exists in this project:

- [x] Only `GET /health` is answered by the backend
- [x] Unknown routes and non-GET methods are denied by default
- [x] Oversized backend requests are rejected
- [x] No invented identities, resources, rules, or interface panels are shipped
- [x] Backend reads requests with a bounded loop and serves each connection in its own bounded worker
- [x] Malformed requests get 400, non-loopback Host is rejected, health responses are no-store
- [x] Strict backend port parsing and diagnosable listen failures
- [x] Real CSP, prototype freezing, and least-privilege window capabilities
- [x] Release workflow: read-only permissions, version/secret checks, backend tests, complete signed artifacts
- [x] Scripts and smoke tests fail closed: installer exit codes, paired signatures, backend health check

The full book sequence is tracked in `BOOK_CHECKLIST.md`.

## Development

Run the numbered scripts in `scripts/` to set up, build, and smoke-test the base. The backend compiles and tests with `mix test` inside `backend/`.

## License

Copyright A Elite Estrangeira. See LICENSE.
