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
  - [x] Pre-signing assessment complete
  - [x] Owner disposition of residual risks and release authorization
  - [x] Hosted Windows ephemeral-key NSIS install, launch and uninstall smoke (both candidate runs passed)
  - [ ] Full clean Windows development bootstrap/rollback (owner-authorized deferral; not passed)
  - [ ] Full independent semantic reread (Book 1 closure; not certified by file hashes)
  - [ ] Production signed v1.2.2 bundles and isolated installation verification
- [ ] 2. Book 2
- [ ] 3. Book 3
- [ ] 4. Book 4
- [ ] 5. Book 5
- [ ] 6. Book 6
- [ ] 7. Book 7
- [ ] 8. Book 8
  - [ ] CP01: partial review of official online text, sections 6.2, 9.2, 9.3 and 11.1; private 559-page edition not yet accessible.
  - [ ] Source changes, uncompiled: exact CSP allowlist regression, explicit transport-option Result handling, negative fixtures and diagnostic assertion.
  - [ ] CP02: private edition verified (559 physical pages); read complete physical pages 240-247 (printed 208-215), 16,055 extracted Unicode characters; targeted reading, not a sequential book completion.
  - [ ] CP02 source changes: positive and negative test pairs, exact duplicate/empty CSP fixtures, non-object updater rejection, diagnostic assertions; all uncompiled.
  - [ ] CP03: read physical pages 239 and 248-264 (18 additional pages, 35,053 Unicode characters); chapter 11 text coverage now 239-264 inclusive (26 pages, 51,108 characters).
  - [ ] CP03 source changes: typed CSP test failures, Result-returning config test, exact error assertions and per-directive missing fixtures; no runtime behavior change.
  - CP03 review: tests use local immutable fixtures; no critical tests ignored, no new public API solely for integration tests. Filtered test runs are diagnostic only and do not replace the final full suite.
  - [ ] CP04: read physical pages 265-294 (30 pages, 62,217 Unicode characters); chapter 12 text coverage complete. Cumulative private-edition coverage: pages 239-294 (56 pages, 113,325 characters).
  - [ ] CP04 source changes: isolate version consistency validation as a pure Result-returning helper; distinguish missing, mismatched and duplicate version metadata; add independent negative fixtures. This is a guard for the current Mix source format, not an Elixir parser.
  - CP04 review: current main/lib separation and startup error handling retained; no CLI, environment override, filesystem search feature or new public API added. Full red-green-refactor verification deferred until authorized build/test execution.
  - [ ] CP05: read physical pages 295-321 (27 pages, 58,538 Unicode characters); chapter 13 text coverage complete. Cumulative private-edition coverage: physical pages 239-321 (83 pages, 171,863 characters).
  - [ ] CP05 source changes: borrowed manifest version parsing without a temporary comparison allocation; malformed suffix fixtures; expanded GLib iterator regression for exact size, repeated exhaustion, empty input, count and out-of-range/overflow skips. Vendor source unchanged.
  - CP05 review: no cache or concurrency introduced; no measured runtime speedup claimed. Existing optimized Linux regression test name retained so CI still selects it. Compilation and test execution remain deferred.
  - [ ] CP06: processed physical pages 322-342 (21 pages, including two with no extracted text; 19 text-bearing pages, 35,582 Unicode characters). Chapter 14 extracted-text coverage complete (323-341). Cumulative physical coverage 239-342: 104 pages, 207,445 characters; 102 text-bearing pages.
  - [ ] CP06 source changes: disable accidental Cargo registry publishing with publish = false; add repository and existing proprietary license-file metadata; document crate scope and run entry point; add a non-launching signature doctest.
  - CP06 review: existing release LTO, codegen-units and stripping retained; no workspace split, dependency changes, tool installation, registry publication or runtime optimization claimed. Doc generation, doctest execution and Cargo validation remain deferred. The two empty-text pages were not visually inspected.
  - [ ] CP07: read physical pages 343-378 (36 text-bearing pages, 80,852 Unicode characters); chapter 15 extracted-text coverage complete. Cumulative physical coverage 239-378: 140 pages, 288,297 characters, including two pages without extracted text.
  - [ ] CP07 source changes: extend the existing optimized Linux GLib regression with borrowed-string lifetime after iterator scope, independent cursor state, explicit iterator drop, nonzero skips, empty strings and Unicode fixtures; document that explicit process exit does not run remaining stack destructors.
  - CP07 review: no first-party need for new Box/Rc/RefCell/Weak ownership structures identified in the current shell. Keep compile-time borrowing, existing ownership and authenticated vendor source; do not claim absence of leaks or verified shutdown. No build or test execution; figures were not visually inspected.
  - [ ] CP08: read physical pages 379-402 (24 text-bearing pages, 50,853 Unicode characters); chapter 16 extracted-text coverage complete. Cumulative physical coverage 239-402: 164 pages, 339,150 characters, including two pages without extracted text.
  - [ ] CP08 source changes: bounded concurrent mixed-request TCP regression (16 loopback requests, at most eight client tasks, individual response assertions, socket cleanup and worker recovery); deterministic UI in-flight refresh and refresh failure regressions using controlled promises, no sleeps.
  - CP08 review: concurrency principles applied to existing OTP and UI boundaries; no first-party Rust threads, Arc/Mutex or unsafe Send/Sync needed for the current native shell. No runtime worker or updater changes, no external network tests, no build or test execution. Existing limits and release gates unchanged.
  - [ ] CP09: processed physical pages 403-426 (24 pages, 23 text-bearing, 51,891 Unicode characters); chapter 17 extracted-text coverage complete. Cumulative physical coverage 239-426: 188 pages, 391,041 characters, including three pages without extracted text.
  - [ ] CP09 source changes: replace independent updater flags and timestamp with one tagged lifecycle state; only ready retains approval and timestamp; installation consumes approval before awaiting; no-update and failed checks invalidate previous approval; regressions cover no-update recovery and in-flight install exclusivity.
  - CP09 review: apply state-pattern principles to existing JavaScript updater, not Rust compile-time typestate; no new public Rust traits, dynamic dispatch, heap allocations in Rust or interfaces. Existing signed update policy, ten-minute freshness and explicit restart behavior retained. Runtime refactor is untested; only syntax/diff validation; no build or release. Empty-text page not visually inspected.
  - [ ] CP10: read physical pages 427-448 (22 text-bearing pages, 43,403 Unicode characters); chapter 18 extracted-text coverage complete. Cumulative checkpoint coverage 239-448: 210 pages, 434,444 characters, including three pages without extracted text. Pages 449-450 previewed but reserved for CP11 accounting.
  - [ ] CP10 source changes: typed updater-policy regression validator using tuple patterns, literal booleans, single-element slice matching and guards for the exact endpoint and pinned public key; independent malformed/missing field fixtures and exact transport-error propagation.
  - CP10 review: test-only validation, no new runtime trust enforcement or signature algorithm; existing updater configuration and vendor unchanged. Historical range syntax from the reference was not introduced. Compilation and tests remain deferred.
  - [ ] CP11: processed physical pages 449-488 (40 pages, 39 text-bearing, 85,483 Unicode characters); chapter 19 extracted-text coverage complete. Cumulative checkpoint coverage 239-488: 250 pages, 519,927 characters, including four pages without extracted text.
  - [ ] CP11 source changes: package-level Rust lints warn about unsafe code and deny implicit unsafe operations inside unsafe functions; existing Linux iterator regression includes a generic associated-type contract for borrowed strings, double-ended traversal, exact size and fused exhaustion; explicit string-slice comparisons clarify CP10 guards.
  - CP11 review: inspected first-party Rust entry points and build script; no handwritten unsafe block identified there. Existing Tauri macros and vendor dependencies unchanged; lint behavior, generated code and trait contract await compiler verification. No new custom macros, FFI, dependencies, runtime permissions or unsafe code introduced. Empty-text page not visually inspected. No build or test execution.
  - [ ] CP12: processed physical pages 489-526 (38 pages, 37 text-bearing, 78,292 Unicode characters); chapter 20 extracted-text coverage complete. Cumulative checkpoint coverage 239-526: 288 pages, 598,219 characters, including five pages without extracted text. Pages 527-528 previewed and reserved for subsequent accounting.
  - [ ] CP12 source changes: TCP split-write regression checks incomplete terminator, response status, content type, byte length, cache policy and connection closure; abandoned partial-request regression checks worker cleanup and listener recovery. Corrected CP08 status-line fixture to use actual CRLF escapes rather than literal backslashes.
  - CP12 review: existing OTP service retains loopback binding, worker cap, deadlines and request policy; no replacement Rust server, new route, unbounded queue or new dependency. Split writes do not prove exact TCP packet boundaries; graceful service shutdown and full functional verification remain pending. No build or test execution. Figure and empty-text page not visually inspected.
  - Next targeted reading cursor: physical page 527, offset 0; physical pages 1-238 remain unread in this session.
  - Source publication through CP12: main only, no version tag, build or release requested. Historical candidate CI does not validate these changes.
  - [ ] Build, test execution and independent assessment deferred; no release or book closure.
  - Owner-directed exception for this checkpoint: Book 1 remains open with its three existing pending items; no release required before this source-only work.

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
