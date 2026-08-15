# Core and App module boundary contract

[简体中文](CORE-MODULE-BOUNDARY.zh-Hans.md) · English

This contract lets contributors understand and verify Chengyin decisions without
starting windows, players, networks, or system services. `CompanionContracts`
owns deterministic policy. `CompanionApp` reads system facts, calls Core, and
performs presentation side effects. Dependency direction is App → Core only.

## Current boundary

Core contains stable rules for events, shared workdays, attention budgets,
experience arbitration, chemistry-based direct interaction selection,
lifestyle-care scheduling, direct-play expansion/return planning, relationship state, window
layout, media projection, low-impact mode, microgame progress, backup formats, and runtime health.
Content Pack media selection and localized accessibility copy also share
`CompanionLocaleResolutionPolicy`: exact tags win, matching scripts outrank a
generic language, a generic language outranks a conflicting region, and
malformed or oversized runtime tags are rejected within a bounded candidate set.
The path-free projection-authoring receipt is also Core-owned, so browser UI,
the transactional applicator, tests and future creator front ends share one
versioned focal-track and safe-area handoff rather than private shapes.
`CompanionLifestyleScheduler` has moved out of App. Reminder kinds, quiet hours,
activity state, scheduling context, policy, and decisions are now explicit
cross-module types. Its current source line count comes from the audit receipt's
`requiredPolicyLines`, rather than a number copied into this document.
`CompanionLifestyleMemoryV1` and its store now own the privacy-minimal care
snapshot, bounded recovery, one rollback copy, legacy projection and explicit
deletion semantics. A focused App adapter performs UserDefaults orchestration;
the view model no longer owns seven independent care-memory fields. A focused
runtime coordinator now also owns session warm-up, away/return recovery,
cadence policy binding and delivery recording, while a separate presentation
mapper owns localized status copy. The view model supplies bounded activity
facts and performs only the returned media side effect.
A focused content-operations coordinator similarly owns MainActor progress,
security-scoped backup access, recoverable-removal receipts and localized,
path-free failures. The transactional content-library actor remains the only
filesystem mutation boundary; the view model only applies returned inventory.
Data-only operation kinds, success projections and recovery receipts live in a
separate focused model file, so adding a result shape cannot silently enlarge
the side-effect coordinator.
`CompanionWorkdayStateV1` follows the same explicit recovery boundary. Its load
receipt distinguishes primary, rollback-copy and safe-default recovery, while a
focused App adapter keeps task presentation live if persistence fails and reports
a stable path-free error instead of exposing a local storage failure.
`CompanionWorkdaySignalTrustPolicy` owns the exact producer/version allowlist
and fail-closed terminal projection. Only the bundled `terminal-events-v1`
emitter may celebrate successful completion; App Server retains only documented
failure/interruption, while unregistered terminal claims become response-ready.
`CompanionEventIngress` separately owns bounded envelope decoding, opaque task
reference sanitization and trust-policy delegation without filesystem, process or
network capability. `CompanionEventWatcher` is consequently transport-only: it
owns the local inbox scan, restart baseline, deduplication and bridge health.
`CompanionWorkdayExperiencePolicy` owns the content-free visual, mood, status,
declarative content-cue, event and relationship-reward plan. Passive progress,
cancellation and integration status cannot overwrite direct play, a microgame or
foreground media; progress heartbeats never become media cues. Task start,
long-running and cancellation cues share the session attention budget and may
select version-gated Content Pack media. Focused App mappers own localization,
stable event-trigger aliases and concrete UI types. The side-effect-free
`CompanionWorkdayApplicationProjection` is the sole semantic-to-executable
gate: a response-ready, failure or malformed non-terminal plan cannot create a
completed visual or relationship reward. The workday application projection has a separate 140-line review budget and cannot own persistence, media,
speech, windows, processes or network access.
The chemistry director is also Core-owned: App injects hour, relationship tone,
chemistry level, mood and bounded recent keys, then maps the returned opaque
moment to presentation media.
`CompanionUserPresentationPolicy` also makes direct-play window behavior
explicit: pet and magic-wand play temporarily open the stage, game rewards open
fullscreen, and audio-only mode never changes window state. The App migrates
the old ambiguous one-click audio-only preference once, and the wand uses a
bounded upward palette instead of a screen-edge scrolling menu.
`CompanionPlayPaletteLayout` is the shared adaptive geometry source for both
the AppKit window and SwiftUI controls. A full canvas keeps three labeled
columns; constrained canvases hide only explanatory copy, compact the picker
and footer, and reduce to two or one column when required. Every action remains
reachable without a `ScrollView`, while invalid display facts use the same safe
fallback as window placement.
`CompanionPresentationSession` owns the temporary return mode and its owner.
Rapid play therefore preserves the first click's origin, pack-authored return
policies cannot strand direct play onscreen, and a failed generated clip hands
off to its local fallback without shrinking and reopening the window.
`CompanionPresentationLifecycle` applies that ownership through one directive
path for pet clicks, the magic-wand palette, all six game rewards, automatic
care/task cues and content-pack return policies. The App performs the returned
window change but no longer rebuilds those transition rules per entry.
A focused experience runtime owns the one attention director, generation-safe
presentation lifetime, pending terminal queue and delayed fallback handoff.
Trusted terminal visuals replace lower-priority queue entries, expand within a
bounded terminal reserve and expose explicit coalescing instead of disappearing;
an old timer or failed clip cannot finish or replace a newer user action. Direct
pet and palette play also start a bounded 45-second attention grace: scheduled
care and time checks wait for the next evaluation, response-ready stays ambient,
and trusted task terminals remain reliable.
A focused workday runtime owns the privacy-minimal daily snapshot, local event
bridge polling, trust-policy projection and completion-reply lifetime. Polling
restart cannot replay a consumed boundary, a disabled announcement stays
consumed without becoming a later celebration, and an old reply timer cannot
close a newer completion response window.
`CompanionTaskCompletionPolicy` owns the task-completion tier, recovery copy
intent, relationship-tone ceiling and all four direct gesture replies. It emits
only bounded relationship keys, positive reward amounts and semantic beats; it
never receives task text or performs persistence. A side-effect-free App
projection localizes the completion line and maps the beat to an action before
the composition root records or plays it.
`CompanionPetDragPolicy` owns completed-drag classification, priority, bounded
pose geometry, restoration timing and opaque relationship keys for fling, dock,
lift, nudge and settle feedback. It normalizes non-finite and extreme pointer
values before calculation. A side-effect-free App projection maps the semantic
plan to localized copy, mood, symbol and existing audio cue; the composition
root performs the effect once.
`CompanionPlaybackHealthAccumulator` owns opaque attempt tokens, exactly-once
terminal accounting, bounded first-frame samples and the 500 ms target status.
The App contributes only monotonic timing from a real visible-frame signal; it
does not pass media URLs, asset IDs or pack identity into diagnostics.
`CompanionRuntimeReadiness` now also owns the strict split between safe local
recovery and manual attention. Only event-directory permission repair and
interrupted content-library transaction recovery can run automatically. Missing
app/media identity, an unexpected file or symlink, and privacy declarations stay
visible for a person to resolve; recovery never replaces the app, deletes media,
changes preferences, or uses the network.
`CompanionPresentationEnvironment` owns transparent/cinematic/dim accessibility
resolution and current/main/specific display selection. AppKit contributes only
bounded display identifiers and visible frames; disconnected targets recover
deterministically without persisting human-readable display names.
`CompanionMicrogameSession` owns the content-free rules for the six built-in
microgames: one active game, bounded timers, catch/hide streaks, ordered combo
gestures, heart-trace tolerance, rhythm hit windows and feed completion. AppKit
still owns windows, audio and haptics. A focused App runtime owns the one
cancellable countdown/rhythm timeline and exact pre-game return context; ending
a game discards all session progress, so play adds no streak, behavioural profile
or hidden persistence. `CompanionMicrogameWindowPolicy` separately receives the
selected display frame, decorated pet size, pointer location and opaque entropy.
It keeps catch targets reachable, preserves a clickable peek strip, rejects an
immediate hide-edge repeat and recovers malformed geometry without reading the
global screen or pointer. AppKit only applies the returned origin.
`CompanionMicrogameCompletionPolicy` separately maps every
win or ending to a debt-free semantic plan: six distinct positive mementos and
reward beats on success, no penalty or relationship mutation on failure, exact
return timing, and no media or platform dependency. A focused App projection
localizes that plan and applies the user's relationship-tone ceiling before the
composition root performs audiovisual side effects.

