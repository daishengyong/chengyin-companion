#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_dir="${script_dir:h}"
source "$repo_dir/scripts/swift-toolchain-env.sh"
source "$repo_dir/scripts/swift-build-cache.sh"
adapter_build_root="$(chengyin_swift_build_root "$repo_dir" app-server-adapter)"

smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-app-server-adapter.XXXXXX")"
event_root="$smoke_root/events"
mkdir -p "$event_root"

cleanup() {
  rm -rf "$smoke_root"
}
trap cleanup EXIT INT TERM

swift build \
  --build-path "$adapter_build_root" \
  --disable-sandbox \
  --product CompanionEventEmitter \
  >/dev/null
bin_dir="$(swift build \
  --build-path "$adapter_build_root" \
  --disable-sandbox \
  --show-bin-path)"
emitter="$bin_dir/CompanionEventEmitter"
[[ -x "$emitter" ]] || {
  print -u2 "FAIL  CompanionEventEmitter was not built."
  exit 1
}

emit() {
  CHENGYIN_EVENT_ROOT="$event_root" "$emitter" codex-app-server "$1"
}

emit '{"method":"turn/started","params":{"threadId":"private-thread-a","turn":{"id":"private-turn-a","status":"inProgress","items":[{"text":"private-start-prompt"}],"cwd":"/Users/private/project"}}}' >/dev/null
emit '{"method":"turn/completed","params":{"threadId":"private-thread-b","turn":{"id":"private-turn-b","status":"completed","durationMs":1200,"items":[{"text":"private-answer"}]}}}' >/dev/null
emit '{"method":"turn/completed","params":{"threadId":"private-thread-c","turn":{"id":"private-turn-c","status":"failed","durationMs":1300,"error":{"message":"private-error"}}}}' >/dev/null
emit '{"method":"turn/completed","params":{"threadId":"private-thread-d","turn":{"id":"private-turn-d","status":"interrupted","durationMs":1400}}}' >/dev/null

before_ignored="$(find "$event_root" -type f -name '*.json' | wc -l | tr -d ' ')"
ignored_output="$(emit '{"method":"item/started","params":{"private":"secret"}}')"
after_ignored="$(find "$event_root" -type f -name '*.json' | wc -l | tr -d ' ')"
[[ "$before_ignored" == "4" && "$after_ignored" == "4" \
  && "$ignored_output" == "Ignored unsupported App Server notification." ]] || {
  print -u2 "FAIL  Unsupported notification was not ignored without side effects."
  exit 1
}

EVENT_ROOT="$event_root" python3 - <<'PY'
import json
import os
import pathlib
import stat
import uuid

root = pathlib.Path(os.environ["EVENT_ROOT"])
assert stat.S_IMODE(root.stat().st_mode) == 0o700
paths = sorted(root.glob("*.json"))
assert len(paths) == 4, len(paths)
events = []
serialized = ""
for path in paths:
    assert not path.is_symlink()
    assert stat.S_IMODE(path.stat().st_mode) == 0o600
    raw = path.read_text(encoding="utf-8")
    serialized += raw
    event = json.loads(raw)
    uuid.UUID(event["eventId"])
    assert event["source"] == "codex-app-server"
    assert event["sourceVersion"] == "turn-events-v1"
    assert event.get("taskRef") is None
    assert event["metadata"] == {}
    assert not any(event["privacy"].values())
    events.append(event)

types = sorted(event["type"] for event in events)
assert types == ["response.ready", "task.cancelled", "task.failed", "task.started"], types
assert "task.completed" not in types
by_type = {event["type"]: event for event in events}
assert by_type["response.ready"].get("outcome") is None
assert by_type["task.failed"]["outcome"] == "failure"
assert by_type["task.cancelled"]["outcome"] == "cancelled"
assert by_type["task.started"].get("durationMs") is None

for private_value in (
    "private-thread",
    "private-turn",
    "private-start-prompt",
    "private-answer",
    "private-error",
    "/Users/private/project",
):
    assert private_value not in serialized, private_value
PY

assert_failure() {
  local expected_code="$1"
  local payload="$2"
  local before_count after_count exit_code receipt
  before_count="$(find "$event_root" -type f -name '*.json' | wc -l | tr -d ' ')"
  set +e
  receipt="$(emit "$payload" 2>&1)"
  exit_code=$?
  set -e
  after_count="$(find "$event_root" -type f -name '*.json' | wc -l | tr -d ' ')"
  [[ "$exit_code" -eq 2 \
    && "$before_count" == "$after_count" \
    && "$receipt" == *"FAIL [$expected_code]"* \
    && "$receipt" == *"ACTION "* \
    && "$receipt" != *"/Users/"* \
    && "$receipt" != *"private-thread"* ]] || {
    print -u2 "FAIL  $expected_code did not produce a privacy-safe stable failure."
    exit 1
  }
}

assert_failure \
  "APP_SERVER_EVENT_INVALID_JSON" \
  '{not-json'
assert_failure \
  "APP_SERVER_EVENT_INVALID_ENVELOPE" \
  '{"method":"turn/started","params":{}}'
assert_failure \
  "APP_SERVER_EVENT_INVALID_STATUS" \
  '{"method":"turn/completed","params":{"threadId":"private-thread","turn":{"id":"x","status":"inProgress"}}}'
assert_failure \
  "APP_SERVER_EVENT_INVALID_DURATION" \
  '{"method":"turn/completed","params":{"threadId":"t","turn":{"id":"x","status":"completed","durationMs":-1}}}'

print "Codex App Server adapter smoke: PASS (4 events + ignore + 4 stable failures)"
