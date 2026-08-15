# Contributing to Chengyin Companion

[简体中文](CONTRIBUTING.md) · English

Thank you for helping improve Chengyin. The project prioritizes contributions that improve stability, privacy, recovery, accessibility, and declarative content extension.

## Five contribution paths

1. **Documentation and localization**: correct copy, add Chinese/English guidance, and improve accessibility descriptions.
2. **Declarative content**: contribute original media and content packs without executable code.
3. **Experience rules**: contribute declarative reactions, rituals, scene stories, and mini-game configuration. Propose new Content Pack v2 extension points through an RFC first.
4. **Event adapters**: map trusted tool lifecycles into privacy-minimal Companion Events.
5. **Swift Core**: improve scheduling, state, playback, recovery, windows, and system integration.

Good first contributions include documentation, localization, test fixtures, and issues labeled `good first issue`. Public protocols, persisted fields, permissions, and new core interaction systems require a short RFC under the [governance rules](GOVERNANCE.md).

## Before you begin

1. Search existing Issues and Discussions to avoid duplicate work.
2. For a large feature, first write a concise proposal explaining the user problem, interaction, and data boundary.
3. Never submit secrets, account credentials, purchase records, or user diagnostics.
4. Never submit real-person photos, voices, music, or video without explicit commercial-use rights.
5. Character media must identify an adult fictional character and must not imitate an identifiable real person.
6. Read the [public roadmap](ROADMAP.md) and [code of conduct](CODE_OF_CONDUCT.md).

Chinese and English are the base locales. Every new semantic UI key must update both `Localizable.strings` files and pass `python3 scripts/check-localization-parity.py`; never rely on a fallback locale to hide a missing translation.

README and contribution-guide changes must also pass `python3 scripts/check-public-doc-parity.py`, which keeps commands, relative links, and heading hierarchy aligned across both entry surfaces.

Before review, route the changed repository paths with the
[module stewardship contract](docs/MODULE-STEWARDSHIP.md). It returns stable role,
check, risk, RFC and owner-gate IDs without exposing the submitted paths in its
receipt; pending role assignments never imply an invented GitHub identity.

New failure branches must follow the [stable error-code contract](docs/ERROR-CODES.md). Lower layers emit stable codes and English technical descriptions; `CompanionErrorPresentation` supplies bilingual recovery. Never display raw system errors that may contain user names or absolute paths.

## Local checks

Run the fast, network-free contributor gate first. Its JSON receipt contains
stable check IDs and recovery commands without a username, repository path or
content-pack path:

```bash
./scripts/check-contribution.py --profile quick --json
python3 scripts/audit-module-stewardship.py --audit --json
python3 scripts/audit-public-source-secrets.py --json
```

Before a release-oriented pull request, use `--profile full`; it exercises the
complete isolated clone/build/contribute package and takes longer. Declarative
pack contributors use the strict local profile:

```bash
./scripts/check-contribution.py --profile pack --pack <pack-directory> --json
```

These profiles never install the app, open the preview browser, request network
access, upload diagnostics or claim public-release readiness.
The secret audit reads only the portable-source allowlist—not environment
values, build caches, `video-production`, or user-private directories. Revoke a
real credential before removing it from the current tree and Git history. PASS
does not prove that history never leaked a secret.

## Create a clean public Git candidate

Do not run `git init` directly in a development directory that may also contain
private production inputs, caches, and historical release artifacts. From a
trusted checkout, run this offline command to build and audit the public source
package before creating a new `main` worktree with every public file staged:

```bash
python3 scripts/bootstrap-public-git.py --destination <new-absolute-directory> --json
```

A successful receipt reports `staged-unborn-main`, `commitCreated=false`,
`remoteConfigured=false`, and PASS for both source-package and credential
audits. The tool does not configure an author, create the first commit, or add a
remote; those decisions remain with the project owner. Checksums prove internal
package consistency, not provenance, and never upgrade
`NOT_PUBLIC_RELEASE_READY` into a public release.

```bash
./scripts/bootstrap-local.sh --check-only
swift build -c release
swift run CompanionContractChecks

./scripts/run-content-pack-smoke.sh
./scripts/run-core-policy-smokes.sh
./scripts/run-creator-error-receipt-smoke.sh
./scripts/run-contribution-metadata-smoke.sh
./scripts/run-content-pack-preview-projection-smoke.sh
./scripts/run-content-pack-experience-authoring-smoke.sh
python3 scripts/check-public-doc-parity.py
```