Core may import only `Foundation` and `CoreGraphics`. It must not directly depend
on SwiftUI, AppKit, AVFoundation, WebKit, Network, process execution, browsers,
or work content. It receives bounded dates, booleans, counts, and enums and
returns testable decisions. It does not read task titles, prompts, code, paths,
or user-authored text.

## Machine gates

Run the baseline audit:

```bash
python3 scripts/audit-core-module-boundaries.py --json
```

Run the compiler-parser boundary audit. It asks the selected local `swiftc` to
emit syntax trees for every Swift source in the four reviewed targets, then
checks the emitted imports and 27 required public Core declarations. It does
not type-check or execute repository source:

```bash
python3 scripts/audit-swift-compiler-boundaries.py --json
./scripts/run-swift-compiler-boundary-smoke.sh
```

Run the complete positive and negative matrix covering policy leakage into App, platform
dependencies, missing lifestyle, locale-resolution, workday-experience, chemistry, user-presentation, media-projection,
presentation-session/lifecycle recovery, playback-health bounds, bounded runtime recovery,
care/workday-memory recovery, projection-authoring, pet-drag, microgame and presentation-environment public types,
a settings-surface merge, content-pack contract re-merging, content-operation re-merging,
microgame-runtime re-merging, experience-runtime re-merging, workday-runtime re-merging,
focused-module growth, composition growth,
and a broken package dependency:

