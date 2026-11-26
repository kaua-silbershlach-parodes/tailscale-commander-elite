# Tailscale Commander Elite - book checklist

Source library: F-Society - Intel Books (1,146 books). One whole book at a time; each book is read by 4 readers, only improvements that harden what already exists in the project are applied, and a new release is published before moving to the next book.

- [x] 1. Planning for a Zero Trust Architecture (applied in v1.1.1)
  - [x] Backend answers only `GET /health`
  - [x] Unknown routes and non-GET methods are denied by default
  - [x] Oversized backend requests are rejected
  - [x] No invented identities, resources, rules, or interface panels
- [ ] 2. Network Security Bible
- [ ] 3. Wireshark for Security Professionals
- [ ] 4. Linux Networking Cookbook
- [ ] 5. TCP/IP Illustrated, Volume 1: The Protocols (2nd edition)
- [ ] 6. DNS Security
- [ ] 7. End to End Network Security - Defense-In-Depth
- [ ] 8. The Rust Programming Language

Workflows decision: YES - .github/workflows/release.yml builds Windows and Linux on version tags.
