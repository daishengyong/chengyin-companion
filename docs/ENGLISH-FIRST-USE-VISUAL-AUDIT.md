# English first-use visual audit

English · [简体中文](ENGLISH-FIRST-USE-VISUAL-AUDIT.zh-Hans.md)

This contract raises English first use from “localized strings exist in source”
to a reproducible five-step window walkthrough. Human VoiceOver and a physical
clean Mac remain explicit external gates. This is engineering evidence, not an
accessibility certification or public-release approval.

## Five-step path

The isolated lab copy uses a unique bundle identifier, separate UserDefaults,
temporary content and event roots, and an empty Codex-session root. It does not
read the user's existing companion content. The audit verifies the tap
invitation, double-click invitation, local companion preference, simulated
shared-work arc, and completion shown only at the terminal step. Every step
records a current-run window capture, full-window containment, English OCR, and
stable control identifiers when existing assistive-technology access permits it.

## Run it

Verify source, isolation, and receipt contracts without launching a GUI:

```bash
./scripts/run-english-first-use-visual-audit.sh --source-only
```

Run the isolated visual walkthrough from the current build on a Mac that already
has screen-capture access:

```bash
./scripts/run-english-first-use-visual-audit.sh
```

Run the local rejection matrix and isolated-root checks:

```bash
./scripts/run-english-first-use-visual-audit-smoke.sh
```

A GUI run writes five PNG files and `receipt.json` under
`dist/audits/english-first-use/`. The receipt contains no username, absolute
path, media filename, task title, or credential. The audit is offline, does not
call Seedance or TTS, does not read API keys or edit Codex configuration, and
does not touch the copy installed in `/Applications`.

## Evidence layers

`PASS_WITH_PENDING` means only that the isolated lab copy completed all five
captures, exposed visible English copy, advanced the interactions, and proved
that its writable roots did not use shared user content. When accessibility is
already trusted, AX control identifiers add evidence. Otherwise the receipt says
`PENDING_RUNTIME_ASSISTIVE_TECHNOLOGY` and requests no new permission.

`PENDING_HUMAN_REVIEW` always reserves VoiceOver reading order, focus travel, and
pronunciation for a person. `PENDING_EXTERNAL_DEVICE` reserves first download,
Gatekeeper, scaling, and layout for a physical clean English Mac. The receipt is
always `NOT_PUBLIC_RELEASE_READY`; it does not imply signing, notarization,
media-rights approval, or a final license. See the
[new-Mac first-use and low-motion audit](FIRST-USE-AND-LOW-IMPACT-AUDIT.md) for
the wider hardware and reduced-motion boundary.

For automated truth checking, this evidence layer is explicitly classified as
`human_review_required`; it is not a completed accessibility review.

## Failure and recovery

Failures use stable `FIRST_USE_VISUAL_AUDIT_*` codes with an executable recovery
action. Screenshot failure asks only for existing capture access to be checked;
missing English copy points to the exact capture and localization; interaction
failure points to the stable control or gesture. A failed run never fabricates a
capture, relaxes the English check, or upgrades a pending human gate to passed.