```bash
./scripts/run-core-module-boundary-smoke.sh
```

Verify that care scheduling and other Core behavior remains unchanged:

```bash
./scripts/run-core-policy-smokes.sh
```

Run stable Core codecs, migration, deletion, recovery, and decision matrices:

```bash
swift run --disable-sandbox CompanionContractChecks
```

Receipts contain no user name or absolute path. Failures use stable
`CORE_BOUNDARY_*` codes and provide a recovery action to move policy, remove a
side effect, or split a file.

## Anti-regression budgets

`CompanionViewModel.swift`, `ContentView.swift`, `CompanionSettingsView.swift`,
and the content-pack validator are migration surfaces, not default homes for new
policy. After extracting interaction policy, playback controls, settings models,
the dedicated video-player binding, presentation preferences/surface, and focused
window/settings modules, care-memory persistence, presentation-session ownership,
focused sequence playback, shared-workday persistence, support diagnostics, and
the AppKit pet-gesture bridge, deterministic microgame session, shared-workday
presentation mapping, the focused lifestyle runtime/presentation mapping, and
the focused media/fallback ladder, content transaction coordination and the
exclusive microgame runtime, side-effect-free microgame HUD/state projection,
debt-free microgame completion policy and localized reward projection, pure
task-completion/reply policy and localized projection, bounded pet-drag policy
and localized value projection,
generation-safe experience runtime, coordinated workday runtime, the bounded
shared care/work lifecycle, the unified
presentation lifecycle, and bounded relationship-memory/feedback/cooldown/playback
coordination, plus the focused completion/presence/relationship/surprise overlay
module, restart-safe gesture discovery coordinator, unified presentation runtime, generation-safe pet feedback runtime, stale-safe content library runtime, typed preference migration/repair store, capability-free settings backup projection, bounded voice selection runtime, deterministic microgame window placement, focused content-sequence session and completion-safe workday application projection, their frozen baseline ceilings are 3576/5600, 1269/3000,
525/900, and 311/420. The executable audit
receipt is the only current line-count source: it reports each file's live count,
delta, remaining capacity and saturation. A passing budget still does not prove
completed modularization. Version baselines freeze 3576, 1269, 525, and 311, so future
additions must stay at or below those ceilings until a reviewed baseline reduction.
The audit also rejects merging `SettingsView`, the action/scene/idle/sprite media
ladder, or the status-overlay views back into `ContentView.swift`. The focused
status-overlay module has a 280-line review budget and cannot own window
transitions, scheduling, persistence or media selection.
The gesture discovery coordinator has a 140-line review budget. It owns only
opaque learned-capability IDs, local persistence and cancellable hint timing;
pointer coordinates, windows, media, task content, speech and network access stay outside it.
The presentation runtime has a 120-line review budget and is the only App owner
of the mutable Core expansion/return lifecycle. It receives semantic modes and
intent only; windows, playback, timers, speech, persistence and task content stay outside it.
The pet feedback runtime has a 180-line review budget and is the only owner of
the cancellable mood, pose and effect reset lifetimes. Every overlapping reset
is generation-guarded so stale hover, drag or effect callbacks cannot overwrite
a newer interaction. It owns no windows, media, speech, persistence, filesystem,
private task content, process or network capability; the ViewModel only binds
observable state and applies semantic interaction decisions.
The content library runtime has a 300-line review budget and owns only the
latest immutable installed inventory, derived catalog/quality summaries,
safe-mode projection and cancellable recovery/playback-validation lifetimes.
Generation tokens reject stale recovery and first-play callbacks after a newer
install, rollback, explicit retry or safe-mode change. It cannot read or mutate
the filesystem and owns no windows, media decoder, speech, user defaults,
clipboard, process or network capability; disk authority remains in the
actor-backed content library and its transaction coordinators.
The preference store has a 420-line review budget and is the only owner of the
local UserDefaults schema, typed clean-install defaults, one-way playback
selection migration, malformed-value repair and retired conversation-key
cleanup. Its load receipt counts repaired fields separately from privacy-key
removals, preserves unknown future contract versions and exposes no UI, media,
window, task-content, filesystem, process or network capability. First-session
profile detection remains before preference loading, and portable restore still
applies through ViewModel setters so runtime side effects remain explicit.
The settings backup projection has a 240-line review budget and is the sole
owner of preference-to-contract export plus compatibility repair planning.
Unsupported persona or sound state, locale-following behavior, retired sharing
prompts, invalid display targets, reduced-dynamic playback and tone-gated
preferences produce a stable ordered repair receipt instead of being silently
invented or applied. It owns no UI, localization, persistence, media, filesystem,
window, task, process or network capability; the App layer applies the plan and
presents the localized adjustment count after a confirmed restore.
The voice selection runtime has a 140-line review budget. It receives an
already-loaded library and owns only two bounded session histories, exact-ID
preference filtering and the 320ms interaction cue cooldown. General and
gesture feedback histories remain separate, addressed lines stay opt-in, and
fresh candidates are exhausted before reuse. It cannot load bundles or own
AVFoundation playback, speaking state, UI copy, persistence, filesystem,
windows, tasks, processes or network access; the ViewModel applies the returned
semantic selection and presents stable missing-audio recovery copy.
The content-sequence runtime has a 140-line review budget. It is the only owner
of the keyed asset-selection cache, active declarative sequence and its fallback
intent. Replaced, stale and duplicate terminal callbacks are rejected there;
filesystem access, media decode, speech, windows, persistence and network remain
outside it. This real state-ownership extraction lowered and re-froze the
ViewModel baseline at 3,631 lines.
It rejects merging manifest models, public-safe failure receipts, semantic-version
parsing, raw JSON shape checks, contribution policy or asset/filesystem safety
back into the orchestration surface. The raw field validator has a 240-line
review budget. Contribution validation is split into a 100-line dispatcher,
180-line shared-field support, 240-line rights policy, 240-line accessibility
policy and 80-line fallback policy. Asset validation is further split into an
80-line stable dispatcher, 140-line
no-follow package enumerator, 140-line per-asset file/hash authenticator and
220-line value-only media/projection policy. Contribution and projection
components remain value-only; only package enumeration and asset-file
authentication may read the package filesystem, and only the latter may hash
declared media. Their contract/failure/SemVer
files retain reviewable absolute budgets of 700, 700, and 120 lines. The workday localization
mapper and media presentation ladder are focused App modules with 180- and
600-line review budgets. Event copy, event-trigger routing and trigger compatibility
are separate focused modules with 100-, 80- and 100-line budgets. The lifestyle
runtime coordinator, localized status mapper and shared-day composition root
have 320-, 200- and 220-line budgets. The shared-day root owns only cancellable
clocks and semantic receipts; it cannot own media, speech, windows or private
task content. None of these responsibilities may be merged back into the view
model.
The relationship runtime coordinator and its content-selection adapter have
280- and 80-line review budgets. They own only bounded local relationship state,
feedback/cooldown scheduling and opaque playback anti-repetition; task text,
filesystem paths, windows, speech and network access remain outside this boundary.
The content-pack transaction actor, stable storage facade, private-directory
layout, validated active-record repository, lexical lock coordinator, read-only
install preflight, lock-scoped install transactions, lock-scoped recovery
transactions, playback-health transitions, one-lock snapshot projection, focused
maintenance transactions, data/error/authorization contracts and local durability
primitives have 300-, 120-, 80-, 110-, 60-, 140-, 180-, 180-, 140-, 120-,
120-, 220- and 140-line review budgets. The actor remains the sole serialized entry point. The install
component owns staging, final revalidation, immutable-version commit, activation
and pre-activation rollback; stage, commit and discard each require an unforgeable
lock scope, while media decoding stays outside it. The recovery
component owns synchronous removal, restore, purge and batch rollback, but every
entry requires an unforgeable scope created only inside the lock-coordinator closure;
it cannot acquire a lock, await or be constructed by another App source. The
preflight owns manifest, authorization, downgrade and exact-revision inspection but
cannot lock or mutate.
Explicit version rollback and abandoned-staging cleanup live in the maintenance
component. Both require the same unforgeable lock scope; cleanup can enumerate
only the staging root and remove only expired direct-child `.staging` directories.
Directory layout, active-record validation/installed-pack projection and lexical
locking stay in separate focused components behind the stable repository facade.
The lock coordinator's synchronous closure makes awaiting media decode while holding
the process lock structurally impossible: install probes outside the lock, then
relocks and revalidates before committing. Models remain side-effect free; only the
durability adapter may own exact private temporary files and `fsync + rename`
active-pointer publication.
The media-kind router, focused video probe, focused non-video probe and bounded
media-quality probe have 180-, 220-, 160- and 180-line review budgets. The
router owns only dispatch and stable error projection. The video probe owns
video extension, codec, declared metadata and first-frame checks; audio, image
and declarative validation remain in the non-video probe. The quality probe owns only sub-second decoded-sample windows
at midpoint/tail and a 250ms audio/video timeline envelope; it cannot own UI,
network, process, storage, hashing or runtime playback state. These checks detect
grossly damaged checkpoints and timeline drift, not subjective lip-sync quality,
loudness or a seamless loop.
Immutable playback/sequence/cursor models, installed-pack manifest projection
and pure runtime selection policy are separate focused files with 200-, 180-
and 400-line budgets. Selection delegates locale ranking to the bounded shared
Core policy and owns cooldown, recent-exclusion and weighted choice but no
installed-pack construction or playback side effects. The bounded localized
media-accessibility resolver and SwiftUI accessibility projection have 240- and
120-line budgets. Validated
alt text, captions and sound descriptions must not be discarded or reimplemented
inside `ContentView`.
The `.chengyinpack` ZIP policy, private-staging importer, AppKit picker and
content-library boundary have 520-, 360-, 100- and 180-line budgets. Archive
parsing must remain write-free; process invocation and post-extraction checks
must stay in the importer, while Settings only chooses a source. This extraction
reduced `CompanionSettingsView` below its frozen baseline instead of increasing
the composition ceiling.
The data-only content-operation models, shared path-safe receipt factory,
portable-backup coordinator and content-pack MainActor coordinator have 100-,
120-, 220- and 360-line review budgets. Backup export/preflight/confirmed restore
may not be merged back into content-pack coordination; shared error projection
may not be duplicated into either stateful coordinator. Transaction state,
security-scoped access or recoverable-removal receipts may not return to the view model.
The recovery catalog and its focused Settings section have 260- and 180-line
review budgets. Restore/purge must stay behind opaque IDs, one-child resolution,
bounded enumeration and explicit destructive confirmation; filesystem URLs may
not enter the view model or Settings projection.
The microgame runtime coordinator has a 300-line review budget. The boundary
rejects bringing six timer tasks, mutable Core progress or per-game return-mode
fields back into the view model.
The localized microgame presentation projection has a 220-line review budget.
It may read the ephemeral Core session and expose computed HUD/view state, but it
may not own timers, audio, haptics, windows, preferences or runtime coordination;
the boundary also rejects merging that HUD mapping back into the view model.
The localized completion projection has a separate 260-line review budget. It
may map the Core completion plan to copy, mood, a relationship-capped reward and
an end cue, but may not own runtime, persistence, audio, haptics or windows. The
boundary rejects duplicating completion copy or relationship reward IDs in the
view model.
The task-completion presentation projection has a separate 180-line budget. It
may localize Core copy intents and map semantic reward beats, but cannot own the
reply timer, relationship persistence, task content, audio, windows or haptics.
The boundary rejects rebuilding tier/action/copy/reply switches in the view model.
The pet-drag presentation projection has a separate 140-line budget. It may map
the Core feedback plan into localized text, mood, symbol and an existing cue,
but it cannot own thresholds, persistence, haptics, windows, playback or tasks.
The boundary rejects rebuilding fling/dock/lift/nudge/settle classification in
the view model.
The privacy-minimal runtime support collector, cancellable safe-repair
coordinator and read-only Settings projection have 260-, 220- and 100-line
review budgets. Repair state, event-bridge repair and interrupted content
transaction recovery may not return to the view model. The repair coordinator
may not access AppKit, preferences, networking, process launch or destructive
filesystem APIs; the presentation projection may not start tasks or repairs.
The experience runtime coordinator has a 340-line review budget. The boundary
rejects returning the attention director, raw presentation task or pending-event
array to the view model. It also keeps the timestamp-only post-user-interaction
grace out of gesture and presentation code; its source gate complements, but
does not replace, the timer/queue behavior smoke.
The workday runtime coordinator has a 300-line review budget. The boundary
rejects returning event-bridge polling, adapter ownership, trust projection or
reply-window tasks to the view model; the real local-event smoke remains required.
The capability-free event ingress and transport-only watcher have 180- and
300-line review budgets. The gate rejects missing ingress, privacy projection
merged back into the watcher, filesystem/process/network capability in ingress,
or a watcher that bypasses the focused extractor. These source checks complement,
but do not replace, the real local-event and restart-deduplication smokes.
Baselines should decrease monotonically after real extraction. A Core file
is limited to 900 lines so a giant App file cannot simply become a giant Core
file.

