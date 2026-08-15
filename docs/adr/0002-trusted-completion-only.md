# ADR 0002: Celebrate only trusted task-terminal success

- Status: Accepted
- Date: 2026-08-06

## Context

A Codex turn ending, output becoming available or a process producing text does
not prove that the user's task succeeded. False celebrations damage trust more
than a subtle delayed response-ready cue.

## Decision

Only an explicit, validated `task.completed` event with success outcome from the
bundled `codex-skill` / `terminal-events-v1` producer opens the task-completion
celebration. App Server keeps only documented failure/interruption states. All
unregistered terminal claims and `agent-turn-complete` map to neutral
`response.ready`. Events already present before watcher startup establish a
deduplication baseline and are not replayed. Trusted fresh terminal events may
queue behind active play, but are delivered once. Broken optional media falls
back to the built-in completion path.

## Consequences

Integrations need a reviewed producer/version contract, not only a syntactically
valid local JSON event. The companion may be quieter for unintegrated tools, but
it will not claim work is complete without registered semantic evidence.

## Verification

Contract checks cover the producer/version matrix, event privacy and round-trips;
experience-director checks cover queuing; event-watcher smoke proves restart
baselining, exact-once fresh delivery and neutral notify mapping; v2 playback has
stale-callback and fallback checks. This is misconfiguration defense, not origin
authentication against an active process running as the same local user.
