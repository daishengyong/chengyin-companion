# Chengyin error-code contract

Chengyin shows a language-neutral support code beside localized recovery
guidance. The code is safe to paste into a public Issue; it does not contain a
username, local path, task title, prompt, media filename or credential.

## Why codes are stable

Translated prose may improve between releases, but automation and issue
deduplication need a durable identity. Once released, a code must not be renamed
or reused for a different failure before a documented breaking compatibility
release. New cases receive new codes.

| Family | Owner | Typical recovery |
| --- | --- | --- |
| `ACCESSIBILITY_CONTRACT_*` | Bilingual critical-control semantics, stable UI identifiers, and validated Content Pack metadata projected into runtime media semantics | Restore reviewed English/Chinese semantic keys, the documented control identifier, or the bounded runtime metadata binding, then rerun the source audit; physical VoiceOver certification remains separate |
| `APP_SERVER_EVENT_*` | Privacy-minimal Codex App Server turn-event projection | Forward one complete turn notification, correct the method/status pair or bounded duration, and never promote `turn/completed` to task success |
| `PACK_VALIDATION_*` | Manifest and package safety validator | Run `validate-content-pack.sh`, fix the declared structure or hash, then retry |
| `PACK_MEDIA_*` | AVFoundation format, decoded-checkpoint and coarse audio/video timeline probes | Re-export with H.264/H.265 video, AAC audio, decodable midpoint/tail samples, aligned track bounds, a supported image format or valid JSON |
| `PACK_STORE_*` | Transactional local content library | Retry, use explicit rollback, or run Health Check; active content stays unchanged on failure |
| `BACKUP_VALIDATION_*` | Portable backup contract | Choose another backup or export a fresh one |
| `BACKUP_SERVICE_*` | Backup import/export transaction | Choose a new destination, restart, or run Health Check as the message directs |
| `CARE_MEMORY_*` | Privacy-minimal lifestyle-memory adapter | Retry persistence or explicitly reset the local rhythm; the last valid snapshot remains available |
| `WORKDAY_*` | Shared-workday state/director adapter | Continue the live task response, then retry persistence or explicitly reset today; raw storage details stay private |
| `PLAYBACK_*` | Bounded local media-health and soak gates | Use the built-in fallback, re-export failed media, or lower dynamic effects as the receipt directs |
| `COMMUNITY_INDEX_*` | Offline reviewed-manifest index auditor | Repair index metadata/hash/review binding, pass strict-v2 audit, then rerun locally |
| `CONTRIBUTOR_CHECK_*` | One-command local contribution readiness gate | Rerun the failed stable check ID using the path-safe recovery command; a pass never implies public-release readiness |
| `CORE_BOUNDARY_*` | Local Core/App architecture auditor | Move deterministic policy back to `CompanionContracts`, remove platform side effects, or extract growth from composition files |
| `CREATOR_*` | Atomic path-safe content-pack scaffolding, local creator CLI arguments, cached build and output | Correct the command or locale/ID, choose a new destination, move an invalid local cache aside, or repair the Swift toolchain, then rerun locally; scaffold failures never preserve partial output or infer rights |
| `EXPERIENCE_AUTHOR_*` | Declarative Content Pack v2 sequence authoring | Correct bounded experience fields or pack declarations; failed post-write validation restores the original manifest |
| `FIRST_USE_VISUAL_AUDIT_*` | Isolated English first-use window, locale, screenshot and gesture evidence | Rebuild the current preview, inspect the path-safe step capture, repair the failed localization or interaction, and rerun without claiming human VoiceOver or physical clean-Mac approval |
| `LOCAL_PREVIEW_*` | Zero-install source preflight, exact-process replacement, build and verified project-local launch | Quit installed or unverified copies when reported, run the named source/build recovery command, then retry; PASS never implies installation or public-release readiness |
| `EVENT_SPOOL_*` | Bounded local Companion Event inbox | Restore the private app-owned event directory, remove an unexpected overload only after inspection, and rerun the no-follow spool matrix |
| `PROJECTION_RECEIPT_*` | Offline focal/safe-area authoring handoff and transactional apply | Regenerate or correct the path-free receipt; a failed post-apply validation restores the original manifest |
| `SOURCE_BOOTSTRAP_*` | New-Mac source prerequisite and Python runtime contract | Install or select Python 3.9+, correct the preflight command, then rerun before any build or creator tool |
| `SOURCE_PACKAGE_*` | Verifiable clone/build/contribute source archive | Discard or move aside the invalid archive, rebuild from the public allowlist, then rerun the source-package audit |
| `SOURCE_SECRET_AUDIT_*` | Offline credential-leak guard for the portable public-source allowlist and packaged source ZIP | Revoke a real credential first, remove high-risk files or assignments from source and history, then rerun locally; PASS is not malicious-code analysis or historical proof |
| `STARTER_MEDIA_*` | Exact built-in Starter inventory, rights/accessibility evidence and packaged-resource match | Refresh changed hashes without carrying approval forward, complete explicit owner review, or rebuild the local preview |
| `STEWARDSHIP_*` | Offline module ownership and contribution-review router | Correct the role/check registry or path route; remove generated/private artifacts and rerun the path-safe audit |
| `SWIFTPM_GRAPH_*` | Evaluated local SwiftPM product/target/dependency/resource graph | Restore the zero-external-dependency, one-way Core graph or complete a separately reviewed architecture migration |
| `UI_*` | Local source/dist/installed/running identity, repair and window lifecycle audits | Launch one verified copy, perform an owner-approved install when required, or restore the previous local build |
| `COMPANION_UNEXPECTED_ERROR` | Safe fallback boundary | Retry once, then attach the code and privacy-minimal diagnostic to an Issue |

