# Chengyin contributor architecture

This is the short map for contributors. Product rationale and longer research
remain in the other documents; this file describes the code and its hard
boundaries as they exist today.

## Runtime flow

```text
explicit user gesture ───────────────┐
trusted Companion Event ─────────────┼─> ExperienceDirector
local lifestyle scheduler ───────────┤       │
ambient Codex response-ready signal ─┘       ├─ present / ambient / queue / defer
                                              v
                                  declarative content selector
                                   │                     │
                              v2 sequence            v1 video
                                   │                     │
                                   └──── AVFoundation ───┘
                                              │
                                   health / fallback / memory
```

`CompanionExperienceDirector` owns interruption precedence. UI code must not
invent a second queue or bypass it for companion-initiated care. Direct user
gestures remain immediate; trusted task-terminal events may wait for an active
interaction but may not disappear.

## Source ownership

| Area | Source | Responsibility |
| --- | --- | --- |
| Stable contracts | `Sources/CompanionContracts` | Privacy-minimal events, settings, workday, relationship and gesture-learning state, backup formats, pure directors |
| Lifestyle care policy | `CompanionLifestyleScheduler.swift` in `CompanionContracts` | Pure, injected-time scheduling for ten reminder families, quiet hours, activity suppression, cooldowns and bounded daily limits; no UI, persistence or system clock lookup |
| Lifestyle memory contract | `CompanionLifestyleMemory.swift` in `CompanionContracts` | Versioned privacy-minimal care snapshot, validation, one-copy rollback recovery, legacy projection and deletion semantics; no task text, prompts or local paths |
| Lifestyle memory adapter | `CompanionLifestyleMemoryAdapter.swift` in `CompanionApp` | Focused MainActor/UserDefaults bridge; surfaces stable recovery identity and errors without leaking raw persistence into the view model |
| Lifestyle runtime coordination | `CompanionLifestyleRuntimeCoordinator.swift` + `CompanionLifestyleEventProjection.swift` + `CompanionLifestylePresentation.swift` in `CompanionApp` | Owns session warm-up, away/return recovery, cadence binding and persistence receipts; semantic event/voice-line projection is isolated from localized outcome copy, while the view model contributes bounded activity facts and executes the selected media only |
| Content operation models and receipts | `CompanionContentOperationModels.swift` + `CompanionContentOperationReceiptFactory.swift` in `CompanionApp` | Data-only operation values plus one shared path-safe localized receipt projection; contains no filesystem, UI, progress state or actor side effects |
| Portable backup coordination | `CompanionBackupOperationsCoordinator.swift` in `CompanionApp` | Owns MainActor backup export, preflight preview, security-scoped access and confirmed restore without leaking pending URLs into the view model |
| Content operations coordination | `CompanionContentOperationsCoordinator.swift` in `CompanionApp` | Owns content-pack operation progress, immediate undo, cross-restart recovery and playback-health reporting; delegates backup lifecycle to its focused coordinator and every filesystem mutation to the transactional library actor |
| Content-pack transaction store | `ContentPackStore.swift` + `ContentPackStoreRepository.swift` + `ContentPackStoreLayout.swift` + `ContentPackActiveRecordRepository.swift` + `ContentPackStoreLockCoordinator.swift` + `ContentPackInstallPreflight.swift` + `ContentPackInstallTransactions.swift` + `ContentPackRecoveryTransactions.swift` + `ContentPackPlaybackHealthTransactions.swift` + `ContentPackStoreSnapshotProjection.swift` + `ContentPackStoreMaintenanceTransactions.swift` + `ContentPackStoreModels.swift` + `ContentPackStoreDurability.swift` in `CompanionApp` | Keeps one actor as the sole serialized entry point and one small repository as its stable storage facade. Directory topology/0700 permissions, validated `active.json` persistence/installed-pack projection, and lexical cross-process locking live in three separate focused components; only the lock coordinator can construct the unforgeable lock scope. Manifest, authorization, downgrade and exact-revision inspection stays in a read-only preflight. Staging, final revalidation, immutable-version commit, activation rollback, removal/recovery, playback-health, explicit rollback and verified abandoned-staging cleanup remain separate synchronous capabilities whose mutation entry points require that scope. Active plus recovery inventory is projected together under the same scope, while the durability adapter is limited to the underlying lock plus exact-private-temp `fsync + rename` publication. Install cleanup can remove only direct-child `.staging` directories or a newly committed version before activation; media decode runs outside the lock and the staged candidate is revalidated before commit. None owns UI, network, account or provider access |
| Content recovery boundary | `ContentPackRecoveryCatalog.swift` + `CompanionContentPackRecoverySection.swift` in `CompanionApp` | Enumerates one bounded private recovery level without following links, exposes opaque IDs instead of paths, revalidates before restore and requires confirmation before an exact-item purge |
| Shared-workday memory | `CompanionWorkdayState.swift` + `CompanionWorkDirector.swift` in `CompanionContracts` | Privacy-minimal daily counters, primary/backup/safe-default recovery receipt and pure task-lifecycle decisions; no task text, prompt, code or path fields |
| Shared-workday event trust | `CompanionWorkdaySignalTrustPolicy.swift` in `CompanionContracts` + `CompanionEventIngress.swift` and `CompanionEventWatcher.swift` in `CompanionApp` | Exact producer/version classification and fail-closed terminal projection live in Core; a capability-free ingress decodes/privacy-cleans bounded envelopes; the watcher owns only transport, restart baselining, deduplication and health |
| Shared-workday experience | `CompanionWorkdayExperiencePolicy.swift` in `CompanionContracts` + `CompanionWorkdayPresentation.swift`, `CompanionWorkdayApplicationProjection.swift`, `CompanionEventPresentation.swift` and `CompanionEventTriggerRouting.swift` in `CompanionApp` | Attention-safe visual/mood/status/content-cue/event plans, localized copy and stable pack-trigger aliases; one side-effect-free application projection is the only semantic-to-executable gate, strips completion visuals/rewards from non-terminal input, and keeps progress status-only |
| Task-completion interaction | `CompanionTaskCompletionPolicy.swift` in `CompanionContracts` + `CompanionTaskCompletionPresentation.swift` in `CompanionApp` | Pure tier/recovery/tone-capped celebration and four bounded gesture-reply plans; the projection localizes and maps semantic beats while timers, relationship persistence and audiovisual side effects remain outside |
| Shared-workday adapter | `CompanionWorkdayAdapter.swift` in `CompanionApp` | One coherent state/director/store bridge; keeps presentation live on persistence failure while exposing only stable issue-safe errors and recovery identity |
| Interaction chemistry policy | `CompanionChemistryInteractionDirector.swift` in `CompanionContracts` | Pure tone/level/daypart/mood candidate gating, deterministic weighted selection and bounded recent-moment avoidance; App owns only media mapping and persistence |
| Relationship runtime coordination | `CompanionRelationshipRuntimeCoordinator.swift` + `CompanionRelationshipContentSelection.swift` in `CompanionApp` | Owns the local relationship-memory session, bounded feedback queue, positive-moment cooldowns, opaque playback anti-repetition and explicit deletion cleanup; a tiny App-only adapter projects that memory into content selection, while the coordinator has no task text, prompts, filesystem paths, windows, speech or network access |
| Direct-play presentation policy | `CompanionUserPresentationPolicy.swift` in `CompanionContracts` | Pure audiovisual-aware stage/fullscreen/return planning for pet gestures, magic-wand actions and game rewards |
| Pet drag feedback policy | `CompanionPetDragPolicy.swift` in `CompanionContracts` + `CompanionPetDragPresentation.swift` in `CompanionApp` | Pure five-way release classification, bounded pose and restoration timing with malformed-pointer normalization; the side-effect-free projection localizes mood, symbol and cue while AppKit retains haptics, windows and playback |
| Experience runtime coordination | `CompanionExperienceRuntimeCoordinator.swift` in `CompanionApp` | Owns one attention director, a bounded post-user-interaction grace, generation-safe presentation token, bounded trusted-terminal queue, readiness replay and stale-fallback cancellation; contains no media, windows, speech, persistence or private task content |
| Shared-workday runtime coordination | `CompanionWorkdayRuntimeCoordinator.swift` in `CompanionApp` | Owns the privacy-minimal daily adapter, cancellable local-event polling, trust-policy projection and generation-safe completion-reply window; the view model executes only the sanitized application plan |
| Shared-day composition root | `CompanionSharedDayRuntimeCoordinator.swift` in `CompanionApp` | Starts and stops care evaluation plus trusted work polling as one local lifecycle, accepts only bounded activity/preferences facts and emits semantic receipts; media, speech, windows, relationship copy and private task content stay outside |
| Companion Event inbox | `CompanionEventSpool.swift` + `CompanionEventIngress.swift` + `CompanionEventWatcher.swift` in `CompanionApp` | Bounded descriptor-based no-follow inbox, isolated privacy projection, filename/content UUID binding, safe retention, restart-aware deduplication and live path-free bridge health; legacy session compatibility is opt-in and cannot promote a turn boundary to task completion |
| First-session journey | `CompanionFirstSession.swift` in `CompanionContracts` + focused runtime/coach/integration files in `CompanionApp` | Deterministic two-gesture → one-preference → simulated-work-arc flow; persists only contract version and the selected local rhythm, never task content, identity or analytics; existing users are not interrupted and replay remains explicit |
| Microgame session policy | `CompanionMicrogameSession.swift` in `CompanionContracts` | Content-free deterministic progress for six games: exclusive activation, bounded timers, streaks, gesture order, heart path, rhythm window and feed completion; App retains windows, media and haptics |
| Microgame window policy | `CompanionMicrogameWindowPolicy.swift` in `CompanionContracts` | Pure selected-display catch and hide geometry with pointer clearance, clickable peek extents, no immediate edge repeat, opaque injected entropy and malformed-input recovery; AppKit supplies bounded facts and applies only the returned origin |
| Microgame completion policy | `CompanionMicrogameCompletionPolicy.swift` in `CompanionContracts` + `CompanionMicrogameCompletionPresentation.swift` in `CompanionApp` | One debt-free semantic result for all six games: distinct positive mementos and reward beats on wins, no relationship mutation on endings, bounded return timing and a side-effect-free localized projection that respects the user's tone ceiling |
| Microgame runtime coordination | `CompanionMicrogameRuntimeCoordinator.swift` in `CompanionApp` | Owns one ephemeral observed Core session, one cancellable countdown/rhythm timeline and one exact return context; emits bounded beat/expiry callbacks while AppKit retains windows, audio and haptics |
| Presentation session | `CompanionPresentationSession.swift` in `CompanionContracts` | Pure ownership and recovery for temporary expansion; preserves rapid direct play across pack policies and hands media failure to a local fallback without window flicker |
| Presentation lifecycle | `CompanionPresentationLifecycle.swift` in `CompanionContracts` | One pure directive path for click, palette, game reward, automatic care/task and content-pack return behavior; App owns only window/media side effects |
| Playback health | `CompanionPlaybackHealth.swift` in `CompanionContracts` | Opaque exactly-once attempts, bounded first-frame samples, concurrency counts and P95 target status; no media identity, URL or work content |
| Runtime readiness | `CompanionRuntimeReadiness.swift` in `CompanionContracts` | Pure health evaluation and the closed set of safe recovery actions; missing identity/media and privacy anomalies always remain manual attention |
| Window policy | `CompanionWindowPolicy.swift` | Pure sizing, restore clamping and edge-docking rules shared by launch and drag handling; no AppKit window-server dependency |
| Window visibility adapter | `CompanionWindowVisibilityKeeper.swift` | AppKit panel cross-Space/full-screen overlay policy, unhide and screen-change repair plus a five-second main-queue reassertion; no media decode, implicit focus stealing, Accessibility automation or intentional-minimize override |
| Presentation environment | `CompanionPresentationEnvironment.swift` | Pure transparent/cinematic/dim accessibility resolution and deterministic current/main/specific display selection with disconnected-screen recovery |
| Display adapter | `CompanionDisplayCatalog.swift` | Ephemeral AppKit screen names and topology notifications; converts screens to bounded Core descriptors and never persists labels |
| Window settings | `CompanionWindowSettingsSection.swift` + `CompanionPresentationPreferences.swift` | Focused appearance/display UI plus safe additive persistence and portable-backup binding outside the large settings/view-model files |
| Preference persistence | `Sources/CompanionApp/CompanionPreferenceStore.swift` + `CompanionPresentationPreferences.swift` | Typed snapshot/load receipt, clean defaults, one-way migration, malformed-value repair, future-contract preservation and retired privacy-key cleanup; first-session detection remains before load and backup restore applies through ViewModel setters |
| Settings backup projection | `Sources/CompanionApp/CompanionSettingsBackupProjection.swift` | Capability-free preference export and restore planning with stable ordered receipts for unsupported persona/sound state, locale following, retired sharing prompts, invalid displays, low-impact playback and tone-gated preferences; App applies the plan and localizes the visible adjustment count |
| Voice selection runtime | `Sources/CompanionApp/CompanionVoiceSelectionRuntimeCoordinator.swift` | Injected-library selection with separate bounded general/interaction histories, addressed-line opt-in, preferred-ID filtering and a 320ms gesture cue cooldown; bundle loading, AVFoundation playback, UI copy and persistence stay outside |
| Media projection | `CompanionPresentationProjection.swift` | Pure pet/stage/fullscreen crop resolution, bounded dynamic focal interpolation, safe-area visibility, v1 aliases, edge containment and reduced-dynamic rendering gate |
| Projection authoring receipt | `CompanionProjectionAuthoring.swift` | Path-free versioned focal/safe-area handoff shared by the offline editor, transactional applicator and contract checks |
| App composition | `Sources/CompanionApp/CompanionViewModel.swift` | Main-actor orchestration and binding stable contracts to presentation |
| Primary presentation | `Sources/CompanionApp/ContentView.swift` | Companion stages and gesture bindings; it does not own AppKit gesture recognition, AVFoundation binding, settings, content-pack operations or play-control menus |
| Status overlays | `Sources/CompanionApp/CompanionStatusOverlays.swift` | Focused completion-reply, Codex-presence, relationship-receipt and guaranteed-surprise animations; owns no window transition, scheduler, persistence or media selection |
| Media presentation ladder | `Sources/CompanionApp/CompanionMediaPresentation.swift` | Pack asset → bundled video → offline sprite composition for action, scene, idle and pet media; no window transitions, content selection or persistence |
| Pet gesture bridge | `Sources/CompanionApp/CompanionPetInteractionSurface.swift` | Focused AppKit first-click, double-click, long-press, drag, fling and edge-docking adapter extracted from the primary presentation file |
| Gesture discovery runtime | `Sources/CompanionApp/CompanionGestureDiscoveryCoordinator.swift` | Restart-safe opaque learned-capability IDs and a cancellable one-time hint; receives no pointer coordinates, windows, media, task content, speech or network capability |
| Presentation runtime | `Sources/CompanionApp/CompanionPresentationRuntimeCoordinator.swift` | One semantic expansion/return session for pet clicks, magic-wand choices, pack fallback, automatic cues and game rewards; ViewModel applies directives but owns no mutable lifecycle policy |
| Pet feedback runtime | `Sources/CompanionApp/CompanionPetFeedbackRuntimeCoordinator.swift` | Generation-guarded cancellable mood, pose and effect lifetimes; owns no windows, media, speech, persistence, filesystem, task content or network capability |
| Content library runtime | `Sources/CompanionApp/CompanionContentLibraryRuntimeCoordinator.swift` | Latest immutable installed inventory, safe-mode projection, derived catalog/quality summaries and generation-safe recovery/playback-health lifetimes; disk transactions remain in the actor-backed content library |
| Content sequence runtime | `Sources/CompanionApp/CompanionContentSequenceRuntimeCoordinator.swift` | One session-local active declarative sequence, fallback intent and keyed asset-selection cache; rejects stale/duplicate terminal callbacks and owns no filesystem, decoder, speech, window, persistence or network capability |
| Video player binding | `Sources/CompanionApp/CompanionVideoPlayer.swift` | AVFoundation lifecycle, health callbacks and an opt-in 15 Hz focal observer used only by assets with a declared dynamic track |
| Playback coordinator | `CompanionPlaybackCoordinator.swift` | Real `isReadyForDisplay` first-frame timing, exactly-once AVFoundation teardown, four-asset local-only prewarm cache and privacy-minimal process health |
| Install-time media validation | `ContentPackMediaProbe.swift` + `ContentPackVideoMediaProbe.swift` + `ContentPackNonVideoMediaProbe.swift` + `ContentPackMediaQualityProbe.swift` + `ContentPackMediaCheckpointDecoder.swift` + `ContentPackVideoDecodeFallback.swift` | Separates media-kind routing, video format/codec/first-frame validation, focused audio/image/declarative validation, checkpoint selection plus the 250 ms timeline policy, synchronous sub-second AVAssetReader mechanics and the narrow external-decode protocol. The media router must delegate every kind and cannot reacquire video or non-video implementations. Runtime and creator tools keep AVFoundation as the primary validator. Only creator CLIs inside a detected Codex outer sandbox may implement the video fallback protocol through `content-pack-creator-media-fallback.swift` to perform a bounded full software decode with an allowlisted fixed FFmpeg installation when AVFoundation sample decode is denied; the receipt names that backend. The application never compiles this process adapter, and clean-Mac AVFoundation review remains a release gate |
| Sequence presentation | `CompanionContentSequenceView.swift` | Focused declarative step cursor, bounded selected-sequence prewarm, minimum-duration handling and stale callback rejection outside `ContentView.swift` |
| Play controls | `Sources/CompanionApp/CompanionPlayControls.swift` | Explicit audio/video selection and a four-tab, non-scrolling magic-wand palette anchored upward from screen-edge pet controls |
| Settings presentation | `Sources/CompanionApp/CompanionSettingsView.swift` | Local preferences, memory deletion confirmations, content-pack lifecycle, portable backup, health and privacy-minimal diagnostics UI |
| Support diagnostics | `CompanionRuntimeSupport.swift` + `CompanionSupportDiagnosticsSection.swift` | Immutable path-free health projection, focused playback/runtime UI and explicit separation of safe repair from manual recovery |
| Accessibility localization contract | `audit-accessibility-localization.py` + bilingual `Localizable.strings` | Freezes semantic copy and stable identifiers for critical controls, and prevents validated pack alt text/captions/sound descriptions from disconnecting before SwiftUI media semantics; source proof does not claim physical VoiceOver certification |
| Evaluated package graph | `audit-swiftpm-package-graph.py` | Uses network-disabled SwiftPM manifest evaluation to freeze products, targets, one-way Core dependencies, source roots and resources. SwiftPM's manifest sandbox remains enabled normally; only a detected nested-sandbox denial inside an existing Codex sandbox retries without the nested layer and records that weaker proof explicitly. This complements rather than upgrades the source-token gate into AST proof |
| Compiler-parsed source boundary | `audit-swift-compiler-boundaries.py` + `run-swift-compiler-boundary-smoke.sh` | Uses local `swiftc -frontend -dump-parse` without executing source to bind all four targets to compiler-emitted imports and required public Core declarations; bounded input, path-safe failures and negative fixtures prevent this evidence from being overstated as type checking or sandbox proof |
| Contributor readiness gate | `check-contribution.py` + `contributor-check-receipt-v1.schema.json` | One path-safe, network-free entry point for quick source policy, complete isolated clone/build and strict content-pack contribution profiles; it never installs, opens a browser, mutates authoritative source or upgrades a preview into a public Release |
| Public source secret audit | `audit-public-source-secrets.py` + `public-source-secret-audit-v1.schema.json` | Bounded offline scan of the exact portable-source allowlist for high-risk credential files, private-key markers, known provider tokens, embedded basic authentication and suspicious assignments; it reads no environment value or private producer directory, includes no matched content in receipts and is also enforced inside untrusted source ZIP auditing |
| Local-first product boundary | `audit-product-boundary.py` + `product-boundary-receipt-v1.schema.json` | Bounded source and public-document guard that rejects payment integrations, forced accounts, advertising, automatic sharing and leaked superseded commercialization research; it permits explicit local export, reports no source excerpts or absolute paths, and runs in contributor, Doctor, CI and source-package gates |
| Public Git bootstrap | `bootstrap-public-git.py` + `public-git-bootstrap-receipt-v1.schema.json` | Builds and audits the portable allowlist into a separate unborn `main`, stages the exact regular-file set, rejects private/generated roots and publishes without replacement; it deliberately creates no commit, author identity, remote, network request or public-release claim |
| Settings presentation models | `Sources/CompanionApp/CompanionSettingsPresentationModels.swift` | Localized content-pack and backup summaries shared by settings without growing the view model |
| Content library boundary | `CompanionContentLibraryModels.swift` + `CompanionContentLibrary.swift` | Named internal result shapes plus the only application-facing actor for install, rollback, removal, recovery, playback health and portable backup; recovery-affecting UI results consume one coherent active/recovery store snapshot instead of joining separate actor reads |
| Content archive policy | `ContentPackArchivePolicy.swift` | Read-only central/local ZIP header agreement, path/link/collision and resource-limit policy shared by app import and the archive auditor |
| Content archive importer | `ContentPackArchiveImporter.swift` + `CompanionContentPackImportPanel.swift` | Private snapshot, fixed local extractor, exact postcondition, cleanup and the focused AppKit file/directory chooser; canonical pack installation remains in the content library |
| Content-pack manifest contract | `ContentPackManifest.swift` | Codable pack, provenance, rights, accessibility, fallback and declarative-experience models without filesystem or media side effects |
| Safe failure contract | `CompanionFailureReceipt.swift` | Stable error identity, path-redacted issue receipts and executable recovery copy shared by UI and creator tools |
| Content-pack validation orchestration | `ContentPack.swift` + `SemanticVersion.swift` | Bounded schema/version/locale/experience orchestration plus focused SemVer compatibility parsing; it delegates raw JSON shape, contribution policy and asset/filesystem safety and must not absorb those implementations |
| Raw manifest field boundary | `ContentPackManifestFieldValidator.swift` | Fail-closed unknown-key rejection before Codable decoding; owns no filesystem, hashing, media, UI, network or persistence capability |
| Contribution policy boundary | `ContentPackContributionValidator.swift` + `ContentPackContributionValidationSupport.swift` + `ContentPackRightsValidator.swift` + `ContentPackAccessibilityValidator.swift` + `ContentPackFallbackValidator.swift` | A thin v1-compatible/v2-strict dispatcher plus focused pure policies for shared field hygiene, package/per-asset rights, localized accessibility and media-compatible fallback. None reads files or environment state, and missing legacy rights are never promoted to verified rights |
| Asset and package safety boundary | `ContentPackAssetValidator.swift` + `ContentPackPackageContentsValidator.swift` + `ContentPackAssetFileValidator.swift` + `ContentPackAssetProjectionValidator.swift` | A thin stable dispatcher over no-follow package enumeration, per-asset path/size/executable/hash authentication and value-only media/projection/trigger policy. Only the first two focused validators own filesystem capability; projection owns no files, hashing, decoder, UI, network, persistence or runtime playback |
| Content playback models | `ContentPackPlaybackModels.swift` in `CompanionApp` | Immutable asset, selection, sequence and playback-cursor values; contains no store access, selection policy or media side effects |
| Content trust runtime | `ContentPackStore.swift` + `ContentPackRuntimeCatalog.swift` + `ContentPackRuntimeSelection.swift` + `CompanionContentSequenceRuntimeCoordinator.swift` + `ContentPackRuntimeAccessibility.swift` | Transactional installation/health, immutable manifest projection, pure locale/cooldown/weighted selection, single-session sequence ownership, ordered playback and bounded localized non-visual media descriptions |
| Error presentation | `CompanionErrorPresentation.swift` | Privacy-safe localized recovery guidance plus stable support codes; raw system errors never cross into UI |
| Creator tools | `scripts/create-content-pack.py`, `scripts/*content-pack*`, `scripts/build-creator-tool.sh` | Network-free atomic multi-locale scaffolding, validation, copy-free locale coverage matrix, preview, projection editing, declarative experience authoring and `.chengyinpack` build/audit; scaffolding emits path-safe receipts without inferred rights, the locale matrix separates strict media eligibility from accessibility fallback without decoding media, manifest-writing flows are rollback-safe and archive output publishes only after an independent path-free post-audit |
| Community review index | `community/index.json` + `audit-community-pack-index.py` | Offline strict-v2 manifest/hash/reviewer binding; never a store or executable plugin registry |
| Local bridge | `CompanionEventEmitter` and watcher | Explicit, bounded, content-free lifecycle events |
| Local bridge repair | `CompanionEventBridgeRepair.swift` | No-follow inspection and permission tightening for the app-owned event directory; refuses unexpected files and symlinks without deleting or renaming them |

