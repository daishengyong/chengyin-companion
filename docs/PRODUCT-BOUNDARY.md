# Local-first product boundary

[简体中文](PRODUCT-BOUNDARY.zh-Hans.md)

## Current commitment

Chengyin Companion's public product is a complete, permanently usable,
local-first desktop companion. The current product contains no monetization,
subscription, purchase entry point, forced account, advertising or automatic
sharing. Core companionship, content packs, games, reminders, local Codex
events and creator tools do not expire or stop after a usage limit.

Explicit user-controlled local export, backup and diagnostic copy operations
are allowed. The app must not upload, publish or share automatically.
Diagnostics continue to exclude user names, absolute paths, task text,
prompts, code, relationship memory, pack identifiers and credentials.

## Compatibility is not commerce

The legacy content-pack schema can still parse the `paid` tier so an old
manifest is not mistaken for an unknown format. This application has no
entitlement provider, payment SDK, checkout link or purchase-restore service,
so such packs fail closed and do not form an available sales channel.
Community and local packs remain governed by provenance, rights, signature
state, media integrity and runtime-health gates.

## Historical research isolation

Superseded commercialization, payment and unit-economics research remains in a
private development working-copy directory as decision history. It is not part
of the public-clone contract, is excluded from portable source packages, and
must not be linked from public READMEs, contribution guides or architecture
entry points. A future boundary change requires a new owner objective and a
separate review; an ordinary contribution cannot introduce it silently.

## Executable checks

Audit the current development working copy:

```bash
python3 scripts/audit-product-boundary.py --scope development --json
```

Audit a portable-source or public-Git candidate:

```bash
python3 scripts/audit-product-boundary.py --scope public --json
```

Receipts contain only safe relative paths, categories and line numbers. They
never include matched source excerpts, environment values or absolute paths.
This is an executable regression guard, not compiler-AST proof, and it does not
replace the final license, media-rights approval, Developer ID, notarization or
human public-release approval.