For mini-game changes, also run the matching smoke script under `scripts/` and perform one real-window interaction check.

For app packaging, versions, or resources, also run:

```bash
./scripts/install-local-app.sh --dry-run
./scripts/doctor.sh
```

`dist/Chengyin Companion.app` and `/Applications/Chengyin Companion.app` do not automatically follow source changes. Builds carry a source fingerprint, and doctor marks missing or stale identities. Do not replace the app manually, and do not delete `~/Library/Application Support/Chengyin` or its preference data.

## Content packs

- Read [Content Pack v1](docs/PACK-SPEC-v1.md) and backward-compatible [Experience Pack v2](docs/PACK-SPEC-v2.md).
- Atomically create a credential-free, executable-free compatibility-v2 draft with `./scripts/new-content-pack.sh <directory> <reverse-domain-id> <character-id> [locale] --json`. Repeat `--locale <tag>` for up to 32 locales. The path-safe receipt never infers provenance, rights or review approval.
- Run `./scripts/validate-content-pack.sh <directory> --json` to validate the manifest, paths, hashes, media decode, dimensions, first frame, audio declarations, and declarative JSON.
- Run `./scripts/preview-content-pack.sh <directory>` to open a validated local catalog. Every video shows the actual pet, stage, and fullscreen runtime crops side by side, including declared anchors, v1 aliases, or safe defaults. It loads no remote script, font, or analytics service.
- Run `./scripts/edit-content-pack-projection.sh <directory> --asset <video-id>` to calibrate Pet, Stage and Fullscreen focal tracks and safe areas in an offline page. The browser exports only a path-free JSON receipt. Preflight with `python3 scripts/apply-content-pack-projection.py <directory> <receipt> --check --json`, then omit `--check` for a transactional apply. Failure restores the original manifest; the receipt is not rights or quality approval.
- Run `./scripts/author-content-pack-experience.sh <directory> --id <experience-id> --kind <kind> --trigger <trigger> --step <video-id:role> --check --json` for a no-write sequence check. Omit `--check` after review; only explicit `--replace` can replace an existing ID. Failure restores the original manifest.
- Run `./scripts/audit-content-pack.sh <directory> --strict` for contribution quality. Audit advice never replaces rights evidence, real playback health, or official signature verification.
- For v1 or older v2 packs, run `./scripts/plan-content-pack-v2-migration.sh <directory> --json` first. It is read-only and never infers authorization from a legacy `license` field.
- The [minimal example pack](examples/packs/hello-workday) is always available for validation.
- A content pack contains declarative media and configuration only—no scripts or executable code.
- v2 `experiences` may reference only declared in-pack videos and have at most eight steps. Do not submit URLs, shell commands, or code that Core would execute.
- Every media asset requires a SHA-256 digest.
- A contributed pack uses `contribution.contractVersion: 2` and supplies package-level and per-asset source, author/provider, authorization basis, enumerated allowed uses, attribution, adult/fictional status, a private-path-free `evidenceID`, and a versioned `draft/pending/approved/rejected` review. Legacy fields cannot stand in for these facts.
- Every asset also needs localized accessibility information: alt text for visual assets; transcripts, captions, and sound descriptions for audio/video; flashing and sudden-loud-audio declarations; and accessibility review status.
- `contribution.fallback.strategy` is `starter`; strict v2 also needs a per-asset fallback. Video, audio, and image fall back to Starter, while declarative localization or mini-game data may `skip`. Evidence-incomplete old packs can remain installable, but strict audit keeps them `DRAFT`.
- Read the [Content Pack threat model](docs/CONTENT-PACK-THREAT-MODEL.md) for the untrusted-input boundary and attack fixtures.
- The UI must label unsigned local packs honestly; they cannot impersonate official packs.
- Official pack signing and release are not open yet. Never request private keys in an Issue.
- Before requesting reviewed-index inclusion, run
  `python3 scripts/audit-community-pack-index.py community/index.json --json`.
  The index accepts only strict-v2 `READY_FOR_LAB` packs bound to the exact
  manifest hash; inclusion is not final legal or release approval.
- Use the bilingual “Content Pack submission” GitHub template for an index
  proposal. Publish only privacy-safe evidence IDs and receipts—not contracts,
  identity documents, credentials, or private paths.

## Pull requests

A PR must explain:

- the user problem it solves;
- its effect on built-in experiences, community packs, or local packs;
- how it was tested;
- whether it adds a permission, network request, persisted field, or third-party dependency;
- media source and usage rights.

Do not mix unrelated formatting or generated files into the same PR.
