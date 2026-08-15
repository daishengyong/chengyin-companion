# Chengyin Companion

[简体中文](README.md) · English

![Chengyin Companion: give your Codex workflow a heartbeat](docs/assets/github-hero.svg)

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111827?logo=apple)](docs/COMPATIBILITY.md)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%E2%80%93M4-6d5cf6)](docs/COMPATIBILITY.md)
[![Swift](https://img.shields.io/badge/Swift-native-f97316?logo=swift&logoColor=white)](Package.swift)
[![MIT code](https://img.shields.io/badge/code-MIT-55c2b5)](LICENSE-SCOPE.md)

Turn the rhythm of Codex work into a visible, playful macOS companion. It can react when work finishes, nudge you to take a break, and respond to taps, holds, drags, and mini-games. It runs locally by default, records no microphone, uploads no code, and requires no account.

**[Try it in two minutes](https://github.com/daishengyong/chengyin-companion#try-it-in-two-minutes-ask-codex)** · **[First interactions](https://github.com/daishengyong/chengyin-companion#first-interactions)** · **[Content packs](docs/PACK-SPEC-v2.md)** · **[Contribute](CONTRIBUTING.en.md)** · **[Share ideas](https://github.com/daishengyong/chengyin-companion/discussions)** · **[Report an issue](https://github.com/daishengyong/chengyin-companion/issues)**

## What is available now

| Capability | Public repository status |
| --- | --- |
| Three desktop presentations, gesture feedback, care rhythms, and six mini-games | Builds and runs |
| Content Pack v1/v2 creation, auditing, import, and safe fallback | Available |
| Local operation without an account, microphone, or telemetry | Available |
| Animated system-symbol fallback | Included by default |
| Full character video, voice, and branded Starter media | Not public; rights are reviewed asset by asset |
| Developer ID signed and notarized DMG for non-technical users | In preparation; an unsigned preview is not presented as a formal release |

The public repository is the complete **MIT code edition**, not a timed demo. It intentionally excludes real-person and brand media whose public rights are not approved. You can use the interaction system immediately and import Content Packs you have the right to use. See [public code-only mode](PUBLIC-CODE-ONLY.md) and [license scope](LICENSE-SCOPE.md).

## Try it in two minutes: ask Codex

Copy the entire prompt below into Codex. It checks the Mac before cloning, building, installing, and launching. It does not use `sudo`, call Seedance/TTS, read API keys, or edit `~/.codex/config.toml`.

```prompt
Please install and launch the public source preview of Chengyin Companion:
https://github.com/daishengyong/chengyin-companion

Requirements:
1. Confirm this is an Apple Silicon Mac running macOS 14+, then check Xcode Command Line Tools and Python 3.9+.
2. Clone into ~/ChengyinCompanion if it does not exist. If that directory already has uncommitted changes, preserve it and use a fresh temporary clone.
3. Run ./scripts/bootstrap-local.sh --check-only first.
4. Run ./scripts/bootstrap-local.sh only after preflight passes, then confirm that the app installs and launches.
5. Do not use sudo, bypass macOS security, read or upload secrets, call Seedance/TTS, or modify ~/.codex/config.toml.
6. Report the installed version, application location, launch result, and any public-release gates that remain pending.
```

Manual installation is four commands:

```bash
git clone https://github.com/daishengyong/chengyin-companion.git ~/ChengyinCompanion
cd ~/ChengyinCompanion
./scripts/bootstrap-local.sh --check-only
./scripts/bootstrap-local.sh
```

A source install creates a local ad-hoc development build, not a notarized public DMG. It does not silently replace the global Codex notification configuration. Use `Command + Shift + R` to preview task-completion celebration; all other direct interactions work immediately. See the [new-user quickstart](docs/QUICKSTART.md) for recovery and troubleshooting.

## First interactions

| Action | Response |
| --- | --- |
| Single click | A short response appropriate to the current daypart |
| Double click | Open a life or fantasy scene |
| Hold and release | Affection feedback and a randomized close action |
| Drag or fling | Pickup, inertia, voice, and edge docking |
| `Command + Shift + M` | Cycle pet, stage, and fullscreen |
| `Command + Shift + G` | Start the 20-second “Catch Me” game |
| Open the magic wand | See actions, scenes, and mini-games together |

The code edition uses animated system graphics in place of unpublished character media. After installing a lawful Content Pack, the same runtime automatically uses its videos, audio, framing, and failure fallbacks.

## Developer quick entry

Launch a project-local preview without installing into `/Applications`:

```bash
./scripts/preview-local.sh
```

Run the fastest offline contributor preflight:

```bash
./scripts/check-contribution.py --profile quick --json
python3 scripts/audit-public-source-secrets.py --json
```

The source flow never calls Seedance/TTS, reads API keys, requests microphone access, creates an account, or uploads diagnostics. Python compatibility, zero-authorization inspection, and isolated source-package checks are documented in the [new-user quickstart](docs/QUICKSTART.md).

## Project map

- [Non-technical installation, first play, and recovery](docs/QUICKSTART.md)
- [Local-first boundary: no monetization, account, ads or automatic sharing](docs/PRODUCT-BOUNDARY.md)
- [Codex companion product and engineering architecture](docs/CODEX-PRODUCT-ARCHITECTURE.md)
- [Global original-persona and Seedance content system](docs/GLOBAL-PERSONA-SYSTEM.md)
- [Code, Starter, community-media, and persona rights boundaries](docs/LICENSING-AND-RIGHTS.md)
- [Local Seedance Mini billing safeguards](docs/SEEDANCE-BILLING-SAFETY.md)
- [Seedance B0 original-persona pilot and measured cost](docs/pilots/SEEDANCE-B0-PILOT.md)
- [Globalization and localization plan](docs/LOCALIZATION-PLAN.md)
- [Chengyin Content Pack v1](docs/PACK-SPEC-v1.md)
- [Contributor architecture map](docs/CONTRIBUTOR-ARCHITECTURE.md)
- [Core and App module boundary contract](docs/CORE-MODULE-BOUNDARY.md)
- [Compatibility policy](docs/COMPATIBILITY.md)
- [Stable error codes and privacy-safe failures](docs/ERROR-CODES.md)
- [Chengyin Experience Pack v2](docs/PACK-SPEC-v2.md)
- [New-Mac first-use and low-motion audit](docs/FIRST-USE-AND-LOW-IMPACT-AUDIT.md)
- [English first-use five-step visual audit](docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.md)
- [Release-readiness states and human owner gates](docs/RELEASE-READINESS-STATES.md)
- [Reviewed community pack index v1](docs/COMMUNITY-PACK-INDEX.md)
- [Verifiable source-preview package contract](docs/SOURCE-PACKAGE-CONTRACT.md)
- [Built-in Starter provenance, rights and accessibility contract](docs/STARTER-MEDIA-CONTRACT.md)
- [Local build, update, and rollback](docs/LOCAL-UPDATE.md)
- [One-command project-local preview](docs/LOCAL-PREVIEW.md)
- [Codex × Seedance desktop-companion production kit](docs/show/README.md)
- [Contributing guide](CONTRIBUTING.en.md)
- [Security policy](SECURITY.en.md)
- [Public roadmap](ROADMAP.md)
- [Project governance](GOVERNANCE.md)
- [Code of conduct](CODE_OF_CONDUCT.md)
- [Support and issue reporting](SUPPORT.md)

## Complete product capabilities

These capabilities are implemented and continuously checked in the source.
The public code edition replaces rights-pending built-in character media with
animated system graphics; a lawful Content Pack activates video and audio
through the same runtime.

- Native SwiftUI content hosted by an AppKit floating panel.
- No recording, dictation, chat thread, or microphone permission.
- Three presentations: fullscreen interactive stage, lower-right companion stage, and animated mini pet.
- The fullscreen window is transparent by default. Idle mode keeps a lightweight control layer; active interactions show only the clean central video.
- The surface can switch among Transparent, Cinematic, and Dim. macOS Reduce Transparency safely resolves Cinematic to Dim, while Increased Contrast strengthens the backing.
- The window can follow its current screen, use the main display, or target a specific display. Disconnecting that display recovers to the current/main screen instead of leaving the pet or stage off-screen.
- The AppKit panel uses the cross-Space/full-screen overlay contract and observes unhide and display-topology changes. A lightweight five-second check reasserts window policy without decoding media, stealing focus, or overriding intentional minimization.
- Pet, stage, and fullscreen reuse the same 720p landscape videos. Optional time-addressed focal tracks keep the character framed in the pet while stage and fullscreen preserve more of the scene.
- Seedance-native dialogue, lip sync, motion, and ambience play in audiovisual mode by default. A button switches to pre-generated TTS audio-only mode.
- Window mode, appearance, display target, pet position, recent reactions, and sound preference persist locally. Display names are never persisted or included in diagnostics.
- Includes 159 pre-generated Volcengine Seed-TTS 2.0 “charming girlfriend” lines: 63 for direct control and mini-games, and 48 for eye breaks, focus, meals, and precise time announcements.
- Nine large actions: drink, stretch, clap, jump, twirl, laugh, heart, kiss, and cheer.
- The “Play” menu directly plays nine independent Seedance audiovisual interaction videos.
- Four mini-life scenes: kitchen tasting, bedside invitation, workout partner, and vanity kiss.
- Those mini-life scenes use Seedance 2.0 Mini to generate picture, dialogue, lip sync, movement, and ambient sound together.
- Mini-life loops stay muted in pet idle mode; direct playback expands automatically and enables the native synchronized soundtrack.
- Four 16:9 fantasy scenes: lunar orbit, underwater glass room, time-frozen café, and rainy-night portal.
- Three randomized looks for an original adult fictional character: rose satin, energetic sport, and evening date.
- A transparent desktop character replaces the old square character card.
- The roughly 100-pixel pet continuously cycles center compositions from the shared landscape masters instead of using a stern static portrait.
- New installs start as a non-intrusive animated mini pet. Hover coaching teaches single tap, double tap, long press, and drag one step at a time; existing saved window modes are preserved.
- Single tap chooses an explicit acknowledgement by daypart; double tap enters a companion or fantasy scene and avoids recent repetition. Hydration, movement, workout, and time-themed beats remain available through care or the magic wand but never impersonate a tap response.
- Pet, stage, and fullscreen character regions support pointer following, long-press affection, and drag feedback.
- Long press starts with a short voice and haptic response; release randomly plays a Seedance-native kiss, heart, or laugh video.
- A short drag makes the character resist and tilt. After 24 pixels, an “picked up” voice and haptic response moves the pet window.
- Fast flings, lifting upward, setting down, and edge docking each have randomized voice feedback. Edge docking persists the location.
- “Catch Me” is a 20-second mini-game in which the pet jumps among nine screen positions and tracks catches, combo, time, and best progress.
- Five catches trigger an expanded Seedance-native celebration. Trusted task completion remains queued until the game or short voice finishes.
- “Edge Hide-and-Seek” hides the pet at all four edges while keeping about 48 horizontal or 112 vertical pixels clickable. Five finds trigger a Seedance kiss reward.
- “Action Combo” asks for tap, long press, and fast fling within 20 seconds, confirms every step with voice and haptics, and rewards success with a hidden twirl video.
- “Heart Trace” uses a clean stage and nine nodes; holding and tracing the whole heart unlocks a native audiovisual heart reward.
- “Heartbeat Rhythm” emits eight pink pulses and layered low-frequency beats; six accurate hits with a three-hit combo unlock a native jump reward.
- “Treat Time” lets the user drag a strawberry, cake, latte, or chocolate into a glowing target. Three successful treats trigger a kitchen audiovisual surprise.
- Single tap, long-press release, fling, menu playback, and task celebration automatically hide toolbars, captions, explanatory text, and decorative frames, restoring controls afterward.
- Stage and fullscreen idle states use the same natural breathing, environmental movement, and cinematic video library.
- Playback timing uses the first actually visible frame and prewarms at most four local assets. Privacy-minimal diagnostics expose only first-frame P95, failure counts, and peak concurrency—never media paths or names. A 30-minute headless media soak passed on the current Mac (26 assets, 737,616 frames, 23ms decode-first-frame P95, 28.03MB peak resident growth); real-window first-frame, GPU, and human audiovisual checks remain separate evidence.
- A spoken event in pet mode expands to stage, performs the action and voice, then returns to pet.
- Direct mini-life playback in pet mode also expands until the native line ends.
- A fantasy scene launched from the pet expands to landscape stage and returns afterward; stage and fullscreen keep their current mode.
- The magic wand opens a fixed four-tab palette above the pet; games, mini life, fantasy, and actions fit without scrolling. Rapid selections preserve the original pet return, and a failed generated clip hands off to its local fallback before the window shrinks.
- Direct taps and scheduled care use separate candidate pools. Time announcements, hydration, movement, task-terminal lines, and game cues cannot leak into a pet click.
- Only an explicit Companion Event Protocol v1 `task.completed + success` can celebrate completion. Codex turn boundaries mean only “response ready”; legacy log watching is off by default.
- “Shared Workday” stores only start, response, completion, blocked and recovery counts plus elapsed duration. It has no field for task titles, code, prompts, or paths. Loads distinguish primary, rollback-copy and safe-default recovery; persistence failure never suppresses a real task response and exposes only a stable issue-safe code.
- The top workday status shows today’s shared completions. It resets across calendar days without streak loss, degradation, or make-up pressure.
- The workday status opens a visible summary and privacy boundary. “Forget today” deletes primary and rollback data so a restart cannot resurrect it.
- “Forget all shared memories” clears moments, keepsakes, surprise progress, playback history, and rollback copies while preserving the user-selected companion tone as a preference.
- `response.ready` obeys a local interruption budget. Rapid Codex turns, quiet hours, or active interaction produce only a subtle cue; trusted terminal events are never lost.
- Work, care, play, and ambient presence pass through one experience director. User gestures respond immediately, terminal events queue reliably, and low-priority care never piles up behind a game or video.
- Lifestyle care independent of Codex includes morning, hydration, sedentary, eye-rest, focus, lunch, hourly/half-hour, evening wrap-up, and late-night rest rhythms that survive app updates.
- Care has quiet, standard, and lively cadences; 23:30–08:30 quiet hours; 30-minute, one-hour, or today pauses; and a visible next-care time.
- Optional launch at login is managed by macOS Login Items.

## Shortcuts and gestures

- `Command + Shift + M`: cycle all three presentations.
- `Command + Shift + 1 / 2 / 3`: pet / stage / fullscreen.
- `Command + Shift + R`: preview task-completion celebration.
- `Command + Shift + P`: preview a random action and voice.
- `Command + Shift + G`: start or stop “Catch Me.”
- `Command + Shift + K`: start or stop “Edge Hide-and-Seek.”
- `Command + Shift + J`: start or stop the tap → hold → fling combo.
- `Command + Shift + H`: start or stop “Heart Trace.”
- `Command + Shift + B`: start or stop “Heartbeat Rhythm.”
- `Command + Shift + F`: start or stop “Treat Time.”
- Single-click the character for a time-appropriate short response.
- Double-click for a time-appropriate life or fantasy scene.
- Long-press to start affection feedback; release for a randomized close action video.
- Short drag to make the character tilt and answer; continue beyond 24 pixels to move the window with pickup feedback.
- Fast-fling or drag to an edge for voice, haptic, inertia, or magnetic docking feedback.
- Right-click to change presentation, preview an action, or quit.

## Explicit local task events

The project implements Companion Event Protocol v1. Events are limited to 64 KiB and reject payloads containing task titles, code, prompts, paths, or personal information. The following command writes a privacy-safe simulated completion into a temporary directory and never reaches the live app:

```bash
CHENGYIN_EVENT_ROOT="$(mktemp -d)" swift run CompanionEventEmitter task.completed 1000
```

Without `CHENGYIN_EVENT_ROOT`, a production adapter writes atomically into the current user’s `Application Support/Chengyin/events`. Validation commands must use a temporary directory so test celebrations never enter the live experience. The old `~/.codex/sessions` observer is off by default because its `task_complete` means a turn boundary, not completion of the user’s objective.

The official Codex `notify` mapper can also be tested locally:

```bash
CHENGYIN_EVENT_ROOT="$(mktemp -d)" swift run CompanionEventEmitter codex-notify \
  '{"type":"agent-turn-complete","cwd":"/discarded","input-messages":["discarded"],"last-assistant-message":"discarded"}'
```

It maps only the official `agent-turn-complete` signal to neutral `response.ready` (“Codex has a new result”), never to whole-task success, while discarding working directory, input, response text, and upstream IDs. Production installation edits user-level Codex configuration only after showing the exact change and receiving explicit confirmation; it never overwrites an existing `notify`. See the [Codex product and engineering architecture](docs/CODEX-PRODUCT-ARCHITECTURE.md).

An optional single-notification App Server ingress is also implemented: `turn/started` maps to start, failed and interrupted map to their true terminal states, and completed still means only `response.ready`. It does not start or manage App Server. See the [App Server adapter contract](docs/CODEX-APP-SERVER-ADAPTER.md) for the privacy projection, verification commands, and unfinished boundary.

Run contract checks with:

```bash
swift run CompanionContractChecks
```

## Content packs and recovery

Content Pack v1/v2 now reaches the local runtime rather than stopping at manifest validation:

- Staging validates every hash, path, file type, size, and trigger, then uses system media frameworks to check codec, duration, dimensions, audio declarations, and the first visible frame.
- Built-in, community and local packs pass manifest, rights and trust gates. The legacy `paid` tier remains parseable only for compatibility; this build has no entitlement provider or purchase entry point, so it always fails closed.
- Immutable version directories and atomic `active.json` keep the current revision intact after failed upgrades.
- Enabled installed videos enter selection by trigger and locale; the Starter Bundle remains the permanent fallback.
- A new revision becomes healthy only after real playback advances. Failure rolls back to the previous revision or disables a broken first install.
- Settings can explicitly export and preflight a portable backup. It contains preferences, four gesture-learning steps, and active local packs—not shared memories, pointer trails, Codex sessions, prompts, tasks, code, paths, or events.
- Settings can copy a privacy-minimal issue diagnostic. It excludes user names, paths, task text, prompts, code, event history, relationship memory, pack identifiers, and secrets, and never uploads automatically.
- Pack and backup failures show bilingual recovery guidance plus stable issue-safe codes rather than raw system errors that may contain absolute paths.
- “Local Health” checks build identity, Starter media, the Codex local event bridge, content library, and the microphone-free boundary, and shows first-frame P95, failures, and peak concurrency. Only event-directory permission tightening and interrupted library transactions are safe one-click recoveries; unexpected files/symlinks, identity, media, and privacy anomalies remain manual. Recovery never replaces the app, deletes media, changes preferences, or calls the network.
- v2 adds declarative reactions, rituals, scene stories, and mini-game rewards of at most eight steps. JSON Schema, cross-reference validation, creator preview, runtime selection, ordered playback, crossfade, completion-only cooldown, and safe fallback are implemented; v1 remains compatible.
- Schema 2 video may optionally declare 2–32 time-addressed focal keyframes and per-presentation safe areas. Core owns linear interpolation and edge containment; validation rejects reversed, over-duration, or safe-area-clipping declarations, while static legacy assets add no periodic playback observer.
- Contribution modes are `legacy-v1`, `compatibility-v2`, and `strict-v2`. Strict v2 requires package and per-asset source, author/provider, authorization basis, enumerated uses, attribution, adult/fictional status, localized alt text/captions/sound descriptions, per-asset fallback, and versioned review. Old packs remain usable but are never inferred as licensed; a read-only migration receipt lists real gaps.
- Packs are untrusted input. Unknown fields, path or symlink escape, hard links, duplicate IDs, oversized media, decode bombs, corruption, declaration mismatches, and private-path leakage all have stable error codes, recovery actions, and CI fixtures.

Settings provide graphical `.chengyinpack` archive or local-folder import, per-pack state, explicit rollback, recoverable removal, and same-session undo. An archive is copied into private staging, checked for central/local-header inconsistencies, traversal, links, collisions and resource abuse, then post-checked after fixed-system extraction before the existing manifest, hash, media and transactional install gates run. Imports execute no pack code, make no network request, and never overwrite the app. Disabling “Enable local content packs” immediately returns to Starter without deleting pack files or active pointers.

The product intentionally has no store or purchase recovery. A production Ed25519 key and signed/notarized public binary are also unfinished. This is a locally validated product foundation, not a public-release claim.

Contributors can create and validate a local pack without launching the app:

```bash
./scripts/new-content-pack.sh /tmp/my-pack cc.example.my-pack starter --locale zh-Hans --locale en-US --json
./scripts/validate-content-pack.sh /tmp/my-pack --json
./scripts/plan-content-pack-v2-migration.sh /tmp/my-pack --json
./scripts/validate-content-pack.sh examples/packs/hello-workday --json
./scripts/preview-content-pack.sh examples/packs/hello-workday
./scripts/edit-content-pack-projection.sh /tmp/my-pack --asset my-video
python3 scripts/apply-content-pack-projection.py /tmp/my-pack my-video.projection.json --check --json
./scripts/author-content-pack-experience.sh /tmp/my-pack --id ritual.shared-win --kind ritual --trigger taskCompleted --step my-video:react --check --json
./scripts/audit-content-pack.sh examples/packs/hello-workday --json
./scripts/audit-content-pack-locales.sh examples/packs/hello-workday --locale zh-CN --locale en-US --json
./scripts/build-content-pack-archive.sh /tmp/my-pack /tmp/my-pack.chengyinpack --json
./scripts/audit-content-pack-archive.sh /tmp/my-pack.chengyinpack --json
python3 scripts/audit-community-pack-index.py community/index.json --json
```

Draft creation uses a sibling staging directory and atomic publication. An
existing destination, duplicate locale, invalid identifier or injected write
failure neither overwrites content nor keeps a partial draft. Its machine
receipt contains no local path, keeps `rightsInferred=false` and
`pending-creator-evidence`, and supports up to 32 valid locale tags without
claiming native-language review.

The locale-matrix command is offline, read-only, and performs no media decode.
It reuses runtime matching to report media eligibility separately from the
locale actually selected for accessibility fallback. JSON contains locale keys
and counts—not dialogue, descriptions, or machine paths—and
`PASS_WITH_WARNINGS` still requires human review of the listed gaps.

Validation includes structural safety plus system first-frame and audio-track checks and never calls an external generation provider. Preview first performs the same validation, then writes a local HTML video/audio/image catalog without remote scripts, fonts, or analytics. Every video shows the pet, stage, and fullscreen crops calculated by the same projection contract as the app, and labels whether the crop came from a modern key, a v1 alias, or a safe default. Dynamic tracks also show a script-free start/middle/end storyboard and dashed safe-area envelope. The preview must live outside the pack so it cannot contaminate later validation.

The separate interactive projection editor is also fully offline. It adjusts
time-addressed focal points and safe areas for Pet, Stage and Fullscreen, then
exports a versioned JSON receipt without local paths. The transactional
applicator validates first, keeps a sibling backup, writes atomically, validates
again, and restores the original manifest on failure; browser code and temporary
editor files never enter the pack.

The experience author uses the same transaction boundary to create or
explicitly replace v2 multi-video sequences. Run `--check` for a no-write
receipt, then omit it for an atomic update. Duplicate IDs, non-video assets and
out-of-bounds steps are rejected with stable codes; failed post-validation
restores the original manifest byte for byte. The tool never infers media rights
or claims real-playback health.

The audit adds quality feedback for crop anchors, native audio, tags, locale, story beats, and license placeholders. `READY_FOR_LAB` only means the pack may enter local playback; it does not claim runtime Stable or signed Verified status. See the [Content Pack threat model](docs/CONTENT-PACK-THREAT-MODEL.md).

## Default care cadence

- Hydration: randomized every 45–70 minutes.
- Walk and stretch: randomized every 80–110 minutes.
- Praise and light flirting: randomized every 35–65 minutes, at most four times per day.
- Quiet hours: 23:30–08:30, with at most one wrap-up after 23:15.
- Care pauses while the user is away for more than ten minutes.
- Codex task completion: immediate, queued during bursts, with at most four pending.

All timing uses jitter and avoids immediately repeating the same line. Lifestyle care, light flirting, pet names, and Codex completion celebrations can be disabled independently.

## Build

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

The application bundle is written to:

```text
dist/Chengyin Companion.app
```

To replace the app in `/Applications` and relaunch it:

```bash
chmod +x scripts/install-local-app.sh
./scripts/install-local-app.sh
```

The installer first creates and verifies a new app carrying the source fingerprint, quits only the exact old process, atomically exchanges the apps inside `/Applications`, retains the previous app in `dist/install-backups/`, relaunches, and verifies the new build. Preferences, relationship memory, and installed packs live outside the bundle and are checked for unchanged state.

To inspect what would happen without quitting or replacing the current app:

```bash
./scripts/install-local-app.sh --dry-run
```

`--dry-run` still refreshes the reproducible `dist` candidate but does not modify `/Applications` or the running process. `./scripts/doctor.sh` separately reports source, `dist`, installed, and running identities and recommends the installer when the live app is stale. `python3 scripts/audit-local-runtime-identity.py --json` emits the same layered machine receipt without a PID, username, or absolute path, and keeps “current preview works” distinct from “installed copy is current.” See [Local build, update, and rollback](docs/LOCAL-UPDATE.md).

To verify the real interface instead of relying on visual memory, first run one current app and then execute:

```bash
python3 scripts/audit-direct-play-runtime.py
```

It actually clicks the pet, opens the non-scrolling magic-wand palette, selects a bundled video, completes five catches, and proves both stage/large reward restoration to the pet. The receipt contains no local path. Because this command moves the live window and plays native audio, it is an explicit local acceptance gate rather than an automatic headless CI step.

To prove that none of the six mini-games can report a text- or audio-only false
completion, run:

```bash
python3 scripts/audit-all-game-rewards.py
```

It completes Catch Me, Hide-and-Seek, Action Combo, Heart Trace, Heartbeat
Rhythm, and Treat Time in sequence. Every game must show a fullscreen-scale
reward video and then restore the pre-game pet before one path-safe JSON receipt
passes. A production receipt is fixed to `proofKind=LIVE_LOCAL_GUI`; the CI
rejection matrix explicitly identifies itself as simulated contract fixtures
and cannot impersonate a real GUI pass. Its schema is
`Schemas/all-game-rewards-v1.schema.json`. This local acceptance gate uses
bundled media only: it does not access the network, call Seedance, or install
the app.

## Regenerating the Volcengine voice pack

The project and app never store provider credentials. To regenerate locally, set `VOLCENGINE_TTS2_APP_ID`, `VOLCENGINE_TTS2_ACCESS_TOKEN`, and `VOLCENGINE_TTS2_RESOURCE_ID=seed-tts-2.0`, then run:

```bash
python3 -m pip install doubao-speech
python3 scripts/generate-tts2-pack.py
```

## Current boundaries

- No text or voice chat. Character speech comes from Seedance-native audio and pre-generated Volcengine prompts.
- Fullscreen has no input box, chat history, or microphone. Idle mode shows status and interaction entry points; video playback shows only the picture.
- Task completion uses Seedance 2.0 Mini 720p/24 fps native audiovisual clips—completion orb, clap, turn, wave, and kiss—with synchronized line and lips.
- Pet idle, stage/fullscreen idle, nine manual interactions, and all fantasy scenes use moving `.mov` assets, never action stills.
- Pet idle loops shared landscape videos silently. Direct native audiovisual scenes expand and use their embedded AAC audio.
- All nine manual actions contain Seedance-generated line, lip sync, motion, laughter/landing effects, and ambience. Audio-only mode retains pre-generated TTS.
- Drag feedback uses an independent Seed-TTS 2.0 short-line player so it cannot cut off task or care audio; higher-priority task events wait until the gesture line ends.
- “Catch Me” changes position and voice per hit, tracks combo, and reuses a current celebration rather than spending online generation quota.
- “Edge Hide-and-Seek” avoids the same edge twice, speaks on discovery, disables drag during play, and restores position and presentation afterward.
- “Action Combo” recognizes tap, hold, and fast fling in order, resets immediately on error, and reuses an existing native audiovisual reward.
- “Heart Trace” requires continuous traversal of nine nodes with segmented haptic/voice feedback and reuses an existing heart video.
- “Heartbeat Rhythm” uses a separate effects player so beat audio does not interrupt speech; beat taps bypass double-click delay for immediate scoring.
- “Treat Time” expands to landscape stage, uses a magnetic target, and provides independent success, miss, timeout, and victory feedback.
- Pet reactions exclude the current asset and six recent responses and persist bounded short-term anti-repetition memory. Pointer interactions can be paused.
- Temporary expansion never overwrites the saved presentation, including if the app exits during playback.
- Hydration, movement, response-ready, morning/evening, and failure comfort currently combine pre-generated TTS with muted motion clips rather than falsely labeling them as native audiovisual scenes.
- Fantasy scenes use Seedance 2.0 Mini’s “master video + video input” path. Masters stay in private TOS objects; short-lived signed URLs are reused but neither public nor stored.
- Measured Mini usage for 720p, four-second, video-input native-audio generation is 173,700 tokens per clip, deducted 1:1 from the Mini package.
- Lunar orbit, underwater glass room, time-frozen café, rainy-night portal, task celebrations, and all nine manual actions passed native-audio and automatic-transcription QA.
- The character is an independent adult fictional persona and does not directly copy or sexualize an identifiable real person from a reference attachment.
- Early multi-persona calibration remains private production evidence. Starter stays focused on one original adult fictional persona and does not include experimental media without approved rights.
