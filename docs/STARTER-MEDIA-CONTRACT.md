# Built-in Starter media contract

[简体中文](STARTER-MEDIA-CONTRACT.zh-Hans.md) · English

This contract turns the bundled Starter videos, speech, sounds, images, icons,
localizations, and data into a repeatable inventory. It proves that declared
bytes and metadata agree. It does not authenticate provenance or replace owner,
legal, or media-rights review.

## Current state

- The manifest covers exactly 198 shippable files and builds without Seedance,
  TTS, or provider credentials.
- The current receipt is `PASS_WITH_PENDING / INTERNAL_PREVIEW_ONLY`.
- Rights review is 0/198; accessibility approved or not applicable is 3/198;
  the package license still requires owner approval.
- Provider failure falls back to local text, static visuals, and existing audio.
- The manifest declares no API keys, task content, personal paths, or runtime
  network dependency.

These values describe the repository today; they are not a public-release
promise. Changing an inventoried file changes its SHA-256 and resets carried
rights and accessibility approval to pending. The tooling never fabricates an
approval from old metadata.

## Four evidence layers

| Layer | What automation proves | What must not be inferred |
| --- | --- | --- |
| Source tree | No unlisted file, hidden metadata, symlink, or stale archive | SwiftPM caches are clean |
| Current build product | Current debug/release resources exactly match source, allowing only a validated SwiftPM `Info.plist` | Old build directories match |
| Current `dist` | The packaged app contains only 198 declared files plus the manifest | The `/Applications` copy was updated |
| Installed app | Only an independent check of the installed build can confirm it | Source or `dist` success replaces installation evidence |

A zero-authorization environment must not replace the app to close the last
layer. Record that layer as pending while keeping the first three independently
verifiable. Source, build-product, and installed-app hygiene are separate claims.

## Local checks

Confirm that the manifest still matches source resources:

```bash
python3 scripts/refresh-starter-media-manifest.py --check
```

Print the current privacy-safe, machine-readable state:

```bash
python3 scripts/audit-starter-media.py --json
```

Run the public-candidate strict gate. It currently exits 3 by design:

```bash
python3 scripts/audit-starter-media.py --strict --json
```

Exercise missing files, tampering, extra archives, private paths, duplicate IDs,
forged approvals, and approval-reset behavior:

```bash
./scripts/run-starter-media-contract-smoke.sh
```

The generator's `--write` mode only reinventories bytes and preserves genuine
human metadata for unchanged files. New or changed files return to pending.
Final licenses, evidence references, and approvers remain owner decisions based
on real authorization.

## Contribution and release boundary

Contributors may add accurate source, author/provider, license or authorization
basis, allowed uses, attribution, adult/fiction status, bilingual alt text,
captions or sound descriptions, fallbacks, and review versions. “Model output,”
“paid generation,” and “matching hash” are not redistribution licenses.

Public release still requires both the [release-readiness states](RELEASE-READINESS-STATES.md)
and [licensing and rights boundary](LICENSING-AND-RIGHTS.md). Passing this contract
only makes the Starter inventory verifiable. Without final licenses, Developer
ID, Apple notarization, and owner approval, the project remains a source preview.