The large app composition files are migration surfaces, not invitations to add
more policy. New deterministic rules should start as a small pure type in
`CompanionContracts` or a focused App source file, gain a smoke/contract check,
and only then be wired into the view model.

The machine boundary in [CORE-MODULE-BOUNDARY.md](CORE-MODULE-BOUNDARY.md)
prevents required policies from returning to App, forbids UI/media/network
dependencies in Core, freezes composition-file growth and checks the public care
scheduler, chemistry and direct-play presentation surfaces.

## Data boundaries

- Task state stores opaque references, counts, timestamps, durations and outcomes;
  it has no fields for prompts, code, titles or paths.
- Relationship state stores counters, a user-selected tone, opaque content IDs and
  bounded playback timestamps. Every persisted field has an explicit deletion path.
- Care memory stores only bounded reminder kinds, timestamps, daily counts and a
  pause deadline. Corrupt primary data may recover one valid local rollback copy;
  explicit deletion clears rollback history first so deleted state cannot return.
- Shared-workday memory stores only counts, bounded durations and lifecycle
  timestamps. Primary, backup and safe-default recovery are explicit in local
  diagnostics; task references remain in-memory only and never enter the report.
- Content packs are immutable, declarative directories. They cannot contain or
  invoke executable code, URLs, shell commands or provider credentials.
