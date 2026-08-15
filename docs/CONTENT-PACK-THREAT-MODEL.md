# Content Pack untrusted-input threat model

Status: implemented contract for local installation and contribution preflight.
It does not turn prototype media into publicly licensed media.

## Trust boundary

A Content Pack is untrusted data, even when it came from a pull request, a
friend or a previously installed directory. Core accepts only declarative files;
the pack cannot run code, invoke a URL, read another directory, issue a Codex
command or grant itself a quality/review status.

Validation happens before the transactional store changes the active pointer:

For `.chengyinpack`, an earlier archive boundary first copies the selected regular
file into a private mode-0700 workspace, validates the ZIP central directory and
every referenced local header, invokes only the fixed macOS extractor, and proves
the extracted file set, types and sizes match the preflight. Directory drafts skip
only this archive layer; both routes then enter the same canonical validation:

1. bound and parse `manifest.json`;
2. reject unknown fields and invalid cross-references;
3. resolve every declared path inside the package root;
4. enumerate the full tree and reject undeclared or unsafe entries;
5. verify SHA-256 for every asset;
6. inspect media metadata within resource bounds, then decode a representative
   frame/image or parse declarative JSON;
7. stage an immutable version and atomically activate only after all checks pass.

Failure leaves the current installed revision unchanged. A first-play failure
marks health and replays the built-in Starter behavior; an unhealthy candidate
cannot silently replace a known-good revision.

## Threats and controls

