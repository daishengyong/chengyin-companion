# Companion Event inbox security

[简体中文](EVENT-SPOOL-SECURITY.zh-Hans.md)

This contract covers the local inbox read by Chengyin Companion after a trusted
adapter emits a privacy-minimal Companion Event. It keeps a broken or hostile
local entry from becoming task completion, an unbounded scan, or a privacy leak.
It does not add a network transport or broaden App Server completion semantics.

## Accepted entry contract

- The inbox root must be a current-user directory with exact mode `0700`; its
  final path component is opened as a directory with no-follow semantics.
- An event must be a current-user, single-link, regular `0600` file named
  `<UUID>.json`. The UUID inside the decoded event must match the filename.
- Reads are bounded by the Companion Event payload limit and use the already-open
  directory descriptor. Links, FIFOs, broad permissions, empty/oversized data,
  malformed events, and filename/content disagreement are ignored.
- Unexpected unsafe entries are preserved rather than followed or deleted.
- Safe entries present before watcher startup establish a deduplication baseline
  and are not replayed. A fresh event is still delivered once after startup.
- Terminal semantics are evaluated by the separate Core producer/version policy;
  a valid file from an unregistered producer is only response-ready.
- Envelope decoding, bounded duration and opaque task-reference sanitization live
  in the capability-free `CompanionEventIngress.swift`. The watcher owns only
  transport, restart baselining, deduplication and health; it cannot silently
  reacquire privacy projection or filesystem/network/process capability in the
  ingress layer.

## Bounds and retention

A scan considers at most 4,096 directory entries, retains at most 512 safe event
files, and prunes only verified safe files older than 36 hours or beyond the
retention cap. An overloaded directory returns the stable
`EVENT_SPOOL_ENTRY_LIMIT_EXCEEDED` status without deleting unknown entries.

## Live health and recovery

The watcher reports root availability on every poll, not only at launch. A
ready-to-unsafe transition produces one content-free integration-disconnected
signal; a successful local repair produces one integration-health signal.
Clicks, games, local media, and scheduled care remain usable. Diagnostics expose
only a stable status code—never a username, event path, task body, prompt, or
upstream identifier. Repair creates or restores the app-owned directory; it does
not overwrite unknown entries.

## Threat boundary

This is defense against accidental links, simple file replacement, broad
permissions, malformed input, stale accumulation, and ordinary local corruption.
It is not origin authentication and does not claim to defeat an active process
running as the same user that can race filesystem calls or modify both an event
and its local evidence. Intermediate parent directories are not attested by this
module. A stronger boundary would require a separately designed authenticated
transport or operating-system isolation.

## Verification

```bash
./scripts/run-event-spool-smoke.sh
python3 scripts/check-event-spool-integration.py
```

The smoke uses temporary directories and verifies valid delivery, unchanged and
restart deduplication, exact-once fresh delivery, unregistered-producer downgrade,
symlink/hard-link/FIFO/permission/size rejection, safe stale and
capacity pruning, overload behavior, path-free codes, and live unhealthy/repair
transitions. The integration and Core-boundary checks also reject missing ingress,
projection re-merge, forbidden ingress capabilities and watcher delegation bypass.
These are source-token regression gates, not compiler AST proof or an
active-adversary certification.

## Release boundary

Passing these checks supports local engineering preview and clone/contribution
claims only. The artifact remains `NOT_PUBLIC_RELEASE_READY` until media rights,
the final license, canonical maintainers, Developer ID signing, notarization,
clean-Mac checks, and owner approval are separately complete.
