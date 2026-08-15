---
name: chengyin-companion
description: Build, diagnose, repair, validate, and restore the local Chengyin Companion macOS project and its content packs. Use when the user asks Codex to install from this repository, check project health, repair the free Starter, validate a pack, or emit a privacy-safe simulated task event.
---

# Chengyin Companion

## Scope

This repository skill operates on the local open-source project. The public signed Release flow is not available until a real GitHub Release, Developer ID signature and notarization exist.

Never:

- download from an unapproved domain;
- run a remote script pipeline;
- enable payment;
- publish a Release;
- upload diagnostics without user confirmation;
- include task titles, code, prompts or paths in companion events;
- use real-person reference photos for commercial content.

## Preflight

1. Locate the repository root containing `Package.swift` and `AGENTS.md`.
2. Read `AGENTS.md`.
3. Run `./scripts/bootstrap-local.sh --check-only`.
4. Run `./scripts/doctor.sh` for an existing installation.
5. Report each failed check and the exact local repair.

For a new source clone whose user explicitly asked to install, the complete local
path is `./scripts/bootstrap-local.sh`. It does not edit Codex configuration,
invoke media providers, read API keys or upload diagnostics.

## Build

```bash
swift build -c release
```

For the local `.app` bundle:

```bash
./scripts/build-app.sh
```

The current app bundle is development/ad-hoc signed. Do not describe it as a public trusted Release.

Before replacing a running local app, preview the exact candidate and installed
build identities:

```bash
./scripts/install-local-app.sh --dry-run
```

With owner confirmation, `./scripts/install-local-app.sh` performs the local
build, atomic application swap, backup, state-integrity check, relaunch and
post-install verification. Do not copy files into a running app bundle or
delete user preferences/content packs to force an update.

## Test

Start with the path-safe, network-free contributor gate:

```bash
./scripts/check-contribution.py --profile quick --json
```

Use `--profile full` before a release-oriented pull request. It runs the complete
isolated clone/build/contribute source-package gate and may take substantially
longer. For a declarative pack contribution, use `--profile pack --pack
<pack-directory>`; the receipt never publishes the local pack path.

```bash
swift run CompanionContractChecks
./scripts/validate-content-pack.sh examples/packs/hello-workday --json
./scripts/preview-content-pack.sh examples/packs/hello-workday --no-open
./scripts/audit-content-pack.sh examples/packs/hello-workday --strict --json
```

## Repair

Safe repair order:

1. validate the workspace;
2. rebuild generated SwiftPM output;
3. validate Starter resources;
4. validate content manifests;
5. rebuild the app;
6. run tests;
7. preserve user settings and packs.

Do not delete `Application Support/Chengyin` unless the user explicitly requests a full data reset. Prefer exporting a backup and moving a damaged pack to quarantine.

## Validate a Content Pack

Use the Pack v1 contract in `docs/PACK-SPEC-v1.md`.

Create, validate and locally preview an executable-free draft with:

```bash
./scripts/new-content-pack.sh /tmp/my-pack cc.example.my-pack starter --locale zh-Hans --locale en-US --json
./scripts/validate-content-pack.sh /tmp/my-pack --json
./scripts/preview-content-pack.sh /tmp/my-pack
./scripts/audit-content-pack.sh /tmp/my-pack --strict --json
```

Reject:

- path traversal;
- symlinks;
- executables;
- unknown triggers;
- duplicate IDs;
- hash mismatch;
- incompatible schema/app versions;
- undeclared or undecodable media;
- missing rights metadata for an official pack.

## Simulated Task Event

Use the local v1 file-spool transport:

```bash
swift run CompanionEventEmitter task.completed 1000
```

The emitter writes a bounded, privacy-safe event with an opaque task reference. Do not write directly into Codex session JSONL files and do not add task titles, code, prompts or paths.

To validate the documented Codex `notify` mapper without editing user configuration:

```bash
swift run CompanionEventEmitter codex-notify '{"type":"agent-turn-complete"}'
```

The mapper emits neutral `response.ready`, not task success, and discards Codex working-directory, prompt, response and upstream identifier fields. To enable live notifications, show the user the exact `~/.codex/config.toml` change first and obtain confirmation. Never overwrite an existing `notify`; provide a manual merge path instead. Treat `task.progress` and `task.long_running` as local companion inference, not guaranteed native Codex events.

## Restore

The current truthful restore path is:

1. rebuild or reinstall the free app from the repository;
2. validate bundled Starter resources;
3. restore an explicit local settings/pack backup if one exists;
4. run doctor;
5. fall back to Starter if a non-free pack is damaged.

If doctor reports a stale dist, installed or running build, rebuild and use the
transactional local installer. A matching human-readable version is not enough:
the embedded source fingerprint must also match.

Do not claim remote purchase restoration exists until an approved entitlement provider is implemented and tested.

## Handoff

Report:

- build status;
- test status;
- media counts;
- pack validation status;
- Codex adapter health;
- whether the app is development-signed or public-signed;
- what was repaired;
- what still requires the owner.
