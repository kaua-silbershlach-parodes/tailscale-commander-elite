# Tailscale Commander Elite - book checklist

Source library: private technical collection. One whole book at a time; each book is read by 4 readers, only improvements that harden what already exists in the project are applied, and a new release is published before moving to the next book. Book titles are not published.

- [ ] 1. Book 1 (historically applied through v1.2.1; reopened for independent validation, see SECURITY_AUDIT.md)
  - [x] Backend answers only `GET /health`
  - [x] Unknown routes and non-GET methods are denied by default
  - [x] Oversized backend requests are rejected
  - [x] No invented identities, resources, rules, or interface panels
  - [x] Bounded request reads, per-connection workers, strict request-line and Host checks
  - [x] CSP and least-privilege capabilities in the shell
  - [x] Fail-closed workflow, scripts, and smoke tests
  - [x] Signed-version enforcement and native updater regressions
  - [x] Authenticated CI verifier provisioning and cross-platform builds (historical evidence)
  - [x] GLib backport integrity and optimized Linux regression (historical evidence)
  - [x] Shared release preflight and exact published-version check (fixture regression)
  - [x] Owner accepted only the two exact maintenance warnings temporarily, through 2026-12-26 UTC
  - [x] Dependency risk policy and complete required CI checks pass on integrated candidate (45938233677, 45938228506)
  - [ ] Pre-signing assessment complete
  - [ ] Owner disposition of residual risks and release authorization (v1.2.3 feature scope)
  - [x] Hosted Windows ephemeral-key NSIS install, launch and uninstall smoke (both candidate runs passed)
  - [ ] Full clean Windows development bootstrap/rollback (owner-authorized deferral; not passed)
  - [ ] Full independent semantic reread (Book 1 closure; not certified by file hashes)
  - [x] Production signed v1.2.2 bundles and hosted installer verification (45966513200; published audit passed)
  - [ ] v1.2.3 MCP integration and live connector validation
- [ ] 2. Book 2
- [ ] 3. Book 3
- [ ] 4. Book 4
- [ ] 5. Book 5
- [ ] 6. Book 6
- [ ] 7. Book 7
- [ ] 8. Book 8

Workflows decision: YES - .github/workflows/release.yml builds Windows and Linux on version tags.

## Security operating record (book 1)

Authorization boundary: the installed shell, the separate backend
process, and signature-verified update artifacts. Everything
outside that boundary is untrusted, including other local
processes: localhost is treated as contested.

Resources and machine identities:
- Shell binary and installed directory (local user process)
- Backend sidecar and its health endpoint (separate OTP process)
- Update feed and release artifacts (integrity-critical)
- Signing key (local secure storage and GitHub secret only)
- GitHub token and workflow (read-only by default)
- PowerShell scripts and build toolchain (shared infrastructure)

Attack surface: loopback TCP listener, update feed and artifacts,
signing key, GitHub secrets, third-party Actions, PowerShell
execution, installer and update path.

Data flows: shell reads its own version; shell checks the HTTPS
update feed and installs only signature-verified artifacts; CI
builds signed artifacts on version tags; scripts install and
smoke-test locally; the backend answers only GET /health on
127.0.0.1. The backend uses plain HTTP on loopback as an explicit
exception: the payload is non-confidential (status, service,
version), the bind is loopback-only, and Host, size, and timeout
checks apply. Caller authentication is not added because the
health payload carries no sensitive data and no user identity
exists in this project.

Classification: signing key and secrets HIGH; update artifacts
and feed HIGH integrity; workflow HIGH integrity; scripts
MODERATE integrity; health payload LOW.

Risk to mitigation:
- Malicious local caller -> loopback bind, Host check, default deny, bounded reads and workers
- Tampered update -> HTTPS feed, per-artifact signature verification, stale-check revalidation
- Compromised build input -> lockfiles, scheduled RustSec audit, version sync, backend tests in CI
- Wrong artifact installed -> paired-signature and hash checks in scripts, installer exit-code checks
- Silent failure -> backend and shell logging, fail-closed workflow gates, feed consistency audit

Operating loop: monitor (scheduled audit, CI logs, backend
anomaly logs) -> select (revisit controls when advisories,
incidents, or failed checks appear) -> implement -> assess
(tests and audits green) -> authorize (signed release only after
every gate passes). Triggers: hold the release on any failed
gate or unapproved advisory; supersede a vulnerable release with a patched
signed version, never replace assets silently; rotate the
signing key on suspected compromise. Failure record: backend
down means the health card cannot be verified and the separate
backend must be started; feed down means updates wait; signature
mismatch means the artifact is rejected and the release is held.

Release authorization checklist: backend tests green, Rust check
green, versions synced across tag, Tauri, Cargo, and Mix,
signatures present for every platform, feed verified after
publish, secrets never printed, publish credential revoked.