Line counts cannot prove good design. The source audit also checks file location,
one-way package dependency, allowed imports, side-effect APIs, focused settings
location, and the lifestyle/chemistry/pet-drag/microgame/user-presentation/presentation-session/playback-health/runtime-readiness/media-projection/projection-authoring/presentation-environment public
surfaces. That audit remains a source regex/token regression gate: its local
package-dependency assertion uses a bounded source window and public types use
declaration string matching. A separate network-disabled
`chengyin.swiftpm-package-graph/v1` gate asks SwiftPM to evaluate the manifest in
its default manifest sandbox, with network credentials and dependency updates disabled, and
then freezes the four products, four targets, zero external packages, one-way
Core edges, source roots, App resource rule, tools version, default locale and
macOS boundary. A third `chengyin.swift-compiler-boundaries/v1` gate now invokes
the local Swift compiler in `-frontend -dump-parse` mode for every regular Swift
source and validates compiler-emitted import nodes plus required public Core
declarations. Together these gates are stronger than source matching alone, but
the parser projection is not a type-checked dependency graph, does not expand
this claim into a general sandbox, and does not prove runtime behavior. A
SwiftSyntax semantic audit, compiler type-check dependency scan and continued
monotonic baseline reduction remain future hardening candidates. Passing does
not replace compilation, code review or behavior tests.