- Projection editor HTML may execute only its embedded local UI logic and cannot
  enter a pack. Its portable receipt contains identities plus bounded geometry,
  never media paths; the applicator validates before and after atomic write and
  keeps a sibling backup on success or rollback.
- The community index is not consumed by the app. It contains only repository-
  relative pack identity, manifest hash and review binding; CI reruns the
  authoritative strict pack audit without network access.
- Runtime compatibility and contribution readiness are separate. Core derives
  `legacy-v1`, `compatibility-v2` or `strict-v2`; it never infers authorization.
  Strict review requires package and per-asset provenance, authorization basis,
  enumerated allowed uses, attribution, adult/fictional status, localized alt
  text/captions/sound descriptions, sensory warnings, per-asset fallback and
  approved versioned reviews.
- UI orchestration must use `CompanionContentLibrary`; it must not retain a raw
  `ContentPackStore` or independently compose backup and inventory operations.
- The user can globally pause local packs without deleting or rewriting them;
  this Starter recovery mode is the first troubleshooting isolation step.
- The app has no microphone declaration, realtime conversation or hidden upload.
- Automatic runtime recovery is closed and local: it may tighten event-directory
  permissions or recover an interrupted content-library transaction. It cannot
  replace the app, delete media, enable preferences, follow an unexpected
  symlink, or contact a network service.
