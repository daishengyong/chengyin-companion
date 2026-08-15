# Chengyin Companion new-user quickstart

[简体中文](QUICKSTART.zh-Hans.md) · English

This guide is for non-technical users trying the source edition for the first
time. The public repository excludes rights-pending built-in character media,
but the interaction system, care rhythms, mini-games, Content Packs, and local
event protocol all run.

## 1. Before installation

- Apple Silicon Mac (M1/M2/M3/M4)
- macOS 14 or newer
- At least 2 GB of free space
- Xcode Command Line Tools
- Python 3.9 or newer

If Command Line Tools are missing, use Apple's system installer:

```bash
xcode-select --install
```

## 2. Easiest route: ask Codex

Send this entire prompt to Codex:

```prompt
Install and launch Chengyin Companion from https://github.com/daishengyong/chengyin-companion.
Check Apple Silicon, macOS 14+, Xcode Command Line Tools, Python 3.9+, and 2 GB free space first.
Clone into ~/ChengyinCompanion. If that folder contains user changes, preserve it and use a fresh temporary clone.
Run ./scripts/bootstrap-local.sh --check-only, then run ./scripts/bootstrap-local.sh only if preflight passes.
Do not use sudo, bypass macOS security, read or upload secrets, call Seedance/TTS, or edit ~/.codex/config.toml.
Report the installed version, location, and launch result at the end.
```

The installer builds the current source, transactionally installs into
`/Applications/Chengyin Companion.app`, retains the previous app, relaunches,
and checks the running identity. A failed install does not leave a partial app.

## 3. Manual installation

```bash
git clone https://github.com/daishengyong/chengyin-companion.git ~/ChengyinCompanion
cd ~/ChengyinCompanion
./scripts/bootstrap-local.sh --check-only
./scripts/bootstrap-local.sh
```

To try it without installing into `/Applications`:

```bash
cd ~/ChengyinCompanion
./scripts/preview-local.sh
```

## 4. Your first minute

1. Single-click the character for a short response.
2. Double-click to open a life or fantasy scene.
3. Hold for one second and release for affection feedback.
4. Drag to try pickup, fling, and edge docking.
5. Press `Command + Shift + M` to cycle pet, stage, and fullscreen.
6. Press `Command + Shift + G` to start the 20-second Catch Me game.
7. Press `Command + Shift + R` to preview task-completion celebration.

The public code edition shows animated system graphics by default. To use video
and audio, import a `.chengyinpack` you have the right to use. The app checks
provenance declarations, paths, sizes, hashes, decoding, and fallbacks first.

## 5. Trigger completion celebration from your Codex project

Automatic task celebration is explicit and project-scoped. Add this rule to
your own project's `AGENTS.md`; never treat ordinary turn completion as whole-task
success:

````markdown
# Chengyin Companion completion event

Only when the primary Codex agent has genuinely completed the user's concrete
objective and all required checks have passed, run exactly once immediately
before the final response:

```bash
if [ -x "/Applications/Chengyin Companion.app/Contents/SharedSupport/CompanionEventEmitter" ]; then
  "/Applications/Chengyin Companion.app/Contents/SharedSupport/CompanionEventEmitter" task.completed
fi
```

Do not emit this event for progress updates, plans, questions, failed work,
subagents, previews, dry runs, or ordinary turn completion.
````

The rule sends no task title, code, prompt, or path. The app receives only a
local terminal event.

## 6. Update, diagnose, and recover

After updating the clone, rerun:

```bash
git pull --ff-only
./scripts/bootstrap-local.sh
```

Check source, build, installed app, and running identity:

```bash
./scripts/doctor.sh
```

Installation retains the previous application under `dist/install-backups/`.
Preferences, relationship memory, and local packs live outside the app bundle.
For help, open a [GitHub Issue](https://github.com/daishengyong/chengyin-companion/issues)
with the app's privacy-minimal diagnostic; never upload API keys or private media.

## 7. Current public-release boundary

- A source install is a local ad-hoc development build, not a Developer ID
  signed and notarized DMG.
- MIT covers code and software documentation only. Rights-pending Starter media
  is absent from the public repository.
- The app does not record audio, read Codex conversations, upload diagnostics,
  or require an account.
- Do not download unofficial installers claiming to include the full character
  media library.

## Developer and automation checks

```bash
./scripts/preview-local.sh --check-only --json
./scripts/run-first-use-low-impact-audit.sh --zero-authorization
./scripts/check-contribution.py --profile quick --json
python3 scripts/audit-public-source-secrets.py --json
./scripts/run-portable-source-smoke.sh
```

These cover preview prerequisites, zero-authorization degradation, contribution
contracts, secret scanning, and isolated source packages. None substitutes for
media rights, Developer ID, Apple notarization, or human testing on a clean Mac.
