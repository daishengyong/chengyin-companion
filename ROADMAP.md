# Chengyin Companion public roadmap

[简体中文](ROADMAP.zh-Hans.md) · English

Chengyin is becoming a flagship, local-first companion for AI coding work. The
free repository must remain a complete product: no timer, daily limit, affection
paywall, forced account, advertisement or automatic sharing.

The roadmap is ordered by product risk rather than by the number of assets. A
milestone moves to **Done** only after implementation, automated checks, failure
behaviour, privacy review, accessibility, localization, diagnostics and recovery
are all present.

## Now — Shared Workday

- [x] Explicit, privacy-minimal Codex lifecycle protocol
- [x] Reliable success-only task completion celebrations
- [x] Restart-safe relationship state and media anti-repetition
- [x] Restart-safe, content-free shared-workday memory
- [x] User-visible and permanently erasable shared-workday journal
- [x] Interruption budget that keeps rapid turn boundaries subtle
- [x] Core experience arbiter for work, care, play and ambient presence
- [x] Declarative scene state machine driven by the experience arbiter
- [x] User-visible and permanently erasable relationship-memory journal
- [x] Field-level relationship and care-memory controls with rollback-safe deletion
- [x] Motion graph with ordered enter, notice, react, settle and exit transitions
- [x] Deterministic decision matrix across every experience source and presentation state

## Next — Experience Packs

- [x] Content Pack v2 JSON Schema, validation and runtime sequence selection
- [x] Application playback for declarative reactions, rituals, scene stories and micro-game rewards
- [x] `new-pack` and `validate-pack` creator commands
- [x] Local, validated and network-free `preview-pack` creator command
- [x] In-app local-folder import, inventory, rollback and recoverable removal
- [x] User-confirmed portable preference/content-pack backup and restore
- [x] Non-destructive Starter recovery mode that isolates every local pack
- [x] Rights, locale, accessibility and fallback metadata for every contribution
- [x] Core-derived Lab, Stable and Verified quality levels
- [x] Exact offline Starter inventory, integrity, fallback and review-state contract
- [x] Time-addressed focal tracks, safe-area validation and matching offline creator preview
- [x] Offline interactive focal/safe-area editor with path-free receipt and transactional rollback
- [x] Accessible transparent/cinematic/dim surfaces and recoverable multi-display targeting
- [ ] Complete rights-clean Starter pack that builds without provider credentials

## Then — Open-source release readiness

- [x] One-command source preflight, transactional install and post-install doctor
- [ ] Final code and Starter-media licenses after owner/legal review
- [ ] Module ownership and CODEOWNERS after the canonical GitHub organization exists
  - [x] Role-only, machine-verifiable [review routing](docs/MODULE-STEWARDSHIP.md) without invented account identities
  - [ ] Bind real steward accounts and generate CODEOWNERS after the owner creates the canonical organization
- [ ] Signed and notarized macOS release with clean-machine restore tests
- [x] Contributor documentation, architecture decisions and compatibility policy
- [x] User-controlled privacy-minimal issue diagnostic with no automatic upload
- [x] Offline public-source credential audit in contributor, CI and source-package gates
- [x] Machine-verifiable local-first product boundary that rejects monetization, forced accounts, advertising, automatic sharing and historical-research leaks
- [x] Audited public Git bootstrap that stages the exact allowlisted tree on an unborn `main` without a commit, author or remote
- [x] Community pack index using reviewed manifests rather than executable plugins
- [ ] Chinese and English product parity; additional locales driven by contributors
  - [x] Runtime key parity covers semantic keys, static SwiftUI literals and format placeholders
  - [x] README, contribution, security, support, governance, roadmap and conduct are paired and CI-checked
  - [x] Critical pet, play, completion and recovery controls use bilingual semantic copy and stable accessibility identifiers
  - [ ] Complete an English-locale clean-Mac visual walkthrough and accessibility audit
    - [x] Reproducible isolated five-step English walkthrough with current-run screenshots, OCR, optional existing AX evidence and a path-safe receipt
    - [ ] Physical clean English Mac plus human VoiceOver reading-order, focus and pronunciation review

## Explicitly later

- Arbitrary in-process code plugins
- An open upload marketplace
- Windows support
- Always-on microphone or realtime voice chat
- Cloud-dependent core experiences

## How to influence the roadmap

Bug fixes, documentation, localization and tests can go directly to a pull request.
New public extension points, persisted fields, permissions or major interaction
systems start with a short RFC issue describing the user problem, data boundary,
fallback and compatibility impact. See [GOVERNANCE.md](GOVERNANCE.md) and
[CONTRIBUTING.en.md](CONTRIBUTING.en.md).
