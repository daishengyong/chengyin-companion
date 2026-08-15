# Chengyin Experience Pack v2

v2 extends Content Pack v1 with declarative, ordered video experiences. It keeps
the same executable-free installation, hashing, media probing, signature gate,
transactional activation and rollback rules.

The machine-readable contract is
[`Schemas/content-pack-v2.schema.json`](../Schemas/content-pack-v2.schema.json).
The Swift validator remains authoritative for filesystem containment, hashes,
media decoding and cross-reference checks that JSON Schema cannot prove.

## Compatibility

- Core accepts schema 1 and schema 2 manifests.
- Existing v1 assets and single-trigger playback remain unchanged.
- `experiences`, `focalTracks` and `safeAreas` are legal only with
  `schemaVersion: 2`.
- Unknown future schema versions are rejected instead of partially installed.
- `new-content-pack.sh` atomically creates compatibility-v2 drafts, supports up
  to 32 unique locale tags and emits an optional path-safe JSON receipt. It does
  not overwrite a destination or invent an author, source, license grant or
  review approval on the creator's behalf. Its receipt contract is
  `Schemas/content-pack-scaffold-receipt-v1.schema.json`.
- `plan-content-pack-v2-migration.sh` produces a read-only receipt for v1 and
  compatibility-v2 packs. The receipt always says `writesPerformed: false` and
  `rightsInferred: false`.
- Existing v2 manifests without `contractVersion: 2` remain install-compatible,
  but strict contribution audit classifies them as `DRAFT`, never
  `READY_FOR_LAB`.
- Strict v2 asset and experience IDs use lowercase ASCII plus `.`, `_` and `-`.
  Legacy v1 and compatibility-v2 retain the previously accepted safe uppercase
  form so adding the contribution contract does not silently break old packs.

## Contribution contract modes

Core derives one of three modes; a manifest cannot self-assert readiness:

- `legacy-v1`: playable with the v1 runtime. No source, license grant, adult
  status or accessibility approval is inferred from the old `license` string.
- `compatibility-v2`: v2 playback remains available, but contribution evidence
  is absent or uses the pre-contract shape.
- `strict-v2`: `contribution.contractVersion` is `2` and every required package
  and per-asset record is structurally present. Review can still be `draft`,
  `pending` or `rejected`, so strict shape alone does not mean ready.

Only strict v2 with exhaustive coverage, complete allowed uses and `approved`
versioned reviews can become `READY_FOR_LAB`. That is a technical contribution
gate, not final legal clearance.

## Package and per-asset evidence

Every asset proposed for community distribution needs one rights record, one
accessibility record and one fallback record. The pack also needs provenance,
adult/fiction status, attribution and a versioned review:

