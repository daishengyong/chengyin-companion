#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-first-use-visual-smoke.XXXXXX")"
DRIVER_BIN="$SMOKE_ROOT/english-first-use-visual-audit"

source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"

cleanup() {
  if [[ -n "${SMOKE_ROOT:-}" \
    && "$SMOKE_ROOT" == "${TMPDIR:-/tmp}"/chengyin-first-use-visual-smoke.* \
    && -d "$SMOKE_ROOT" ]]; then
    /bin/rm -rf "$SMOKE_ROOT"
  fi
}
trap cleanup EXIT INT TERM

passed=0
check() {
  local label="$1"
  shift
  if "$@"; then
    passed=$((passed + 1))
    print "PASS  $label"
  else
    print -u2 "FAIL  $label"
    exit 1
  fi
}

source_receipt="$($PROJECT_DIR/scripts/run-english-first-use-visual-audit.sh --source-only)"
SOURCE_RECEIPT="$source_receipt" check "source-only receipt preserves pending owner gates" python3 - <<'PY'
import json, os
value = json.loads(os.environ["SOURCE_RECEIPT"])
assert value["status"] == "PASS_WITH_PENDING", value
assert value["environment"] == "SOURCE_ONLY", value
assert value["runtimeAccessibility"] == "PENDING_GUI_RUN", value
assert value["humanVoiceOverAudit"] == "PENDING_HUMAN_REVIEW", value
assert value["physicalCleanMacAudit"] == "PENDING_EXTERNAL_DEVICE", value
assert value["releaseState"] == "NOT_PUBLIC_RELEASE_READY", value
assert "human_review_required" in value["proofStrength"], value
encoded = json.dumps(value)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, value
PY

set +e
"$PROJECT_DIR/scripts/run-english-first-use-visual-audit.sh" --unknown \
  >"$SMOKE_ROOT/unknown.out" 2>"$SMOKE_ROOT/unknown.err"
unknown_status=$?
set -e
check "wrapper rejects an unknown option" test "$unknown_status" -eq 2

check "Swift visual driver typechecks" \
  xcrun swiftc -typecheck "$PROJECT_DIR/scripts/english-first-use-visual-audit.swift"
xcrun swiftc "$PROJECT_DIR/scripts/english-first-use-visual-audit.swift" -o "$DRIVER_BIN"
set +e
driver_receipt="$($DRIVER_BIN 2>/dev/null)"
driver_status=$?
set -e
DRIVER_RECEIPT="$driver_receipt" DRIVER_STATUS="$driver_status" \
  check "driver returns a stable invalid-argument receipt" python3 - <<'PY'
import json, os
value = json.loads(os.environ["DRIVER_RECEIPT"])
assert int(os.environ["DRIVER_STATUS"]) == 1
assert value["status"] == "FAIL", value
assert value["code"] == "FIRST_USE_VISUAL_AUDIT_INVALID_ARGUMENT", value
assert value["recoveryAction"], value
assert value["releaseState"] == "NOT_PUBLIC_RELEASE_READY", value
PY

check "machine integration contract" \
  python3 "$PROJECT_DIR/scripts/check-english-first-use-audit-integration.py"

SCHEMA="$PROJECT_DIR/Schemas/english-first-use-visual-audit-v1.schema.json" \
  check "schema locks truthful evidence boundaries" python3 - <<'PY'
import json, os
schema = json.load(open(os.environ["SCHEMA"], encoding="utf-8"))
props = schema["properties"]
assert schema["additionalProperties"] is False
assert props["status"]["enum"] == ["PASS_WITH_PENDING", "FAIL"]
assert props["humanVoiceOverAudit"]["const"] == "PENDING_HUMAN_REVIEW"
assert props["physicalCleanMacAudit"]["const"] == "PENDING_EXTERNAL_DEVICE"
assert props["releaseState"]["const"] == "NOT_PUBLIC_RELEASE_READY"
assert props["steps"]["maxItems"] == 5
assert schema["allOf"][0]["then"]["properties"]["proofStrength"]["pattern"] == "human_review_required"
PY

check "runtime root isolation matrix" \
  "$PROJECT_DIR/scripts/run-runtime-environment-smoke.sh"

print "English first-use visual audit smoke: PASS ($passed/7)"