| Threat | Control | Stable family |
| --- | --- | --- |
| `../`, absolute or backslash traversal | Relative normalized path contract and resolved-root containment | `PACK_VALIDATION_*PATH*` |
| Central/local ZIP name or method mismatch | Parse both headers from the private byte snapshot and require exact agreement before extraction | `PACK_ARCHIVE_UNSAFE_ENTRY` / `INVALID_ZIP` |
| Encrypted, ZIP64, unknown compression or link entry | Accept one disk, 32-bit bounded stored/deflate regular files and directories only | `PACK_ARCHIVE_UNSUPPORTED_FEATURE` |
| ZIP bomb or forged expanded size | 512 MiB archive/entry, 256 files, 1.5 GiB total, 8 MiB central directory and 200:1 ratio gate | `PACK_ARCHIVE_RESOURCE_LIMIT` |
| Extractor creates a different tree | Post-extraction exact file/type/size comparison with no symlink and private-root containment | `PACK_ARCHIVE_EXTRACTION_FAILED` / `UNSAFE_ENTRY` |
| Symlink escape | Reject symlinks and a resolved URL different from the declared regular file | `PACK_VALIDATION_SYMBOLIC_LINK` / `PATH_TRAVERSAL` |
| Hard-link alias | Reject regular files with link count above one | `PACK_VALIDATION_HARD_LINK` |
| Hidden/undeclared payload | Reject hidden components, unsupported types and every file not in the manifest | `HIDDEN_PATH`, `UNDECLARED_FILE` |
| Case/Unicode collision | Canonicalize and case-fold enumerated paths before uniqueness check | `PATH_COLLISION` |
| Oversized archive/media | 256 files, 1.5 GiB unpacked, 1 MiB manifest, 512 MiB per asset | `TOO_MANY_FILES`, `*_TOO_LARGE` |
| Image/video decode bomb | Reject declarations and actual metadata above 33,177,600 pixels or ten minutes before decode | `MEDIA_DIMENSIONS_TOO_LARGE`, `MEDIA_DURATION_TOO_LONG` |
| Corrupt or unsupported media | System playability/track/codec checks, real frame/image decode and JSON parse | `PACK_MEDIA_*` |
| Hash substitution | Streaming SHA-256 over the exact staged bytes | `PACK_VALIDATION_SHA256_MISMATCH` |
| Duplicate identifiers | Unique asset, experience, rights, accessibility and fallback IDs | `PACK_VALIDATION_DUPLICATE_*` |
| Claim/file mismatch | Track, dimensions, duration, native-audio and source-hash checks | `PACK_MEDIA_*_MISMATCH` |
| Hostile or falsely compatible projection timeline | Only five presentation keys; 2–32 finite keyframes, strict time order, 0ms start, media-duration bound, normalized geometry, safe-area containment and app-minimum gate | `INVALID_FOCAL_TRACK`, `INVALID_SAFE_AREA`, `SAFE_AREA_NOT_VISIBLE`, `PROJECTION_REQUIRES_APP_VERSION` |
| Falsely compatible workday cue | New workday triggers are allowlisted and require `minAppVersion >= 0.19.42`; response-ready remains semantically distinct from trusted completion | `WORKDAY_TRIGGER_REQUIRES_APP_VERSION`, Core trust-policy tests |
| Unknown future field | Recursive known-key pass before Codable; JSON Schema also uses `additionalProperties: false` | `PACK_VALIDATION_UNKNOWN_MANIFEST_FIELD` |
| Private path leakage | Evidence IDs are opaque; source/author/provider/attribution reject local home/file paths; receipts redact absolute paths | `PACK_VALIDATION_PRIVATE_PATH_DISCLOSURE` |
| Forged contribution approval | Core derives mode/readiness; v1 and old v2 never infer rights; strict review is versioned and exhaustive | `STRICT_*`, audit `DRAFT` |
| Broken fallback declaration | Package Starter fallback plus exactly one type-compatible record per asset in strict v2 | `*_FALLBACK_*` |
| Malicious projection authoring receipt | Versioned exact fields, regular single-link input, pack/asset binding, bounded modes/timeline, safe-area containment and no media path | `PROJECTION_RECEIPT_*` |
| Malicious experience authoring arguments | Schema-v2 source validation, bounded enums/IDs/counts, declared-video cross-reference, explicit replacement, sibling backup, atomic write and post-validation rollback | `EXPERIENCE_AUTHOR_*` |
| Recovery-area traversal or path disclosure | Restore/purge accept one bounded ASCII opaque basename, resolve exactly one direct child and never project a URL into UI state | `PACK_STORE_INVALID_RECOVERY_ITEM` |
| Recovery symlink or damaged metadata | One-level no-follow inventory isolates the item as cleanup-only; permanent deletion removes the link/entry itself without following it | `PACK_RECOVERY_*` |
| Recovery-area exhaustion | Inventory fails closed above 128 visible entries with an actionable stable code | `PACK_STORE_RECOVERY_LIMIT_EXCEEDED` |
| Failed restore leaves damaged active pack | Validate again after the move and transactionally return the directory to recovery on failure | `PACK_STORE_RECOVERY_ROLLBACK_FAILED` |

## Failure semantics

- Structural, rights-contract or media preflight failure: do not install.
- Candidate first-play failure with a previous healthy version: atomically
  restore the previous version and use Starter for the interrupted event.
- First installed revision fails playback: disable the bad revision and use
  Starter; report that there is no rollback version rather than pretending the
  content recovered.
- `skip` is legal only for non-media declarative assets. Video, audio and image
  assets must explicitly return to Starter.
- Error receipts contain `status`, stable `code`, safe `message` and executable
  `recoveryAction`. They must not include usernames or absolute paths.

## Restricted creator media backend

The application and ordinary creator environment use AVFoundation for media
metadata, codec, timeline and representative-sample validation. A detected Codex
outer sandbox can deny AVFoundation sample decoding even when the same local file
decodes on a normal Mac. In that one creator-only environment, the CLI may retry
the decode portion with a fixed local FFmpeg executable resolved only beneath
`/usr/bin`, `/opt/homebrew/Cellar/ffmpeg` or `/usr/local/Cellar/ffmpeg`.