Manifest evaluation is not advertised as a general untrusted-repository scanner.
The gate uses SwiftPM's default manifest sandbox, isolated temporary scratch and
module caches, disabled credential stores, disabled dependency caching and no
automatic resolution. A malicious checkout or compromised toolchain still needs
OS-level isolation and human review; the receipt proves the reviewed local graph,
not arbitrary-code safety or package origin authenticity.

## Contribution flow

For a deterministic rule, start with a focused value type in
`CompanionContracts`, reduce system input to bounded facts, add normal, quiet,
busy, corrupt, duplicate, cancellation, and recovery tests, and only then bind
it from the view model. Media playback, window operations, UserDefaults
orchestration, system-event reads, and local file transactions remain App
adapters.

Changing an existing public scheduler type, trigger family, persisted field,
permission, or dependency direction requires migration and fallback under the
[compatibility policy](COMPATIBILITY.md), the [contributor architecture](CONTRIBUTOR-ARCHITECTURE.md),
and the [contribution guide](../CONTRIBUTING.md). A security fix may immediately
tighten unsafe input, but it must not silently rename stable error codes or leave
old data without an actionable recovery.

## Known follow-up migrations

This contract does not claim modularization is finished. App composition remains
large, while parts of feedback and media orchestration can still move. Each
migration must reduce or freeze App
complexity, preserve a built-in fallback, pass bilingual checks, and prove it
adds no network, microphone, account, commerce, advertising, or automatic share.
