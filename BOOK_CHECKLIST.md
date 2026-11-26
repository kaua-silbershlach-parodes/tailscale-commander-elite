# Tailscale Commander Elite - book checklist

Source library: F-Society - Intel Books (1,146 books). One whole book at a time; each book is read by 4 readers, only improvements that harden what already exists in the project are applied, and a new release is published before moving to the next book. Book titles are not published.

- [x] 1. Book 1 (applied in v1.1.1, completed in v1.2.0 after a full project re-read)
  - [x] Backend answers only `GET /health`
  - [x] Unknown routes and non-GET methods are denied by default
  - [x] Oversized backend requests are rejected
  - [x] No invented identities, resources, rules, or interface panels
  - [x] Bounded request reads, per-connection workers, strict request-line and Host checks
  - [x] CSP and least-privilege capabilities in the shell
  - [x] Fail-closed workflow, scripts, and smoke tests
- [ ] 2. Book 2
- [ ] 3. Book 3
- [ ] 4. Book 4
- [ ] 5. Book 5
- [ ] 6. Book 6
- [ ] 7. Book 7
- [ ] 8. Book 8

Workflows decision: YES - .github/workflows/release.yml builds Windows and Linux on version tags.