- Media health is established only after real playback progress; a failed pending
  revision rolls back or disables safely.
- A content-pack crop is resolved by the shared projection contract before it
  reaches AVFoundation. Modern `stage`/`fullscreen` keys and v1 `partial`/`full`
  aliases are accepted. Optional focal tracks interpolate linearly from media
  time, declared safe areas must remain visible at every keyframe, and edge
  anchors are clamped so they cannot reveal blank gutters. Missing or invalid
  declarations use the bounded mode default; reduced-dynamic mode keeps its
  static fallback.
- Lab/Stable/Verified is derived from installation tier, signature gate and real
  playback health. It is never trusted from creator-authored manifest copy.

## Experience precedence

1. A direct gesture may replace the current presentation.
2. A trusted task success/failure is queued while play or media is active, then
   presented once.
3. Direct pet or palette play grants 45 seconds in which response-ready remains
   ambient and proactive care waits for reevaluation.
4. A response-ready signal becomes ambient when attention is already occupied.
5. Lifestyle care defers during quiet hours, games, media and hourly-budget limits.
6. Ambient presence never interrupts a higher lane.

Content Pack v2 supplies only media order, step role, transition, return policy,
weight and cooldown. It does not decide precedence.

## Failure rules

- Never infer task completion from process output, elapsed time or a turn ending.
- Never mark a sequence complete before the last video-end callback.
- Ignore stale and duplicate player callbacks.
- Keep a bounded watchdog for media systems, but treat watchdog expiry as failure.
- On v2 failure, report pack health and replay the original event through the
  bundled fallback without selecting the same experience again.