```json
{
  "contribution": {
    "contractVersion": 2,
    "package": {
      "source": "opaque or public source description",
      "author": "Example creator",
      "provider": "Example generation provider",
      "origin": "generative",
      "license": "LicenseRef-Example",
      "authorizationBasis": "providerOutput",
      "allowedUses": [
        "useInApp", "redistribution", "modification", "commercialUse"
      ],
      "attribution": {"required": true, "text": "Example creator"},
      "adultFictionStatus": "fictionalAdultsOnly",
      "evidenceID": "ledger.pack.example-r1",
      "review": {
        "status": "approved",
        "version": 1,
        "reviewerID": "maintainer.review-1"
      }
    },
    "rights": [
      {
        "assetID": "shared-win-react",
        "origin": "generative",
        "holder": "Example creator",
        "license": "LicenseRef-Example",
        "evidenceID": "ledger.seedance.shared-win-r1",
        "sourceSHA256": null,
        "commercialUseReviewed": true,
        "subjectStatus": "fictionalAdult",
        "source": "generation job bound by the evidence ledger",
        "author": "Example creator",
        "provider": "Example generation provider",
        "authorizationBasis": "providerOutput",
        "allowedUses": [
          "useInApp", "redistribution", "modification", "commercialUse"
        ],
        "attribution": {"required": true, "text": "Example creator"},
        "review": {
          "status": "approved",
          "version": 1,
          "reviewerID": "maintainer.review-1"
        }
      }
    ],
    "accessibility": [
      {
        "assetID": "shared-win-react",
        "descriptions": {
          "zh-Hans": "成年虚构角色在暖光工作室鼓掌庆祝。",
          "en": "An adult fictional character applauds in a warm studio."
        },
        "transcripts": {
          "zh-Hans": "这次真的完成啦。",
          "en": "That one is truly done."
        },
        "altText": {
          "zh-Hans": "成年虚构角色在暖光工作室微笑鼓掌。",
          "en": "An adult fictional character smiles and applauds in a warm studio."
        },
        "captions": {
          "zh-Hans": "这次真的完成啦。",
          "en": "That one is truly done."
        },
        "soundDescriptions": {
          "zh-Hans": "轻柔人声与短促掌声，无突发巨响。",
          "en": "Soft speech and brief applause, with no sudden loud sound."
        },
        "flashingLights": false,
        "suddenLoudAudio": false,
        "review": {
          "status": "approved",
          "version": 1,
          "reviewerID": "maintainer.access-review-1"
        }
      }
    ],
    "fallback": {
      "strategy": "starter",
      "assets": [
        {"assetID": "shared-win-react", "strategy": "starter"}
      ]
    }
  }
}
```

Rights origins are `original`, `generative`, `licensed` and `publicDomain`.
Authorization bases are `owned`, `licensed`, `commissioned`, `providerOutput`
and `publicDomain`. Allowed uses are enumerated, not prose:
`useInApp`, `redistribution`, `modification` and `commercialUse`. Attribution is
an explicit `{required,text}` record.

Subject status is explicit: `fictionalAdult`, `verifiedAdult`, `noPerson` or
`notApplicable`. Visual assets cannot pass strict audit with `notApplicable`.
Package adult/fiction status is one of `fictionalAdultsOnly`,
`verifiedAdultsOnly`, `mixedVerifiedAndFictionalAdults` or `noPeople`.
An `evidenceID` is an opaque reference into the maintainer's rights ledger; URLs,
filesystem paths, credentials and provider receipts do not belong in a pack.
Optional `sourceSHA256` binds a reviewed source without distributing it.

`descriptions` cover every declared locale. Visual assets also require `altText`.
Audio and native-audio video require `transcripts`, `captions` and
`soundDescriptions` for every declared locale. Flashing-light and
sudden-loud-audio flags are factual warnings, not marketing tags. Package,
rights and accessibility review records use `draft`, `pending`, `approved` or
`rejected`, a positive integer version and an opaque reviewer ID. Editing facts
requires a new review version; it must not preserve a stale approval.

Package fallback is always `starter`. Every asset also declares `starter` or
`skip`; video, audio and image assets must use `starter`, while declarative game
or localization assets may safely `skip`. A failed candidate is never allowed to
replace the installed working revision. This metadata improves reviewability and
access but does not replace legal review, adult consent evidence for real-person
media, or the provider's current terms.

## Projection authoring: static crops, focal tracks and safe areas

One landscape master can supply pet, stage and fullscreen presentations. Existing
`cropAnchors` remain valid. Schema 2 adds two optional, additive fields:

```json
{
  "cropAnchors": {
    "stage": {"x": 0.5, "y": 0.5, "scale": 1.15},
    "fullscreen": {"x": 0.5, "y": 0.5, "scale": 1.0}
  },
  "focalTracks": {
    "pet": [
      {"timeMs": 0, "x": 0.46, "y": 0.32, "scale": 2.8},
      {"timeMs": 1800, "x": 0.53, "y": 0.35, "scale": 2.8},
      {"timeMs": 4000, "x": 0.48, "y": 0.33, "scale": 2.8}
    ]
  },
  "safeAreas": {
    "pet": {"x": 0.42, "y": 0.26, "width": 0.16, "height": 0.16}
  }
}
```

