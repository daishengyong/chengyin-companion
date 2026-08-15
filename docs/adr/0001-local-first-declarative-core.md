# ADR 0001: Local-first declarative companion core

- Status: Accepted
- Date: 2026-08-06

## Context

The companion must remain useful after cloning, without an account, hosted
service, microphone or opaque executable extensions. Optional media still needs
safe installation, rollback and community contribution.

## Decision

Core scheduling, interaction, state and fallback media run locally. Content packs
contain immutable declarative media and bounded manifest data only. They cannot
contain executable code, provider credentials, URLs or commands. Network services
may help creators produce assets outside the pack, but are not a runtime
dependency.

## Consequences

The free repository remains complete and inspectable. Creator workflows need
explicit generation outside Core, and richer extensions must evolve through
versioned schemas rather than arbitrary plugins.

## Verification

The validator rejects executable/undeclared/traversal input; creator preview is
network-free; doctor checks there is no microphone declaration and that bundled
fallback media decodes.
