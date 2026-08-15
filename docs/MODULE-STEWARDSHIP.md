# Module stewardship and contribution routing

[简体中文](MODULE-STEWARDSHIP.zh-Hans.md) · English

Chengyin keeps review ownership executable without inventing people or GitHub
handles. `community/module-stewardship.json` is the reviewed policy,
`Schemas/module-stewardship-v1.schema.json` is its public shape, and
`scripts/audit-module-stewardship.py` is the authoritative offline auditor and
changed-path router.

## What the contract answers

For every routed module, the receipt reports only stable IDs:

- review roles;
- required local checks and their executable commands;
- risk classes;
- RFC policy;
- owner-gate policy.

It never includes the submitted paths, checkout location, username, process ID or
media filename. It performs no network request and always preserves the explicit
`NOT_PUBLIC_RELEASE_READY` boundary.

## Run the contract

Audit the policy itself:

```bash
python3 scripts/audit-module-stewardship.py --audit --json
```

Route one or more changed repository paths:

```bash
python3 scripts/audit-module-stewardship.py --path Sources/CompanionContracts/CompanionEvent.swift --path docs/MODULE-STEWARDSHIP.md --json
```

Or pipe the newline-delimited output of a version-control change list without
placing raw paths in the receipt:

```bash
git diff --name-only --diff-filter=ACMRTUXB | python3 scripts/audit-module-stewardship.py --stdin --json
```

The router accepts deleted paths because it matches normalized repository-relative
names, while the policy audit separately proves that every declared prefix and
exact path exists in the trusted checkout. Exact-path declarations win over
prefixes; otherwise the longest matching prefix wins. Equal-specificity ambiguity,
unknown roots, generated/private areas, traversal syntax and symbolic-link policy
files fail with stable `STEWARDSHIP_*` codes and executable recovery guidance.

## Identity and owner boundaries

Six stewardship roles intentionally remain
`unassigned-until-canonical-github-organization`. The maintainer and release-owner
records describe owner boundaries, not public account identities. After the owner
creates the canonical GitHub organization, a separate reviewed change may bind
real accounts and generate `.github/CODEOWNERS`; until then, pull requests and ADRs
record the actual human reviewers.

Routing is not approval. A matching role does not prove media rights, accessibility
quality, security, final licensing, signing, notarization or public-release consent.
The receipt makes these review and owner gates visible so a contribution cannot
silently cross them.

## Evolving the policy

When adding a repository area:

1. Add one narrowly scoped module route and reuse existing role/check IDs where
   possible.
2. Add a role or check only when its responsibility is genuinely distinct.
3. Keep commands local, argument-only and free of shell operators, redirects,
   absolute paths and network tools.
4. Add positive and rejection coverage to
   `scripts/run-module-stewardship-smoke.sh`.
5. Run the quick contributor gate and public-document parity before review.

Nested modules are preferred over broad exceptions. Build outputs, local bridges,
Python caches and production backups stay forbidden contribution paths.
