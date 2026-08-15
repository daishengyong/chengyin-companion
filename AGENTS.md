# Chengyin Companion — Codex Working Guide

## Product

Chengyin Companion is a local-first macOS desktop companion for AI coding workflows. It reacts to explicit local task events with short audiovisual scenes, gestures, reminders and mini-games.

This repository must remain a complete free product. Do not add a timer, daily limit, advertisement, affection paywall, forced sign-in or automatic sharing.

## Current Status

- Personal MVP; not production-ready.
- Do not publish a repository or Release without the owner.
- Do not enable production payments.
- Do not sign, notarize or enroll provider accounts without the owner.
- Existing real-person reference photos are not commercial inputs.
- Existing media is prototype material until its rights status is approved.

Read first:

1. `docs/PRODUCT-BOUNDARY.md`
2. `ROADMAP.md`
3. `docs/CODEX-PRODUCT-ARCHITECTURE.md`
4. `docs/GLOBAL-PERSONA-SYSTEM.md`
5. `docs/PACK-SPEC-v2.md`

## Required Checks

Run:

```bash
./scripts/doctor.sh
```

Or individually:

```bash
swift build -c release
swift run CompanionContractChecks
CHENGYIN_EVENT_ROOT="$(mktemp -d)" swift run CompanionEventEmitter task.completed 1000
CHENGYIN_EVENT_ROOT="$(mktemp -d)" swift run CompanionEventEmitter codex-notify '{"type":"agent-turn-complete"}'
./scripts/run-content-pack-smoke.sh
```

The direct command `swift scripts/content-pack-smoke.swift` is not the supported invocation.

## Architecture Rules

- Put versioned event and settings contracts in `CompanionContracts`.
- Treat the direct `~/.codex/sessions/**/*.jsonl` watcher as a legacy adapter.
- Do not send prompts, code, paths, task titles or personal data in companion events.
- Do not claim the app can silently reuse a user's ChatGPT or Codex subscription.
- Treat Codex `notify`, trusted lifecycle hooks, or App Server as upstream event sources; file spool/UDS are transports only.
- Never overwrite an existing user-level Codex `notify` setting or install a project hook without explicit user confirmation.
- Keep presentation, scheduling, media, games, packs and events separable.
- One 16:9 source video should project to pet, stage and fullscreen where possible.
- Content packs cannot contain executables or arbitrary scripts.
- Install packs transactionally; validate before activation; roll back on failure.
- Keep installed community and local packs usable offline after activation.
- Never add payment SDKs, account walls, advertising, automatic sharing, signing private keys or provider credentials.

## Content Rules

- All public characters are original fictional adults, explicitly 25+.
- Do not imitate celebrities, public figures, actors, voices or protected characters.
- Do not use prompts like “looks like X” or “X mixed with Y.”
- Do not use user-provided real-person photos in public generation.
- Relationship tone is independent of skin tone, body type, locale and nationality.
- Public assets are non-explicit and accurately described by their manifests.
- Record prompt, model, task ID, resource tokens, input rights, output SHA-256 and review status.
- First Seedance calibration is limited to 10 calls and 2M resource-package tokens.

## Change Discipline

- Preserve user changes and unrelated files.
- Use migration and rollback for state changes.
- Add automated checks for contracts, parsers, security boundaries and recovery. The current local Swift toolchain does not expose XCTest/Testing; `CompanionContractChecks` is the zero-dependency runner until the Xcode CI test module is available.
- Update relevant docs when changing a public contract.
- Do not report production readiness without signing, notarization, clean-machine restore, provider approval and rights evidence.

## Completion Truth Rule

- Only the primary Codex agent may emit a live `task.completed` event, never a subagent, smoke test, preview, plan step or intermediate turn.
- Emit it at most once, after the user's concrete implementation objective is genuinely finished, required checks pass, and any requested local installation is verified.
- Questions, reviews, partial progress, blocked work and `agent-turn-complete` are `response.ready`, not task completion.
- Validation commands must set `CHENGYIN_EVENT_ROOT` to a temporary directory. They must never write a simulated success into the live event spool.

## Definition of Done

A feature needs:

- implementation;
- automated tests;
- failure and offline behavior;
- privacy review;
- localization keys;
- accessibility where applicable;
- doctor diagnostics;
- migration and rollback when state changes;
- user-facing documentation.
