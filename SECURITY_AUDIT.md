# Book 1 re-audit — v1.2.2 review candidate

This is a candidate, not release authorization. The scope is the existing desktop shell, signed updater, separate loopback health service, scripts and release pipeline. No new identity system, remote-control feature, or access policy has been invented.

## Security controls and evidence

- The health endpoint is bound to IPv4 loopback, denies every unsupported route and method, validates Host and framing, enforces bounded workers, request size and deadlines, and recovers when connections close. Native tests include sequential requests, slow clients, worker exhaustion and recovery, malformed/oversized requests, and the listen address.
- The signed updater rejects unbound/mismatched versions. The independent release verifier checks signature and trusted comment, expected file and version, release asset digests, URLs, duplicates and size. Test keys are ephemeral, never production keys.
- Published v1.2.1 Windows installer, Linux AppImage and deb, and the two update-feed signatures have been cryptographically verified using the pinned public key. This is not a signature or authorization for the local candidate.
- Local Windows installer selection and private-key handling must fail closed; production installer execution and production signing keys are outside this isolated audit.
- Workflow actions are pinned by immutable SHA; the Rust toolchain is pinned. Test with the actual lockfile and keep all versions synchronized.

## Risk register and release blockers

| Finding | Disposition |
| --- | --- |
| Loopback health response is unauthenticated | Low sensitivity status only; never use as an authorization decision or proof of service identity. Record explicit risk acceptance before release; otherwise authenticate through a suitable local boundary. |
| cookie 0.18.2 / RUSTSEC-2026-0594 | Updated by Cargo to 0.18.3; repeat Windows/Linux validation. The published advisory excludes Windows and requires specific fork/private-cookie behavior on Unix. |
| glib 0.18.5 / RUSTSEC-2024-0429 | Local source backport of upstream PR 1343; Linux optimized regression and exact-source verification required. Track migration to upstream fixed >=0.20. Advisory remains recorded. |
| chrono 0.4.45 / RUSTSEC-2026-0543 | Transitive dependency, maintenance warning; track upstream migration, document an approved temporary disposition if necessary. |
| proc-macro-error 1.0.4 / RUSTSEC-2024-0370 | Transitive GTK build-time macro, maintenance warning; track upstream migration, document any approved temporary disposition. |

## Authorization gate

Release authorization: PENDING

Do not mark Book 1 closed until the final tree is inventoried and read, all applicable findings are remediated or formally accepted, native tests/builds pass, both supported platforms are validated, the signed release is verified, and the decision is recorded. Do not weaken the security gate by suppressing unresolved advisories. The review candidate is not a production install or published release.

Every subsequent change must re-inventory all project files, verify the full tree and rerun the applicable controls and tests. The original repository and currently installed application remain unchanged until separately authorized.

## Book 1 traceability (physical PDF page numbers)

The source was reopened and its eighteen-page text retrieved. Pages 1-4 identify scope and audience; pages 5-6 describe logical PE/PA/PEP and policy inputs; pages 6-8 describe seven tenets; pages 9-10 introduce the RMF and mapping of resource/data-flow boundaries; pages 11-15 describe PREPARE, CATEGORIZE, SELECT, IMPLEMENT, ASSESS, AUTHORIZE, MONITOR and operational loops; page 16 summarizes organizational ownership; pages 17-18 are references, not additional implementation requirements.

