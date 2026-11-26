# Book 1 re-audit — local candidate

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
| glib 0.18.5 / RUSTSEC-2024-0429 | Transitive Tauri/GTK dependency for Linux; compatible upgrade to >=0.20 must be validated against the GTK chain. Do not force an ABI-incompatible substitution or silently ignore the advisory. |
| chrono 0.4.45 / RUSTSEC-2026-0543 | Transitive dependency, maintenance warning; track upstream migration, document an approved temporary disposition if necessary. |
| proc-macro-error 1.0.4 / RUSTSEC-2024-0370 | Transitive GTK build-time macro, maintenance warning; track upstream migration, document any approved temporary disposition. |

## Authorization gate

Release authorization: PENDING

Do not mark Book 1 closed until the final tree is inventoried and read, all applicable findings are remediated or formally accepted, native tests/builds pass, both supported platforms are validated, the signed release is verified, and the decision is recorded. Do not weaken the security gate by suppressing unresolved advisories. The local candidate is not a production install or published release.

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

The post-update OSV query covered 493 external package entries; the cookie advisory no longer appeared after the update to 0.18.3. Three flagged packages remain (glib, chrono, proc-macro-error). The tag workflow now fails closed before any signing job unless the recorded authorization and checklist are complete and the dependency audit passes. This guard is not itself approval.

## CI verifier provisioning

Ubuntu 22.04 did not provide minisign via apt in candidate runs 45885601248 and 45886278580. The official Linux x86_64 minisign 0.12 archive is now authenticated using its pinned upstream Ed25519 public key, including the signed trusted comment; archive and executable SHA-256 are pinned. Only the exact executable is written to a new runner-local directory. Bootstrap regression tests are mandatory. Checkout v5 and upload-artifact v6 use Node 24 and remain commit-pinned. Dependency auditing is independent of signature provisioning and must still fail on unresolved advisories. No advisory is ignored and release authorization remains pending.