Coordinates are normalized to the source frame and measured from its top-left.
`scale` stays between 1 and 8. A focal track has 2–32 keyframes, starts exactly
at `timeMs: 0`, increases strictly, and cannot extend beyond the declared video
duration. A pack using `focalTracks` or `safeAreas` must declare
`minAppVersion: 0.19.28` or newer, so a pre-feature app never receives a false
compatibility claim. Runtime and creator preview use the same linear interpolation. A track
takes precedence over the static anchor for the same presentation; the static
anchor remains useful to older compatible packs and as an author-readable
default.

Projection keys are `pet`, `stage` and `fullscreen`; `partial` and `full` remain
labelled v1 aliases. Edge crops are bounded instead of exposing blank gutters.
A `safeAreas` rectangle is an authoring envelope, not a macOS screen inset: the
validator proves that the full rectangle remains inside the normalized crop at
every declared keyframe. An invalid key, reversed/duplicate time, non-finite or
out-of-range geometry, an over-duration keyframe, or a clipped safe area is a
hard validation failure with a stable `PACK_VALIDATION_*` receipt. Schema 1
packs cannot opt into these fields and continue unchanged.

The AVFoundation binding creates a 15 Hz time observer only when the selected
asset actually has a dynamic track. Static assets pay no periodic-observer cost,
and reduced-dynamic mode still chooses the static fallback. The network-free
HTML preview shows all three presentations plus start/middle/end focal samples
and a dashed safe-area overlay. It contains no script, remote font, analytics or
provider credential; the samples are an author review aid, while the Swift
validator is authoritative.

For authoring rather than review, the separate interactive editor stays local
and uses the same Core geometry:

```bash
./scripts/edit-content-pack-projection.sh /tmp/my-pack --asset my-video
python3 scripts/apply-content-pack-projection.py \
  /tmp/my-pack my-video.projection.json --check --json
python3 scripts/apply-content-pack-projection.py \
  /tmp/my-pack my-video.projection.json --json
```

The browser page does not write the pack. It exports a path-free
`chengyin.projection-authoring-receipt/v1` JSON document. The applicator rejects
unknown fields, unsafe links, wrong pack/asset identities, invalid timelines
and clipped safe areas. It validates the unchanged source pack first, stores a
regular sibling backup, atomically replaces `manifest.json`, validates again,
and restores the original on failure. The receipt and backup are not a license,
rights review, signature or runtime playback approval.

## Experience model

Contributors do not need to hand-edit this array. Check a proposed sequence
without writing:

```bash
./scripts/author-content-pack-experience.sh /tmp/my-pack \
  --id ritual.shared-win \
  --kind ritual \
  --trigger taskCompleted \
  --step shared-win-enter:enter:700:crossfade \
  --step shared-win-react:react::cut \
  --step shared-win-exit:exit::crossfade \
  --locale zh-Hans \
  --cooldown 900 \
  --weight 1.5 \
  --return-policy previousMode \
  --check --json
```

Remove `--check` to create the experience. An existing ID is never replaced
implicitly; repeat the command with `--replace` only after reviewing the target.
The tool validates the unchanged pack, accepts only bounded enum/identifier
arguments, checks that every step is a declared video, creates a mode-0600
sibling backup, atomically replaces `manifest.json`, validates again and rolls
back on failure. Its `chengyin.experience-authoring-receipt/v1` JSON reports
check/create/replace, write counts and an opaque relative backup reference; it
does not confer rights approval, provenance authenticity or playback health.

Step syntax is
`assetID:role[:minimumPlaybackMs[:transition]]`. Use an empty duration to set a
transition without a minimum, for example `assetID:react::cut`.

An experience is a bounded sequence of one to eight declared video assets:

```json
{
  "id": "ritual.shared-win",
  "kind": "ritual",
  "triggers": ["taskCompleted"],
  "steps": [
    {
      "assetID": "shared-win-enter",
      "role": "enter",
      "minimumPlaybackMs": 700,
      "transition": "crossfade"
    },
    {
      "assetID": "shared-win-react",
      "role": "react",
      "transition": "cut"
    },
    {
      "assetID": "shared-win-exit",
      "role": "exit",
      "transition": "crossfade"
    }
  ],
  "locales": ["zh-Hans"],
  "cooldownSeconds": 900,
  "weight": 1.5,
  "returnPolicy": "previousMode"
}
```

Kinds:

- `reaction`: a short response to a user or work event;
- `ritual`: a repeatable multi-beat moment such as morning arrival or shared win;
- `sceneStory`: a longer environment change with an entry and exit;
- `microGameReward`: the bounded reward sequence after a local mini-game.

Step roles are `enter`, `notice`, `react`, `settle` and `exit`. Transitions are
`cut` and `crossfade`. These names describe presentation only; they do not grant
code execution, access files, or issue commands.

Return policies:

- `previousMode`: return to the user's avatar/stage/fullscreen mode;
- `keepCurrentMode`: do not change the current projection;
- `remainExpanded`: remain on the expanded stage after the sequence.

## Validation invariants

- At most 64 experiences per pack and eight steps per experience.
- Every experience ID is unique and bounded.
- Every step references a declared video asset in the same immutable pack version.
- Triggers use the same allowlist as v1.
- `taskStarted`, `taskLongRunning`, `taskCancelled` and `responseReady`
  require `minAppVersion` 0.19.42 or newer. Start, long-running and cancelled
  cues are attention-budgeted passive moments; progress heartbeats remain
  status-only. `responseReady` is a neutral result boundary and never proves
  successful task completion. The legacy `manual:event.reply_ready` route
  remains a fallback for existing packs.
- Experience weight is `0.01...100`; cooldown is at most seven days.
- Experience locale overrides are explicit; without one, pack locales apply.
- Preview output is written outside the pack and cannot contaminate validation.
- No experience can contain scripts, URLs, commands, arbitrary text payloads or
  executable plugins.
- Unknown manifest keys are rejected before Codable decoding; they are not
  silently ignored. Paths must stay relative, regular and declared. Symlinks,
  hard links, hidden files, case-fold collisions and undeclared files fail.
- A manifest is at most 1 MiB; a pack has at most 256 files and 1.5 GiB unpacked;
  one asset is at most 512 MiB. Media is bounded to 33,177,600 pixels and ten
  minutes before first-frame/image decode. Video installation also performs
  bounded decoded-sample reads at midpoint and tail; native audio gets a tail
  decode and must keep its track start/end within 250ms of video. This detects
  gross damage or timeline drift without claiming perceptual lip-sync, loudness
  or seamless-loop certification.
- Contribution records may reference only declared assets. Rights/accessibility
  records cannot be duplicated, localized copy uses declared locales, and
  source/author/provider/attribution values cannot disclose private local paths.
- `audit-content-pack.sh --strict` requires full per-asset rights and
  accessibility coverage, allowed uses, approved versioned review, localized
  descriptions/alt text/captions/sound descriptions and explicit package plus
  per-asset fallback before reporting `READY_FOR_LAB`.

## Runtime state

Installed v2 packs are resolved to immutable `CompanionVideoSequence` values.
Selection preserves caller trigger order, ranked locale matching, weighted choice,
recent-sequence exclusion, cooldown and explicit fallback triggers. One shared,
bounded Core policy ranks exact tags first, then script-compatible declarations,
then a generic language, then another compatible region. Script conflicts such as
`zh-Hans` versus `zh-TW` do not match; system-style `zh_TW` input is normalized,
while malformed, oversized and beyond-limit candidates are ignored. The same
ranking resolves alt text, captions, transcripts and sound descriptions, so media
and VoiceOver copy cannot silently choose different language variants. Sequence IDs
are qualified by pack and version, so updates cannot silently reuse old playback
state.