- PREPARE: repository manifest, desktop UI/webview IPC, updater HTTPS endpoint and artifacts, local health listener, build and signing resources, GitHub roles and service identities. Current application is a desktop base, not a complete enterprise ZTA. GitHub account authorization and signing-key ownership are external controls. No enterprise identity/endpoint inventory is claimed.
- CATEGORIZE: proposed risk classification, not formal FIPS authorization. Health status: low confidentiality, moderate integrity/availability if used operationally; code and artifacts: low confidentiality for public code, high integrity; signing material: high confidentiality/integrity; build and update service: high integrity. Owner must approve classifications.
- SELECT/IMPLEMENT: strict default-deny HTTP routes, bounded requests, capability allowlist, CSP, TLS and signed-version binding, release verification and pinned workflow actions. These are scoped enforcement points, not a universal policy engine or authenticated enterprise session service. Local health identity and dynamic per-session resource authorization remain out of scope or unresolved; loopback alone is not trust.
- ASSESS: native socket tests, configuration regression tests, signature negatives, dependency scan, CI on both platforms; verify final candidate rather than assuming earlier test results apply to changed code.
- AUTHORIZE: branch review only. No signed release, production installation, formal risk acceptance or claim of full Zero Trust conformity.
- MONITOR: scheduled dependency and release checks, review security findings before release, re-inventory and reassess after every change. Owner must provide operational incident response and approval.

## Candidate review CI

The review branch runs Windows and Linux builds and tests without production signing secrets. It does not create release assets or publish a release. Dependency findings remain visible and require resolution or formal owner acceptance. No test job is a certification of a production deployment.

The post-update OSV query covered 493 external package entries; the cookie advisory no longer appeared after the update to 0.18.3. At that historical checkpoint three flagged packages remained (glib, chrono, proc-macro-error). The tag workflow now fails closed before any signing job unless the recorded authorization and pre-signing assessment are complete and the dependency audit passes. This guard is not itself approval.

## CI verifier provisioning

Ubuntu 22.04 did not provide minisign via apt in candidate runs 45885601248 and 45886278580. The official Linux x86_64 minisign 0.12 archive is now authenticated using its pinned upstream Ed25519 public key, including the signed trusted comment; archive and executable SHA-256 are pinned. Only the exact executable is written to a new runner-local directory. Bootstrap regression tests are mandatory. Checkout v5 and upload-artifact v6 use Node 24 and remain commit-pinned. Dependency auditing is independent of signature provisioning and must still fail on unresolved advisories. No advisory is ignored and release authorization remains pending.

## Dependency disposition and GLib backport candidate

