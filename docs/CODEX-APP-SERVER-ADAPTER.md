# Codex App Server turn-event adapter

[简体中文](CODEX-APP-SERVER-ADAPTER.zh-Hans.md)

This adapter projects one trusted local Codex App Server turn notification into
Companion Event v1. It owns state semantics and privacy minimization. It does
not start App Server, establish a JSON-RPC connection, modify Codex
configuration, or decide whether a multi-turn user objective is complete.

## Completion truth

| App Server input | Companion output | User meaning |
| --- | --- | --- |
| `turn/started` + `inProgress` | `task.started` | One Codex turn has started |
| `turn/completed` + `completed` | `response.ready` | A new Codex result is ready; the whole task is not proven complete |
| `turn/completed` + `failed` | `task.failed` | This turn failed |
| `turn/completed` + `interrupted` | `task.cancelled` | This turn was interrupted |

Only an explicit task orchestrator, a user action, or a semantically validated
adapter may send `task.completed`. Both source and tests prevent this projection
layer from producing `task.completed` from an App Server turn completion.

## Minimal privacy projection

The adapter reads only `method`, `params.threadId`, `params.turn.id`, `status`,
and optional `durationMs`. The two upstream IDs are used only to reject empty or
malformed input and are then discarded. The event retains no IDs, items, error
text, prompts, answers, working directories, paths, personal data, upstream
timestamps, or unknown fields. The written Companion Event has a fresh local
UUID, a null `taskRef`, empty metadata, and all privacy declarations set to
false.

Input is limited to one 1 MiB notification and duration is limited to 30 days.
The public [minimal projection schema](../Schemas/codex-app-server-turn-events-v1.schema.json)
allows additive upstream fields because the mapper discards them. It is not the
complete App Server protocol or proof of upstream authenticity.

## Local verification

These commands write only to a temporary event directory and do not reach a
running app:

```bash
CHENGYIN_EVENT_ROOT="$(mktemp -d)" swift run --disable-sandbox CompanionEventEmitter codex-app-server '{"method":"turn/completed","params":{"threadId":"local-probe","turn":{"id":"local-turn","status":"completed","durationMs":1200}}}'
./scripts/run-codex-app-server-adapter-smoke.sh
```

The second command checks four statuses, unknown-message ignore behavior, file
permissions, privacy deletion, stable error codes, and recovery actions.

## Integration boundary

The current public artifact provides a single-notification ingress: a trusted
local transport may pass one complete notification as the second argument to
`CompanionEventEmitter codex-app-server`. This release does not include a
resident App Server manager, initialization handshake, reconnection, flow
control, process lifecycle management, or user-level configuration writes. It
must not be described as a complete managed App Server integration.

A real transport must preserve these boundaries:

1. the user opts in and can see the launch command, data scope, and disable path;
2. only one supported turn notification is forwarded and raw JSON is not logged;
3. the transport owns health, reconnection, deduplication, and a bounded queue;
4. unknown methods are quietly ignored while malformed known input gets a stable code;
5. taps, games, scheduled care, and local media remain fully usable while disconnected;
6. internal consistency checks are not described as origin authentication or active-attack protection.

## Failure receipts

Failures use stable `APP_SERVER_EVENT_*` codes and include an executable recovery
action without usernames, absolute paths, or upstream IDs. Covered failures are
malformed JSON, missing structure, method/status disagreement, invalid duration,
and oversized input. A failure writes no partial event and never falls back to
“task complete.”

