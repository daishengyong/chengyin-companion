# Project governance

[简体中文](GOVERNANCE.zh-Hans.md) · English

Chengyin currently uses a maintainer-led model while its public contracts and
rights boundaries stabilize. The aim is fast, transparent decisions without making
contributors depend on private context.

## Decision classes

- **Routine contribution:** bug fixes, tests, documentation, localization and
  compatible content updates may go directly through pull request review.
- **RFC contribution:** a new public API, pack contribution point, permission,
  persisted field or major interaction begins with a short proposal in Discussions
  or an RFC issue.
- **Owner gate:** public repository creation, final licensing, trademarks, signing,
  notarization, provider accounts and release publication remain decisions for the
  project owner. A pull request cannot silently cross these gates.

## Review principles

1. Protect a complete free, local-first experience.
2. Prefer explicit lifecycle events over inference from private files.
3. Persist opaque counters and identifiers, never prompts, code, paths or task titles.
4. Prefer declarative experience packs to executable plugins.
5. Require a graceful offline fallback and rollback path.
6. Treat character, voice, music and video rights as release data, not informal notes.
7. Avoid streak loss, jealousy, guilt or intimacy as pressure mechanics.

## Module stewardship

Frequent contributors may become stewards for a package, adapter, locale or content
pack. A steward is expected to review related issues and pull requests, maintain
tests and compatibility notes, and identify a successor before stepping away.
Stewardship grants review weight, not ownership of community contributions.

The machine-readable [module stewardship contract](docs/MODULE-STEWARDSHIP.md)
routes changed paths to role IDs, local checks, risks, RFC policy and owner gates.
When the canonical GitHub organization is created, real steward accounts can be
bound to that reviewed manifest and `.github/CODEOWNERS`. Until then, reviewers
are recorded in pull requests and architecture decisions without inventing GitHub
handles; a routing receipt is not approval or release authorization.

## Compatibility

- Stable event and pack schemas use semantic versions.
- Breaking changes require an ADR, migration, rollback fixture and deprecation period.
- A character or relationship update must preserve identity and user-controlled tone.
- A contributor can always fork under the final code license; trademarks and media
  follow their separately published policies.

## Conflict resolution

Start with the documented product boundary and reproducible evidence. If reviewers
still disagree, the maintainer records the decision, alternatives and revisit trigger
as an ADR. Security and rights reports use the private process in `SECURITY.en.md`.
