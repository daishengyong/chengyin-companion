# Example content packs

`hello-workday` is a small, executable-free Content Pack v2 learning fixture. It
contains one real three-beat `taskCompleted` ritual, two localizations and three
16:9 abstract videos with soft native tones. The videos are intentionally
person-free: the example teaches sequence routing, projection, rights,
accessibility and fallback metadata without redistributing a character likeness.
It is not a public character or a final Starter-media license.

Validate it from the repository root:

```bash
./scripts/validate-content-pack.sh examples/packs/hello-workday --json
./scripts/audit-content-pack.sh examples/packs/hello-workday --strict --json
python3 scripts/check-example-experience-pack.py
```

Generate and open a local, network-free catalog after validation:

```bash
./scripts/preview-content-pack.sh examples/packs/hello-workday
```

The preview is local and network-free. It shows the three ordered steps and the
pet, stage and fullscreen projections declared by the same landscape masters.

Regenerate the abstract fixture media after installing FFmpeg:

```bash
./examples/packs/generate-hello-workday-media.sh
```

Regeneration does not edit `manifest.json`: review the result, update the three
SHA-256 declarations and increment the affected rights/accessibility review
versions before validating again. Checked-in clips remain usable when FFmpeg is
not installed.

To learn the transactional authoring flow, copy the pack to a temporary
directory and replace the existing ritual only after a dry run:

```bash
./scripts/author-content-pack-experience.sh /tmp/hello-workday \
  --id ritual.shared-win \
  --kind ritual \
  --trigger taskCompleted \
  --step shared-win-enter:enter:900:crossfade \
  --step shared-win-react:react:1100:cut \
  --step shared-win-exit:exit:900:crossfade \
  --locale zh-Hans --locale en-US \
  --cooldown 900 --weight 1 \
  --return-policy previousMode --replace --check --json
```

Create a new empty draft:

```bash
./scripts/new-content-pack.sh /tmp/my-pack cc.example.my-pack starter zh-Hans
```

The generated draft contains no provider credential and no executable plugin. Add
assets to `manifest.json`, record their SHA-256 values and validate again before a
pull request.
