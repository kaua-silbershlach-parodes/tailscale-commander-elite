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