- The latest stable Tauri v2.12.7 still uses GTK3 and the GLib 0.18 dependency family. A Cargo update dry run did not offer updates resolving these three advisories. Tauri's own audit configuration for this tag acknowledges the GLib and proc-macro-error limitations.
- RUSTSEC-2024-0429: the upstream fix is [gtk-rs/gtk-rs-core PR 1343](https://github.com/gtk-rs/gtk-rs-core/pull/1343), merge 05dff0ee696f9bcd8617cd48c4b812d046d440cb. The original crates.io GLib 0.18.5 archive is pinned by SHA-256, all 121 source files are reproduced byte-for-byte except the two upstream lines in src/variant_iter.rs, and upstream license and copyright are preserved. Cargo uses the local path override without misrepresenting its version. The exact vendor inventory and optimized Linux regression must pass; this is a local security backport, not an official patched release. Keep the advisory visible regardless of scanner treatment of path dependencies.
- RUSTSEC-2026-0543: chrono 0.4.45 appears in Cargo.lock through optional serde_with dependency metadata. Cargo tree for both supported target triples reports no active reverse-dependency path with the project's current features. This is scope evidence, not automatic risk acceptance or a promise about future feature changes.
- RUSTSEC-2024-0370: proc-macro-error 1.0.4 is active through GLib and GTK3 procedural macros on Linux at build time. It has no fixed published upgrade. A macro replacement is not a drop-in upgrade of the existing GTK3 macro stack; the alternative must itself be audited and maintained.
- Strict Cargo Audit remains enabled, including warnings. No advisories are suppressed. Release authorization remains pending; the backport and scope evidence need validation and owner disposition of the remaining maintenance risks.

## Verified follow-up and remaining decision

Evidence at commit 37f6dff8035eec0e227e0fb1143affe1cf572ab4: both Windows and Linux platform jobs passed in GitHub Actions run 45888806546. Linux verified all 121 vendor files and executed the named optimized GLib iterator regression (1 passed); the regular Rust suite passed 5 Linux and 4 Windows tests. Cryptographic security job passed. Cargo Audit returned exit 1 for two denied unmaintained warnings: chrono and proc-macro-error. No unresolved GLib registry warning was reported because of the local path override; the original advisory and backport remain tracked.

The new dependency scope check uses Cargo tree with locked normal, build and dev edges for both target triples. Chrono is present in Cargo metadata and the lockfile but absent from the current build trees; this distinction is not a waiver or a claim that future builds cannot activate it. proc-macro-error appears only in the Linux tree; Cargo metadata shows direct parents glib-macros and gtk3-macros with procedural macro targets. The scope tool fails on a change in those assumptions and is tested with six regression cases. Strict Cargo Audit is still separately required.

No official compatible fixed release of either remaining crate was identified. Removing optional dependency records solely to silence a scanner or inventing an unmaintained local macro fork is not remediation. Track upstream maintenance/migration, review the build toolchain and feature activation, and do not publish while the strict audit gate is red. The owner must explicitly decide whether to accept a bounded temporary residual risk and authorize a documented change in release policy, or retain the current hold until upstream remediation. This document does not make that decision. The unauthenticated local health response likewise must not become an authorization signal.

Review candidate README documents architecture, toolchain, commands, test evidence, dependency disposition, installation limits and license boundaries. No book titles, private key material, credentials or local machine paths are disclosed.

## Release script follow-up

The local signing script checks recorded approval, the Book 1 checklist, version consistency, a clean checkout and strict dependency auditing before inspecting signing key paths. It requires a separately provisioned matching restricted key and never generates a replacement key, rewrites the pinned public key or changes the key-directory ACL. The Tauri CLI runs from src-tauri with the NSIS target and locked Rust dependencies. Local installation checks recorded approval before executing any installer. Non-pre-release smoke verification requires the cryptographically verified published version to match the installed version. The local health response is reported only as unauthenticated liveness. The shared release preflight is covered by isolated fixture tests and used in CI. No production key or installation was exercised by this change.

The remaining RUSTSEC-2026-0543 and RUSTSEC-2024-0370 findings are informational unmaintained advisories with no published patched versions. RUSTSEC-2026-0173 also marks proc-macro-error2 unmaintained. A migration of the GTK3 procedural macro stack to another maintained diagnostic API is not a compatible version bump. Strict audit remains enabled and approval remains pending.

The pre-signing assessment is separate from final Book 1 closure to avoid a circular gate: complete and record the assessment and explicit owner authorization, then pass strict dependency audit before signing. After the signed bundles and exact published version are independently verified and the isolated installation check passes, record final Book 1 closure. Both approval markers remain pending in this candidate. This change does not waive any dependency advisory or accept residual risk.

## Isolated signed Windows candidate validation

The Windows platform job now includes a disposable GitHub-hosted runner test with an ephemeral signing key, the same candidate application version and per-user NSIS settings, and a temporary configuration overriding only the updater public key. It authenticates the Windows x64 minisign 0.12 executable using the independently verified archive and executable hashes, then checks the upstream archive signature. The test requires a clean install directory, verifies the signed installer and signed version before execution, holds read locks during installation, checks the installed file version, launches the application, checks process liveness, and uninstalls it. The test is restricted to GitHub-hosted Windows runners, refuses production signing variables, and does not publish or upload its artifacts. The local verifier provisioning and PowerShell syntax checks passed; hosted installation and uninstall results are pending at this checkpoint. This is not production signing, an authenticated backend identity check, a GUI interaction test, or final release authorization.

The remaining maintenance advisories have no published compatible fixes; the GTK3 macro migration would require refactoring the upstream macro diagnostics and regression-testing the vendor stack, while chrono is absent from the current build trees. No vendor fork is introduced solely to remove advisory entries. The strict dependency gate and the open Book 1 status are unchanged.

## Owner risk decision — 2026-11-27

The owner explicitly authorized temporary acceptance of exactly the following two maintenance advisories and integration after all required checks pass:

| ID | Exact package/version | Classification | Scope | Expiry (UTC, exclusive) |
| --- | --- | --- | --- | --- |
| RUSTSEC-2026-0543 | chrono 0.4.45 | Unmaintained | Lockfile only; absent in both current build trees | 2026-12-27 |
| RUSTSEC-2024-0370 | proc-macro-error 1.0.4 | Unmaintained | Linux compile-time procedural macros only | 2026-12-27 |

The 30-day expiry is a conservative review interval selected for this temporary acceptance. Both findings remain public, visible in the full unfiltered Cargo Audit JSON report, and unresolved upstream. They are informational maintenance risks, not confirmed exploitable vulnerabilities. This decision supersedes earlier statements requiring a completely warning-free audit; it does not supersede release authorization or other open findings.

The new policy evaluator rejects all known vulnerabilities, any unapproved warning (including unsound, yanked, or notice), changes to either package/version/advisory type, expiry, filtered reports, scanner errors, inconsistent exit codes, and changed target scope. The raw scanner still denies warnings; only its verified complete report can satisfy the explicit temporary policy. Candidate, scheduled audit, release and local signing use the same gate. No scanner ignore flags or advisory database edits are used. Reassess immediately on any upstream fix, scope change or new advisory, and before expiry; do not automatically renew. No production signing or release is authorized by this decision. The loopback identity risk and final semantic review remain open.

## RustSec database provenance and hosted CI evidence

The CI at commit 6c72481 passed Windows and Ubuntu platform jobs, including ephemeral-key NSIS installation, process liveness and uninstall, and the security job. The dependency scanner reported 494 dependencies, 1,568 advisories, zero known vulnerabilities and the two owner-approved maintenance warnings. The policy failed because cargo-audit's no-fetch Database::open report omits commit/time metadata.

The evaluator now requires an independently verified fresh temporary clone from the official RustSec advisory-db HTTPS origin. It compares the checkout revision with upstream HEAD, checks checkout cleanliness and commit age, and verifies the same revision again after both unfiltered scans. Null report metadata alone is not a waiver; a non-null conflicting revision is rejected. Scope, expiry, exact warning IDs and versions, scanner diagnostics and all other existing checks remain required. The actual historical scanner JSON was replayed as a regression fixture locally with independent checkout evidence; this is not a new Cargo Audit result. The fresh checkout and negative revision checks passed. New hosted CI must validate the complete scanner execution before merging.

## Integrated candidate — release preparation checkpoint

The reviewed source tree is integrated into protected main at 6d036c1a2cca417cbcf398b0bf3c87a863b46ed9. Both candidate runs 45938233677 (pull request) and 45938228506 (push) passed all four jobs, including the ephemeral-key NSIS smoke, optimized GLib regression and the full unfiltered RustSec policy. All 191 tracked files match the prior merged-tree SHA-256 manifest. A separate local release worktree was created from that exact commit; the experimental connectivity feature is excluded. Local Python (53), JavaScript (7), and exact GLib archive verification (121 files) passed again.

The owner authorized preparing and publishing v1.2.2 subject to the remaining controls, not a blanket waiver. The existing /health endpoint is unauthenticated and restricted to loopback, bounded status responses without confidential information; it is not a proof of identity or authorization. The owner has explicitly accepted this residual risk solely for local availability, never for proof of service identity or authorization, on 2026-11-27. The clean-machine prerequisite installation/rollback and complete semantic review are not established by the successful CI smoke or by the byte-integrity manifest. Production signed artifacts and isolated installation remain unverified. The existing release gate remains unchanged; no signing key, tag, or release is created by this checkpoint.

Owner decision: loopback /health residual risk accepted exclusively for local liveness; no identity or authorization use. The owner authorized continuing the remaining controls and publishing v1.2.2 only after approval. This is not acceptance of any other residual risk or an assertion that the pre-signing assessment is complete.

### Exact signed artifact verification gate

The release workflow is prepared to test the actual signed NSIS bundle on a disposable Windows runner, using the pinned production public key without exposing signing credentials to the smoke process. The Linux runner verifies both bundle signatures, DEB metadata and extracted executables, and attempts process liveness under a virtual display. These tests must pass before artifact upload. They are not a clean-machine development bootstrap or a GUI interaction test. The modified workflow itself still requires review and validation. No authorization marker was changed.

The Linux candidate job now exercises the same package checks with an ephemeral signing key and disposable runner before production signing can be considered. This does not confer release authorization. Full clean OS bootstrap remains unverified.

Local backend native suite: 8/8 tests passed again in the isolated release checkout. Windows Hyper-V and Windows Sandbox are disabled on the available machine; no operating-system settings were changed. The clean Windows development bootstrap/rollback and final full semantic reread remain open. PowerShell and Bash syntax checks passed for the new smoke gates; new hosted CI evidence is required. The release remains held by the existing preflight.

## Clean Windows Sandbox finding and bootstrap correction

The first real clean Windows Sandbox run (Windows 10 Enterprise build 19041) verified the exported 193-file candidate, then failed before installing Git because WinGet was not installed. The bootstrap now detects the registered Microsoft App Installer; if absent, it downloads pinned v1.29.380 assets from the official Microsoft GitHub release, validates exact lengths and SHA-256, extracts only the three exact x64 dependency members, and uses ordinary trusted AppX deployment. No signature bypass, Store sign-in or host OS change is used. Python is explicitly installed for release verification tooling. Source selection is restricted to the WinGet community source. Clean-machine retest and updated CI are required; release authorization remains pending.

The second and third clean Sandbox runs both successfully installed WinGet, Git, Python, Visual Studio Build Tools, WebView2 and Rust 1.100.0. Run 2 lost its guest connection during Tauri CLI source compilation; run 3 failed to execute a Rust build script on the shared cache (Windows error 1392). Neither completed a clean bootstrap; no hardware failure is inferred. At owner direction, further testing uses the existing host toolchain rather than the Sandbox. The Windows bootstrap now provisions the official Tauri CLI 2.12.6 x64 archive with pinned archive and executable lengths and SHA-256, and refuses to overwrite a different CLI. The exact binary was independently downloaded, verified and executed on the host, reporting version 2.12.6. The full clean Windows bootstrap/rollback remains unverified; this limitation must not be represented as a passed test. No application runtime source changed. Production signing remains gated.

## Scoped pre-signing decision — 2026-11-27

Owner explicitly authorized publication of v1.2.2 and deferral of the incomplete clean Windows development bootstrap/rollback. This is a scoped release assessment, not completion of Book 1 or certification of a clean installation. Both exact candidate runs 45961110724 and 45961059625 passed security, dependency policy, Windows ephemeral NSIS install/launch/uninstall and Linux signed candidate package checks. PR #3 was merged into protected main at 10d18969850c0642779ae2572a338d48cc3cf13d; identical reviewed Git tree verified. Native host regression on 022118749d73b4096a166cedd5f40afb155c700d: 53 Python, 7 JavaScript, 8 ExUnit, 4 Rust; 121 GLib vendor files, 193 tracked-file inventory and stable v1.2.1 signatures/feed verified. Reviewed runtime shell, updater configuration and capability boundaries, backend and UI logic, release scripts, verifier and production smoke workflow; no runtime code changed by bootstrap or this authorization. Previously accepted exact maintenance warnings and local health liveness risk retain their original scope and expiry. The full independent semantic reread of every file and full clean bootstrap remain pending; no claim of complete Book 1 assessment is made. Production signing is authorized only after the final protected-branch CI and tag workflow dependency gate; exact production bundle signatures, installer/liveness tests and independent release/feed verification remain mandatory. No key replacement, gate bypass or change to the feature branch is authorized.

## v1.2.3 connectivity review

Owner authorized recovering, testing, integrating and publishing the MCP feature on CTI. v1.2.2 was published and all three signatures and both feed entries were verified; its approval does not automatically approve v1.2.3. Only system_info and tailscale_status are exposed. No real credentials, machine identifiers, public tunnel endpoints, or runtime state are committed. Actual OpenAI connector interoperability is still pending. The release gate remains pending until the new scoped assessment and required checks are recorded.
