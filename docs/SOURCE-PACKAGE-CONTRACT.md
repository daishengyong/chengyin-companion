# Verifiable source-preview package contract

[简体中文](SOURCE-PACKAGE-CONTRACT.zh-Hans.md) · English

This contract answers a narrow question: does a Chengyin source-preview ZIP contain the declared clone, build, test, customization, and contribution surfaces, without also carrying local caches, private paths, or generated release artifacts? It does not declare the artifact ready for public release.

## Build and verify

From a trusted repository checkout:

```bash
source_package_root="$(mktemp -d)"
./scripts/check-python-runtime.sh
./scripts/build-portable-source.sh --output "$source_package_root/chengyin-source.zip"
python3 scripts/audit-portable-source.py "$source_package_root/chengyin-source.zip" --json
python3 scripts/audit-public-source-secrets.py --json
python3 scripts/audit-product-boundary.py --scope development --json
./scripts/run-portable-source-smoke.sh
```

The builder refuses to overwrite an existing archive. Its default archive root contains both the runtime-source fingerprint and a separate source-package fingerprint. The first identifies the executable application's inputs; the second covers every staged public source and contribution file, so a scripts-, schema-, test-, or documentation-only change still receives a distinct package identity without pretending the app binary changed. An explicit root must use letters, numbers, dots, underscores, and hyphens and must end in `-source`.

## Machine-readable contents

Every archive has exactly one top-level directory. `SOURCE-PACKAGE.json` declares the app build identity, the full source-package identity, macOS and architecture floor, included and excluded roots, checksum inventory, and the current owner-controlled release gates. `SOURCE-SHA256SUMS.txt` covers every packaged regular file except itself. The source-package fingerprint is computed over the relative path and SHA-256 of every regular file except the generated `SOURCE-PACKAGE.json` and `SOURCE-SHA256SUMS.txt`, avoiding a circular identity. The JSON Schema is `Schemas/source-package-v1.schema.json`.

The `clone-build-contribute-v1` profile includes the Swift application and contract sources, tests, creator tools, Content Pack v2 schemas and examples, CI, bilingual public governance documents, the machine-verifiable product boundary, module stewardship and review-routing policy, local packaging instructions, and the release-gate registry. It excludes working-copy metadata, local agent state, build caches, installed artifacts, private video-production inputs, superseded commercialization research, and generated release outputs.

## Audited public Git bootstrap

`python3 scripts/bootstrap-public-git.py --destination <new-absolute-directory> --json`
turns that allowlisted package into a separate public repository candidate. It
re-audits the ZIP before extraction, runs the bounded credential audit on the
extracted tree, initializes an unborn `main` branch, stages exactly every
regular public file, rejects private/generated roots, then publishes the new
directory with a macOS exclusive rename. Existing destinations are never
merged or replaced. The receipt contains no local path and explicitly records
that no commit, remote, author identity, network access, or mutation of the
authoritative development directory occurred.

This is a staging contract, not repository ownership or release approval. The
project owner still chooses the first commit, author identity, canonical host,
remote and organization. Run `./scripts/run-public-git-bootstrap-smoke.sh` to
exercise the successful path plus relative, existing, in-project, symlinked
parent and unknown-option rejection cases.

## Untrusted archive boundary

The auditor reads the ZIP without extracting it. It rejects absolute or traversing paths, backslashes, symbolic links, duplicate names, case or Unicode collisions, file/directory normalization collisions, hidden or undeclared roots, local metadata, generated/private paths, excessive file counts or sizes, unsafe compression ratios, incomplete checksum coverage, changed bytes, mismatched build identity, and release-gate drift. It also runs the same bounded secret policy and local-first product-boundary policy over packaged source. A coherently checksummed credential, payment integration, forced account, advertising, automatic sharing, or leaked historical commercialization document is still rejected. Failures use the shared stable error-code registry and return a privacy-safe recovery action.

The allowlist is deliberately strict at the repository-root boundary. Files inside declared public source directories remain covered by the exact checksum inventory and the archive limits; arbitrary root additions such as secrets, environment files, private photos, or Finder metadata are rejected even if someone recalculates the checksum list.

## Integrity is not authenticity

The SHA-256 inventory and source-package fingerprint prove only internal consistency between this ZIP, its manifest, and its packaged files. They are not digital signatures, do not identify who created the archive, and do not protect against an active attacker who can replace both the payload and all identity/checksum metadata. Obtain the audit script from a trusted checkout, compare release evidence through a trusted channel, and wait for a future signed distribution before making provenance claims.

An audit `PASS` means the package satisfies the clone/build/contribute preview contract. It does not mean media rights passed, a final license was approved, Developer ID signing succeeded, notarization was accepted, or the owner authorized public release. Those states remain separate in `release/release-gates.json`.

## Verification matrix

The smoke matrix covers a content-addressed default root, a valid explicit root, invalid-root rejection, coherent checksum repacking with a stale package fingerprint, a coherently checksummed credential-file rejection, a complete isolated checkout that compiles the actual `ChengyinCompanion` application product, checksum tampering, undeclared sensitive root files, Finder metadata, normalized path collisions, symbolic-link and traversal attacks, concurrent Swift preflights, a deterministic Python 3.9+ runtime matrix, the one-command contributor receipt, role-only module review routing and its rejection matrix, source-only bootstrap, public-document and localization parity, stable error codes, release-state preservation, Swift contract checks, the example content pack, the Content Pack v2 eight-state matrix, creator-tool integrity, projection authoring, ephemeral microgame wiring, the path-safe source/dist/installed/running identity matrix, portable direct-play and all-six-game reward receipt wiring, its JSON Schema, a simulated rejection matrix that cannot claim live GUI evidence, and a short privacy-safe headless media decode/memory probe with negative receipts. The script reports the current isolated-check count from its executable matrix instead of relying on a hand-maintained number. The source-package smoke does not inject pointer input or claim a GUI pass; `audit-direct-play-runtime.py` and `audit-all-game-rewards.py` perform separate local runtime gates only when one verified current app is already running. Only the latter's production receipt may state `proofKind=LIVE_LOCAL_GUI`.

A locked GUI session is tri-state evidence, not a failed reward. The aggregate
game receipt returns `PENDING` with exit 2, `proofKind=NO_GUI_PROOF`, zero
verified games and no expansion/restoration records. Only an unlocked six-game
`PASS` can carry `proofKind=LIVE_LOCAL_GUI` as successful visual evidence.

The smoke test never installs into `/Applications`, launches the GUI, calls Seedance or TTS, reads API keys, or upgrades a preview artifact into a public-release claim. Its short media probe sets `releaseSoakSatisfied=false`. On a normal Mac it must produce `HEADLESS_AVFOUNDATION_DECODE`; if a detected Codex outer sandbox denies every AVFoundation frame while memory remains bounded, the probe instead returns exit 2 with `PENDING / PLAYBACK_SOAK_AVFOUNDATION_RESTRICTED / NO_DECODE_PROOF_RESTRICTED_SANDBOX`, and the aggregate source receipt is `PASS_WITH_PENDING`. Corrupt media, partial decode, resource growth and latency regressions still fail. The separately stored 30-minute current-Mac receipt sets that field to true for headless AVFoundation decode and bounded resident growth only; it still does not substitute for the App's real `isReadyForDisplay` timing, GPU curve, or human audiovisual review on target hardware. New-Mac installation, media-rights approval, the final license, Developer ID signing, notarization, and owner release approval remain separately evidenced gates.
