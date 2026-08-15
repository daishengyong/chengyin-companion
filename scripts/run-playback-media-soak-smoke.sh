#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"

SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-playback-soak-smoke.XXXXXX")"
SOAK_BIN="$SMOKE_ROOT/playback-media-soak"
cleanup() {
  if [[ "$SMOKE_ROOT" == "${TMPDIR:-/tmp}"/chengyin-playback-soak-smoke.* \
    && -d "$SMOKE_ROOT" ]]; then
    rm -rf "$SMOKE_ROOT"
  fi
}
trap cleanup EXIT INT TERM

fail() {
  print -u2 "FAIL  playback media soak: $1"
  exit 1
}

xcrun swiftc \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionPlaybackHealth.swift" \
  "$PROJECT_DIR/scripts/playback-media-soak.swift" \
  -o "$SOAK_BIN"

set +e
valid_receipt="$(CHENGYIN_ALLOW_RESTRICTED_DECODE_PENDING=1 $SOAK_BIN \
  --media-root "$PROJECT_DIR/Sources/CompanionApp/Resources" \
  --duration-seconds 1 \
  --max-growth-mb 256 \
  --max-first-frame-ms 1000)"
valid_status=$?
set -e
valid_retry_used=0
valid_pending=0
if [[ "$valid_status" -ne 0 ]] \
  && SOAK_RECEIPT="$valid_receipt" python3 - <<'PY'
import json, os
try:
    receipt = json.loads(os.environ["SOAK_RECEIPT"])
except Exception:
    raise SystemExit(1)
raise SystemExit(0 if receipt.get("code") == "PLAYBACK_SOAK_FIRST_FRAME_SLOW" else 1)
PY
then
  # A freshly extracted source tree may pay AVFoundation's one-time decoder
  # startup while the machine is also compiling the isolated package. Retry
  # exactly once to exercise the app-equivalent prewarmed path; repeatable
  # latency, decode and memory failures still fail the gate.
  valid_retry_used=1
  set +e
  valid_receipt="$(CHENGYIN_ALLOW_RESTRICTED_DECODE_PENDING=1 $SOAK_BIN \
    --media-root "$PROJECT_DIR/Sources/CompanionApp/Resources" \
    --duration-seconds 1 \
    --max-growth-mb 256 \
    --max-first-frame-ms 1000)"
  valid_status=$?
  set -e
fi
if [[ "$valid_status" -eq 2 ]]; then
  SOAK_RECEIPT="$valid_receipt" python3 - <<'PY'
import json, os
r = json.loads(os.environ["SOAK_RECEIPT"])
assert r["status"] == "PENDING", r
assert r["code"] == "PLAYBACK_SOAK_AVFOUNDATION_RESTRICTED", r
assert r["proofKind"] == "NO_DECODE_PROOF_RESTRICTED_SANDBOX", r
assert r["releaseSoakSatisfied"] is False, r
assert r["attempts"] > 0 and r["decodedFrames"] == 0, r
assert r.get("firstFrameP95Milliseconds") is None, r
assert r["recoveryAction"], r
assert "/Users/" not in json.dumps(r) and "/Volumes/" not in json.dumps(r), r
PY
  valid_pending=1
elif [[ "$valid_status" -ne 0 ]]; then
  SOAK_RECEIPT="$valid_receipt" python3 - <<'PY' >&2
import json, os
try:
    r = json.loads(os.environ["SOAK_RECEIPT"])
except Exception:
    print("FAIL  playback media soak: valid probe returned no readable receipt")
    raise SystemExit(0)
print(
    "FAIL  playback media soak: valid probe "
    f"code={r.get('code')} attempts={r.get('attempts')} "
    f"decodedFrames={r.get('decodedFrames')} "
    f"p95ms={r.get('firstFrameP95Milliseconds')} "
    f"targetMs={r.get('firstFrameTargetMilliseconds')} "
    f"peakGrowthMB={r.get('peakGrowthMB')}"
)
PY
  exit 1
else
  SOAK_RECEIPT="$valid_receipt" python3 - <<'PY'
import json, os
r = json.loads(os.environ["SOAK_RECEIPT"])
assert r["status"] == "PASS", r
assert r["proofKind"] == "HEADLESS_AVFOUNDATION_DECODE", r
assert r["scope"] == "short-probe", r
assert r["releaseSoakSatisfied"] is False, r
assert r["attempts"] > 0 and r["decodedFrames"] >= r["attempts"], r
assert r["mediaCount"] > 0 and r["firstFrameP95Milliseconds"] is not None, r
assert "/Users/" not in json.dumps(r) and "/Volumes/" not in json.dumps(r), r
PY
fi

mkdir -p "$SMOKE_ROOT/empty"
set +e
missing_receipt="$($SOAK_BIN \
  --media-root "$SMOKE_ROOT/empty" \
  --duration-seconds 1)"
missing_status=$?
set -e
[[ "$missing_status" -eq 1 ]] || fail "empty media root did not exit 1"
SOAK_RECEIPT="$missing_receipt" python3 - <<'PY'
import json, os
r = json.loads(os.environ["SOAK_RECEIPT"])
assert r["status"] == "FAIL" and r["code"] == "PLAYBACK_SOAK_MEDIA_MISSING", r
assert r["recoveryAction"] and "/Users/" not in json.dumps(r), r
PY

mkdir -p "$SMOKE_ROOT/corrupt"
print -r -- "not a video" > "$SMOKE_ROOT/corrupt/broken.mov"
set +e
corrupt_receipt="$($SOAK_BIN \
  --media-root "$SMOKE_ROOT/corrupt" \
  --duration-seconds 1)"
corrupt_status=$?
set -e
[[ "$corrupt_status" -eq 1 ]] || fail "corrupt media did not exit 1"
SOAK_RECEIPT="$corrupt_receipt" python3 - <<'PY'
import json, os
r = json.loads(os.environ["SOAK_RECEIPT"])
assert r["status"] == "FAIL" and r["code"] == "PLAYBACK_SOAK_DECODE_FAILED", r
assert r["attempts"] > 0 and r["releaseSoakSatisfied"] is False, r
assert "broken.mov" not in json.dumps(r), r
PY

set +e
argument_receipt="$($SOAK_BIN --duration-seconds nope)"
argument_status=$?
set -e
[[ "$argument_status" -eq 1 ]] || fail "invalid arguments did not exit 1"
SOAK_RECEIPT="$argument_receipt" python3 - <<'PY'
import json, os
r = json.loads(os.environ["SOAK_RECEIPT"])
assert r["status"] == "FAIL" and r["code"] == "PLAYBACK_SOAK_ARGUMENT_INVALID", r
assert r["scope"] == "not-started" and r["recoveryAction"], r
PY

if [[ "$valid_pending" -eq 1 ]]; then
  print "Playback media soak smoke: PASS_WITH_PENDING (4/4, AVFoundation decode proof pending outside restricted sandbox)"
elif [[ "$valid_retry_used" -eq 1 ]]; then
  print "Playback media soak smoke: PASS (4/4, one bounded cold-start retry)"
else
  print "Playback media soak smoke: PASS (4/4)"
fi