The application plays v2 steps in manifest order and treats the final video-end
signal as the experience completion boundary. `crossfade` steps use a short
opacity transition; `cut` steps replace the previous item immediately. A bounded
watchdog and per-item AVFoundation failure handling prevent a broken pack from
swallowing task-terminal events: the pack health record is updated and the app
replays the same event through the built-in v1/bundled fallback without selecting
the failed experience again.

An experience is added to recent/cooldown memory only after every step completes.
Stale or duplicate video-end callbacks cannot advance a replacement sequence.
`previousMode`, `keepCurrentMode` and `remainExpanded` are applied by the app at
the sequence boundary; they cannot resize windows or execute code themselves.

Validated per-asset accessibility metadata is also carried into the immutable
runtime catalog. During a multi-step experience, localized `altText` (falling
back to `descriptions`) becomes the non-visual media label; localized `captions`
or `transcripts` and `soundDescriptions` become the media value. The runtime
normalizes whitespace, applies deterministic locale fallback, removes duplicate
step copy and bounds the final label/value to 512/1,024 characters. Flashing-light
and sudden-loud-audio declarations become localized VoiceOver hints. This does
not add a visual caption panel, so direct-play video remains visually clean.
Compatibility and v1 packs without these fields keep the existing localized
event/status fallback; no approval state is invented. The source audit proves
the binding exists, but physical VoiceOver review remains a release gate.

## Core-derived quality levels

Quality is not a manifest field and creators cannot self-assert it:

- **Lab**: pending real-playback health (or otherwise not healthy);
- **Stable**: a local pack whose active immutable revision passed real playback;
- **Verified**: a free/paid distribution tier that passed the required signature
  gate and then passed real playback.

Health and quality are separate: a disabled revision is not selected at runtime,
and a newly installed official revision remains Lab until its first playback
actually advances.

## Creator flow

```bash
./scripts/new-content-pack.sh /tmp/my-pack cc.example.my-pack starter --locale zh-Hans --locale en-US --json
./scripts/validate-content-pack.sh /tmp/my-pack --json
./scripts/plan-content-pack-v2-migration.sh /tmp/my-pack --json
./scripts/preview-content-pack.sh /tmp/my-pack
./scripts/edit-content-pack-projection.sh /tmp/my-pack --asset my-video
./scripts/audit-content-pack.sh /tmp/my-pack --strict --json
./scripts/audit-content-pack-locales.sh /tmp/my-pack --locale zh-CN --locale en-US --json
./scripts/build-content-pack-archive.sh /tmp/my-pack /tmp/my-pack.chengyinpack --json
./scripts/audit-content-pack-archive.sh /tmp/my-pack.chengyinpack --json
```

The validator does not call Seedance, TTS or any remote service. Provider keys and
generation receipts stay outside distributable packs.
The locale matrix is also network-free and read-only. It uses strict locale
compatibility for media, the declared pack order for accessibility fallback,
and emits `chengyin.content-pack-locale-matrix/v1`. Receipts intentionally omit
localized copy, media decode results and paths; warnings are review signals, not
invented rights, native-language review or public-release approval.
The builder publishes only after a separately compiled archive auditor accepts
the staged `.chengyinpack`. The app and auditor share the same bounded ZIP policy,
private extraction/postcondition checks and stable `PACK_ARCHIVE_*` errors. Both
flat archives and one wrapped root are accepted; source directories remain
supported for iterative authoring. Archive PASS proves local structure, manifest
hashes and media decode, not rights, provenance authenticity, signing or public
release readiness.
The local preview renders rights status, subject status, descriptions,
transcript coverage and sensory warnings beside each asset so reviewers do not
need to infer them from prose in a pull request. Video cards also render pet,
stage and fullscreen viewports with the same `CompanionPresentationProjection`
contract used by AVFoundation. Missing or invalid anchors show the stable mode
default, and v1 `partial`/`full` aliases are labelled rather than silently
rewritten. Dynamic tracks add start/middle/end storyboard samples; safe areas
are drawn as dashed envelopes, using the same clamped top-origin geometry as
runtime without adding script or a network request.