The exhaustive case-to-code mapping lives next to each error enum in source so
the compiler requires every new case to choose an identity. The versioned public
inventory is `Schemas/error-codes-v1.json`; CI compares it with Core and all
creator CLI sources and rejects accidental removals or unregistered additions.

## Creator-tool failure receipt

`validate-content-pack.sh --json` and `audit-content-pack.sh --json` return the
same stable code on failure and exit non-zero:

```json
{
  "code": "PACK_VALIDATION_MANIFEST_INVALID_JSON",
  "message": "manifest.json is not valid Content Pack JSON.",
  "recoveryAction": "Correct manifest.json or the declared assets, then rerun scripts/validate-content-pack.sh <pack-directory> --json.",
  "status": "FAIL"
}
```

The validator, audit, archive-audit, migration and locale-matrix CLIs encode the same Core
`CompanionFailureReceipt`; their text logs use the same code, message and action.
The app replaces the English technical message with localized, action-oriented
guidance while preserving the code. Raw system errors are never displayed,
because they can contain private absolute paths.

`.chengyinpack` preflight uses `PACK_ARCHIVE_*` for invalid sources/ZIPs,
unsafe or unsupported entries, resource limits, extraction postconditions and a
missing package root. The graphical importer localizes those identities without
showing the selected path. `build-content-pack-archive.sh` uses the parallel
`PACK_ARCHIVE_BUILD_*` family, refuses overwrite, and publishes only after the
shared Swift archive auditor returns PASS. Neither family implies rights,
signature, provenance authenticity or public-release approval.

Projection authoring keeps distinct identities for malformed time tracks
(`PACK_VALIDATION_INVALID_FOCAL_TRACK`), invalid rectangles
(`PACK_VALIDATION_INVALID_SAFE_AREA`) and a valid rectangle that the declared
crop would clip (`PACK_VALIDATION_SAFE_AREA_NOT_VISIBLE`). A pack that advertises
an older incompatible app minimum uses
`PACK_VALIDATION_PROJECTION_REQUIRES_APP_VERSION`. Validator JSON, text
logs and localized app guidance preserve the same code and executable recovery
action; none includes the contributor's absolute path.

The workday content triggers introduced in 0.19.42 have the same explicit
compatibility boundary. A pack that declares `taskStarted`, `taskLongRunning`,
`taskCancelled` or `responseReady` while advertising an older app minimum fails
with `PACK_VALIDATION_WORKDAY_TRIGGER_REQUIRES_APP_VERSION`; prior trigger
contracts and legacy scoped aliases remain valid.

The interactive editor exports a
`chengyin.projection-authoring-receipt/v1` document rather than writing a pack
from browser JavaScript. `apply-content-pack-projection.py` first validates the
unchanged source pack, rejects unknown or unsafe receipt data, stores a regular
sibling backup, writes `manifest.json` atomically, and validates again. A failed
post-apply check returns `PROJECTION_RECEIPT_VALIDATION_FAILED` with
`rolledBack: true`; rollback failure has its own stable code and never gets
reported as success.

Experience authoring follows the same no-network transaction boundary without
requiring contributors to hand-edit `manifest.json`. The
`chengyin.experience-authoring-receipt/v1` result distinguishes check, create
and explicit replace operations, records whether bytes were written, and uses
only an opaque relative backup reference. Unknown assets, non-video assets,
duplicate IDs and out-of-bounds steps fail before writing. If the canonical
validator rejects the updated pack, `EXPERIENCE_AUTHOR_VALIDATION_FAILED`
confirms that the original manifest was restored byte for byte.

## Contribution checklist

When adding an error case:

1. Add a unique code to the exhaustive switch.
2. Keep the low-level description technical, English and free of credentials.
3. Route app-facing display through `CompanionErrorPresentation`.
4. Add a smoke or contract assertion that freezes the code.
5. Add or update both `zh-Hans` and `en` recovery copy when the user action changes.