- Explicit deletion clears rollback data before installing the replacement state.
- Engineering preview and installation are separate evidence layers: a current
  `dist` process proves the preview path only. A local update remains incomplete
  until source, `dist`, installed app and running process identities agree.
- Runtime identity receipts expose only versioned state, origin category and a
  short source fingerprint; never publish a PID, username or absolute path.
- Public failure identity uses the stable families documented in
  [ERROR-CODES.md](ERROR-CODES.md); translated prose may change, codes may not be
  renamed or reused inside a compatible release line.

## How to add a feature

1. Define the user-visible outcome and the data/permission boundary.
2. Put deterministic policy in a pure type and add a contract or smoke check.
3. Add localized Chinese and English copy together.
4. Add a built-in fallback before accepting optional pack content.
5. Verify cancellation, duplicate callbacks, corrupt state and restart behavior.
6. Use Python 3.9 or newer, then run `./scripts/bootstrap-local.sh --check-only`, `swift build`, the relevant
   smoke checks and `./scripts/doctor.sh`.

Public contract changes, persistence fields, new permissions and new trigger
families require an RFC. See [COMPATIBILITY.md](COMPATIBILITY.md),
[GOVERNANCE.md](../GOVERNANCE.md) and [CONTRIBUTING.md](../CONTRIBUTING.md).

## Machine-routed review ownership

The [module stewardship contract](MODULE-STEWARDSHIP.md) is the executable bridge
between this source map and contribution review. Given repository-relative changed
paths, it returns only stable module, role, check, risk, RFC and owner-gate IDs.
It supports deleted files, resolves nested modules by exact path then longest
prefix, rejects generated/private areas, and never includes the input paths in its
receipt. The policy intentionally uses role IDs until a canonical GitHub
organization exists; it is a regression-prevention review-routing gate, not proof of human approval,
rights, compiled architecture, signing or public-release readiness.
