# Compatibility policy

Chengyin is pre-1.0, but local state, content packs and event producers already
need predictable evolution. This policy applies to accepted public changes.

## Compatibility promises

- The current app reads Content Pack schema 1 and 2. Existing schema-1 packs do
  not need migration to use the single-video runtime.
- Core derives `legacy-v1`, `compatibility-v2` or `strict-v2`. v1 and old v2
  remain installable, but no missing source, authorization, allowed use,
  attribution, adult/fiction status or review is inferred from legacy fields.
- Legacy v1 and compatibility-v2 keep safe mixed-case asset/experience IDs;
  strict-v2 normalizes new contribution IDs to lowercase without rewriting old
  manifests.
- `plan-content-pack-v2-migration.sh` is read-only and reports missing factual
  evidence with `writesPerformed: false` and `rightsInferred: false`.
- Strict v2 requires package and per-asset provenance, explicit allowed uses,
  attribution, adult/fiction status, localized alt text/captions/sound
  descriptions, fallback and versioned review. Only exhaustive approved records
  can become `READY_FOR_LAB`.
- Unknown future schema majors are rejected, not partially interpreted.
- Projection authoring receipts use their own
  `chengyin.projection-authoring-receipt/v1` schema. They bind one pack and one
  video asset, use only modern `pet`/`stage`/`fullscreen` keys, and never rewrite
  legacy aliases until the user explicitly applies a validated receipt.
- Persisted state is versioned and decoded through an explicit migration path.
- Existing settings default safely when a newer optional field is absent.
- Legacy settings default to a transparent surface that follows the window's
  current display. A specific-display target stores only a bounded technical
  identifier; if it is invalid or unavailable, runtime selection recovers to the
  current, main, first valid, or deterministic fallback frame in that order.
- Cinematic appearance resolves to the non-material Dim surface when macOS
  Reduce Transparency is enabled. Increased Contrast changes only the derived
  surface plan, not persisted settings.
- Portable backups restore only explicit companion preferences and active content
  packs; relationship memory and Codex-derived workday state never travel in the
  backup. Older settings payloads gain safe defaults for additive fields.
- Companion Event protocol `1.x` stays privacy-minimal; a major protocol change is
  required before adding a new privacy-bearing data class.
- Built-in media and behavior remain a usable fallback when optional content is
  absent, incompatible or unhealthy.
- Lifestyle scheduling is a Core policy with injected time and bounded facts.
  Its public reminder, context, policy and decision types may only change with a
  documented migration; App adapters own persistence and presentation side effects.
- Direct-interaction chemistry is a Core policy with injected time, tone, level,
  mood and bounded recent keys. Public interaction, candidate, selection and
  director types may only change with a documented migration; existing tone
  boundaries and the neutral fallback must remain available.
- Experience presentation lifetime is session-local and non-persistent. A
  generation token rejects stale timer/fallback callbacks, while trusted task
  terminal visuals use a bounded reserve and explicit coalesced count instead
  of silent queue loss. Changing queue priority, capacity or coalescing semantics
  requires busy, overflow, cancellation, stale-handoff and replay tests.
- Shared-workday polling and completion-reply lifetime are session-local. A
  poll generation prevents a cancelled loop from delivering after restart, and
  a reply generation prevents an older expiry from closing a newer response
  window. Disabled announcements are consumed without delayed replay. Changes
  require real local-event, false-completion, stop/restart and expiry tests.
- Built-in microgame progress is an ephemeral Core session: active game, timer,
  score, combo, gesture step, heart path and rhythm timing are discarded on end
  or launch and never enter backup or diagnostics. This extraction needs no data
  migration. Existing catch/hide best-score preference keys remain compatible;
  one focused App coordinator owns the only cancellable timeline and exact
  pre-game return context, without persisting either one;
  changing a target, timing window or public session type requires a behavior
  compatibility note and normal, boundary, wrong-order and timeout tests.
- Community index schema v1 is an offline repository review artifact. Existing
  v1 fields keep their meaning; new required fields or any remote/runtime loading
  behavior require a new schema version and migration plan.
- Index approval binds one strict-v2 pack ID/version and exact manifest SHA-256.
  It never upgrades runtime Lab/Stable/Verified state or infers legal approval.
- Source bootstrap and local upgrade preserve preferences and installed content
  packs, and keep a recoverable previous app bundle.

## Change categories

| Change | Requirement |
| --- | --- |
| Documentation, copy, test strengthening | Pull request with normal checks |
| Optional manifest field with safe default | Schema, Swift validation, preview, compatibility test and docs |
| New trigger or experience behavior | RFC, allowlist update, arbiter impact and fallback test |
| Persisted field | RFC, size/privacy bound, migration, deletion control and corruption recovery test |
| Permission or network dependency | RFC and explicit user consent; never a silent core dependency |
| Community index field or policy | Schema, bounded parser, malicious fixture, strict-pack audit and compatibility note |
| Breaking schema/protocol change | New major version and side-by-side migration plan |

## Deprecation

A supported public field or trigger is not removed silently. Deprecation needs:

1. documentation and validator guidance in one release;
2. a working compatibility path for at least the next minor release;
3. a migration or an actionable local error;
4. a release note naming the last compatible version.

Security fixes may reject previously accepted unsafe input immediately, but the
release note must explain the boundary and the doctor should identify affected
local packs without uploading them.

## What is not yet promised

- A stable 1.0 source API for arbitrary in-process plugins;
- a public hosted pack marketplace or remote entitlement service;
- signed/notarized public binaries before release infrastructure exists;
- compatibility for media whose distribution rights are not documented.

The app version, bundle build and source fingerprint are all part of local update
identity. Matching timestamps or signatures alone never prove compatibility.