The fallback invokes no shell or network, accepts no executable path from the
pack, decodes the complete primary video and optional audio stream with one
thread, discards output and terminates after 20 seconds. AVFoundation still owns
container, codec, dimensions, duration, audio declaration and timeline checks.
The machine-readable audit receipt reports either `avfoundation` or
`avfoundation+fixed-ffmpeg-full-software-decode`; failure remains the stable
`PACK_MEDIA_FIRST_FRAME_DECODE_FAILED` family.

This is a restricted creator-validation compatibility path, not the application
playback backend and not evidence that AVFoundation works on a clean physical
Mac. It also does not authenticate FFmpeg or defend against an active local
attacker who can replace an allowlisted installation. Public release still
requires clean-Mac playback review and the independent media-rights gates.

## Executable checks

- `scripts/run-content-pack-smoke.sh`: path escape, symlink, duplicate IDs,
  unknown keys (including nested projection fields), private path, oversized
  media, declared decode bomb, malformed/over-duration focal tracks, invalid or
  clipped safe areas, corruption, transactional install/rollback and
  UI/JSON/log presentation, cross-restart recovery, opaque-ID traversal,
  damaged-item isolation, recovery rollback, link-only purge and bounded inventory.
- `scripts/run-content-pack-archive-smoke.sh`: flat and single-root success,
  transactional runtime install and staging cleanup, traversal, link, duplicate,
  case collision, local-header mismatch, encryption, unknown compression, forged
  size, compression bomb, missing root, corruption, atomic build and no-overwrite.
- `scripts/run-content-pack-v2-contract-matrix.sh`: valid v1, valid strict v2,
  missing required evidence, rights pending, accessibility missing, malicious
  input, media failure with declared fallback and fully unrecoverable input.
- `scripts/run-content-pack-migration-smoke.sh`: read-only v1→v2 receipt with no
  inferred rights.
- `scripts/run-content-pack-projection-editor-smoke.sh`: no remote route/API,
  top-origin geometry self-check, reduced-motion and keyboard semantics,
  bilingual copy and path-free embedded receipt.
- `scripts/run-projection-receipt-apply-smoke.sh`: check-only mode, atomic apply,
  sibling backup, clipped/unknown/symlink rejection, privacy-safe receipts and
  exact manifest restoration after post-apply validation failure.
- `scripts/run-content-pack-experience-authoring-smoke.sh`: no-write check,
  ordered create, explicit replace, unsafe-link/unknown/non-video/duplicate
  rejection, privacy-safe receipts and byte-identical rollback after canonical
  post-write validation failure.
- `scripts/check-error-code-contract.py`: shared registry coverage for Core and
  all creator CLIs.

## Creator CLI build-cache boundary

The six local creator wrappers obtain their Swift executable from one build
registry. A cache entry is a committed pair: a regular executable plus a
versioned `manifest.json`. The manifest records the tool ID and fingerprint,
the binary SHA-256, repository-relative source SHA-256 values, and privacy-safe
hashes of the compiler, SDK and test namespace identities. It is published last
as the commit marker. Every cache hit hashes the executable again and compares
a freshly rendered deterministic manifest before returning the path.

This check detects accidental truncation, corruption, stale metadata and simple
replacement of either the executable or its manifest. A mismatch fails closed
with `CREATOR_TOOL_BUILD_CACHE_INVALID` and an action to move the affected cache
aside and rebuild locally. It is not a code-signing or hostile-filesystem
boundary: an active attacker who can replace both the executable and manifest,
or change the running repository/build script, is outside this control. Do not
describe a content-addressed cache path as proof of binary authenticity.

- `scripts/run-creator-tool-cache-smoke.sh`: fresh publish, verified hit,
  source/toolchain namespace invalidation, executable use, privacy-safe
  manifest, truncated-binary rejection, altered-manifest rejection, stable
  unknown-tool receipt and single source registry.

The full matrix runs in CI and `scripts/doctor.sh`. Security limits may tighten
in a compatible release when real abuse or platform decoder behavior requires
it; such a change must keep a stable error code and an actionable migration.
