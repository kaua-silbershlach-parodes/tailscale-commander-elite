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
  - [ ] CP13: processed physical pages 527-559 (33 pages, 32 text-bearing, 49,222 Unicode characters); appendices A-E, index and colophon reviewed through extracted text. Cumulative checkpoint coverage 239-559: 321 pages, 647,441 characters, including six pages without extracted text.
  - [ ] CP13 source-review outcome: retain Rust 2021, existing derived Debug/PartialEq/Eq for the three diagnostic enums, pinned compiler and lockfile. Add a first-party formatting check and a locked Clippy review command to the documented future validation procedure. Neither command was executed; Clippy requires compiler work. Do not apply automatic fixes or change the language edition without reviewed evidence and build authorization.
  - CP13 review: historical edition and language-server examples are not current toolchain requirements. No new executable code, dependency, lint severity, edition migration or vendor change. No formatting, installation, compilation or tests performed. Empty-text page not visually inspected.
  - [ ] CP14: processed physical pages 1-44 (44 pages, 39 text-bearing, 83,552 Unicode characters); front matter, detailed contents, introduction and chapter 1 extracted-text coverage complete. Cumulative checkpoint coverage 1-44 and 239-559: 365 pages, 730,993 characters, including eleven pages without extracted text.
  - [ ] CP14 source changes: Windows clone-and-check script explicitly selects the existing candidate Rust 1.100.0 toolchain for locked cargo check; README aligns Rust test commands with the same pin and distinguishes source-only inspection from compiler analysis. Confirmed Cargo.lock is tracked and candidate/release workflows use the same compiler pin.
  - CP14 review: retained existing compiler, edition, lockfile, release profiles and dependencies. No toolchain file or automatic installation added. Windows installer script still relies on the configured toolchain; no signing workflow changes. No PowerShell execution, compilation, tests or platform verification. Empty-text pages not visually inspected.
  - [ ] CP15: processed physical pages 45-62 (18 text-bearing pages, 36,102 Unicode characters); chapter 2 extracted-text coverage complete. Cumulative checkpoint coverage 1-62 and 239-559: 383 pages, 767,095 characters, including eleven pages without extracted text.
  - [ ] CP15 source changes: extend the existing backend port-parser regression with lower/upper valid boundaries, accepted whitespace, leading zeros and explicit plus sign; reject out-of-range, fractional, exponential, hexadecimal, embedded whitespace, non-ASCII numerals and oversized numeric values; assert the exact original invalid input is returned.
  - CP15 review: preserve the existing runtime parser and its accepted numeric syntax; no dependency, random generator, lockfile or logging change. Source assertions are not executed evidence; no build or functional tests.
  - [ ] CP16: processed physical pages 63-90 (28 pages, 27 text-bearing, 51,094 Unicode characters); chapter 3 extracted-text coverage complete. Cumulative checkpoint coverage 1-90 and 239-559: 411 pages, 818,189 characters, including twelve pages without extracted text.
  - [ ] CP16 source changes: name the existing 600,000 ms updater approval limit; require age to be within the inclusive interval 0..600,000 before installation. Negative and non-finite age values require a new check rather than permitting installation. Add deterministic boundary, clock rollback and invalid-clock regression cases.
  - CP16 review: this is an existing JavaScript runtime guard refinement, not a Rust integer-overflow fix. The clock remains wall-clock based; this change does not establish monotonic time or detect all clock changes. Existing signing, endpoint, restart and explicit approval controls retained. No new dependency, build or functional test execution. Empty-text page not visually inspected.
  - [ ] CP17: processed physical pages 91-114 (24 pages, 23 text-bearing, 45,989 Unicode characters); chapter 4 extracted-text coverage complete. Cumulative checkpoint coverage 1-114 and 239-559: 435 pages, 864,178 characters, including thirteen pages without extracted text.
  - [ ] CP17 source changes: document the borrowed CSP diagnostic contract; add a regression checking complete UTF-8 unexpected-directive slices and duplicate-directive slices, including pointer identity with the original owned policy. Test fixture uses safe slice access and no raw-pointer dereference.
  - CP17 review: existing borrowed version comparison and GLib ownership checks retained; no new allocation in the validator, unsafe operation, runtime CSP policy change or dependency. Pointer comparisons in tests check the current implementation, not a general memory-safety proof. No compilation or functional test execution. Figures and empty-text page not visually inspected.
  - [ ] CP18: processed physical pages 115-128 (14 text-bearing pages, 28,040 Unicode characters); chapter 5 extracted-text coverage complete. Cumulative checkpoint coverage 1-128 and 239-559: 449 pages, 892,218 characters, including thirteen pages without extracted text.
  - [ ] CP18 source changes: group the three borrowed version-check inputs in a private CandidateVersions struct with named fields and a read-only validate method; migrate all eight existing call sites to named initialization, retaining the same error categories and source-format checks.
  - CP18 review: test-only organization, no new runtime interface, owned copy, dependency or version change. Named fields reduce positional ambiguity but do not make the two string fields distinct types. No compiler or functional test execution.
  - [ ] CP19: processed physical pages 129-142 (14 text-bearing pages, 28,089 Unicode characters); chapter 6 extracted-text coverage complete. Cumulative checkpoint coverage 1-142 and 239-559: 463 pages, 920,307 characters, including thirteen pages without extracted text.
  - [ ] CP19 source changes: typed main-capability regression guard with explicit Option comparisons and pattern matching for window scope, exact permission array, absent remote declaration, single main window and current-user installer mode. Add 21 negative fixture cases and retain existing positive test name.
  - CP19 review: exact source baseline checks, not an evaluation of effective Tauri ACLs or proof of remote-origin isolation. Existing runtime config, capabilities, dependencies and release permissions unchanged. No compilation or functional test execution.
  - [ ] CP20: processed physical pages 143-162 (20 pages, 19 text-bearing, 38,906 Unicode characters); chapter 7 extracted-text coverage complete. Cumulative checkpoint coverage 1-162 and 239-559: 483 pages, 959,213 characters, including fourteen pages without extracted text.
  - [ ] CP20 source changes: move the existing private security_tests module from lib.rs to sibling security_tests.rs, preserving cfg(test), all 13 test declarations, their bodies and module paths. Keep the native run entry point and root Linux GLib regression in lib.rs, preserving its exact CI selector.
  - CP20 review: source equivalence against published HEAD verified after removing only module wrapping and indentation; all three include_str paths resolve from the same directory. No new public exports, dependency, runtime behavior or vendor change. New module file must accompany lib.rs on publication. Compilation and test discovery/execution remain pending. Empty-text page not visually inspected.
  - [ ] CP21: processed physical pages 163-182 (20 pages, 19 text-bearing, 40,723 Unicode characters); chapter 8 extracted-text coverage complete. Cumulative checkpoint coverage 1-182 and 239-559: 503 pages, 999,936 characters, including fifteen pages without extracted text.
  - [ ] CP21 source changes: add two backend header regression tests covering three accepted forms, seven duplicate or forbidden header cases and five invalid HTTP field encoding cases. Check case-insensitive map keys, rejection before overwrite, colon preservation and ASCII-only field policy separately from UTF-8 validity.
  - CP21 review: preserve the existing bounded parser, map implementation, exact header policy and byte-length limit; do not introduce a new collection or hasher without a demonstrated need. No runtime change, dependency, build or functional test execution. Empty-text page not visually inspected.
  - [ ] CP22: processed physical pages 183-202 (20 pages, 19 text-bearing, 43,208 Unicode characters); chapter 9 extracted-text coverage complete. Cumulative checkpoint coverage 1-202 and 239-559: 523 pages, 1,043,144 characters, including sixteen pages without extracted text.
  - [ ] CP22 source changes: isolate restart handling in restartAfterInstall, allow it only after successful installation, mark restart in flight, and restore explicit restart retry if the relaunch call returns or fails. Add three deterministic UI regressions for premature restart, concurrent restart and recovery after failure.
  - CP22 review: recoverable restart failure is distinct from installation failure. No automatic restart, reinstall, new permission, dependency or Rust panic-profile change. Actual relaunch behavior and functional tests remain unverified; no build or functional test execution. Empty-text page not visually inspected.
  - [ ] CP23: processed physical pages 203-238 (36 pages, 35 text-bearing, 75,479 Unicode characters); chapter 10 extracted-text coverage complete. Cumulative checkpoint coverage 1-559: 559 physical pages, 1,118,623 Unicode characters, including seventeen pages without extracted text. All twenty chapters, appendices A-E and supplementary text accounted for.
  - [ ] CP23 source changes: share the updater and main-capability negative fixture mutation procedure via a private generic helper bounded by Debug + PartialEq and FnOnce. Preserve 32 existing field cases, independent baseline clones, distinct typed errors, and the difference between explicit JSON null and missing fields. Assert that removal fixtures contain the target field before deletion.
  - CP23 review: no new runtime abstraction, public export, dependency, lifetime extension or vendor change. Existing borrowed contracts and Linux regression selector retained. Source review only; generic bounds and test behavior still need compiler and functional validation. No build, release or functional tests.
  - Book 8 reading coverage: complete for extracted text, 559/559 physical pages (542 text-bearing, 17 without extracted text). Visual inspection of figures and empty-text pages, independent semantic validation and integrated build/testing remain pending. Do not mark all implementation checks passed based on reading alone.
  - Next targeted reading cursor: page 560, offset 0 (end-of-file sentinel; no unread physical pages remain). End of source-only reading cycle; next phase is review/publication or authorized integrated validation.
  - Source publication through CP23: main only, no version tag, build or release requested. Historical candidate CI does not validate these changes.
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
