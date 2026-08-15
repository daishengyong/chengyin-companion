#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE 2>/dev/null || true

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
RUNNER="$PROJECT_DIR/scripts/check-contribution.py"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-contributor-check-smoke.XXXXXX")"

cleanup() {
  if [[ -n "${SMOKE_ROOT:-}" \
    && "$SMOKE_ROOT" == "${TMPDIR:-/tmp}"/chengyin-contributor-check-smoke.* \
    && -d "$SMOKE_ROOT" ]]; then
    /bin/rm -rf "$SMOKE_ROOT"
  fi
}
trap cleanup EXIT INT TERM

fail() {
  print -u2 "FAIL  $1"
  exit 1
}

assert_private_path_free() {
  local value="$1"
  [[ "$value" != *"/Users/"* \
    && "$value" != *"/Volumes/"* \
    && "$value" != *"/private/tmp/"* ]] \
    || fail "receipt exposed a private absolute path"
}

PYTHONDONTWRITEBYTECODE=1 python3 -m json.tool \
  "$PROJECT_DIR/Schemas/contributor-check-receipt-v1.schema.json" \
  >/dev/null || fail "contributor receipt schema is not valid JSON"

set +e
INVALID_RECEIPT="$(PYTHONDONTWRITEBYTECODE=1 "$RUNNER" \
  --profile unsupported --json)"
INVALID_STATUS=$?
set -e
[[ "$INVALID_STATUS" -eq 1 ]] || fail "unsupported profile was accepted"
assert_private_path_free "$INVALID_RECEIPT"
SOURCE_RECEIPT="$INVALID_RECEIPT" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["SOURCE_RECEIPT"])
assert receipt["status"] == "FAIL", receipt
assert receipt["profile"] == "unknown", receipt
assert receipt["code"] == "CONTRIBUTOR_CHECK_INVALID_ARGUMENT", receipt
assert receipt["checks"] == [], receipt
assert receipt["recoveryAction"], receipt
PY

set +e
MISSING_PACK_RECEIPT="$(PYTHONDONTWRITEBYTECODE=1 "$RUNNER" \
  --profile pack --json)"
MISSING_PACK_STATUS=$?
set -e
[[ "$MISSING_PACK_STATUS" -eq 1 ]] || fail "pack profile without a pack was accepted"
assert_private_path_free "$MISSING_PACK_RECEIPT"
SOURCE_RECEIPT="$MISSING_PACK_RECEIPT" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["SOURCE_RECEIPT"])
assert receipt["status"] == "FAIL", receipt
assert receipt["profile"] == "pack", receipt
assert receipt["code"] == "CONTRIBUTOR_CHECK_PACK_REQUIRED", receipt
assert receipt["recoveryAction"], receipt
PY

QUICK_RECEIPT="$(PYTHONDONTWRITEBYTECODE=1 "$RUNNER" \
  --profile quick --json)" || fail "valid quick profile failed"
assert_private_path_free "$QUICK_RECEIPT"
SOURCE_RECEIPT="$QUICK_RECEIPT" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["SOURCE_RECEIPT"])
assert receipt["status"] == "PASS", receipt
assert receipt["profile"] == "quick", receipt
assert receipt["networkRequired"] is False, receipt
assert receipt["authoritativeSourceMutation"] is False, receipt
assert receipt["releaseState"] == "NOT_PUBLIC_RELEASE_READY", receipt
assert receipt["passedCount"] == len(receipt["checks"]), receipt
assert receipt["passedCount"] >= 20, receipt
assert receipt["failedCount"] == 0 and receipt["skippedCount"] == 0, receipt
assert receipt["code"] is None and receipt["recoveryAction"] is None, receipt
assert all(item["status"] == "PASS" for item in receipt["checks"]), receipt
assert "module-stewardship" in {item["id"] for item in receipt["checks"]}, receipt
assert "app-server-adapter" in {item["id"] for item in receipt["checks"]}, receipt
assert "event-spool-security" in {item["id"] for item in receipt["checks"]}, receipt
assert "shared-day-lifecycle" in {item["id"] for item in receipt["checks"]}, receipt
assert "local-preview-contract" in {item["id"] for item in receipt["checks"]}, receipt
assert "game-reward-audit-integration" in {item["id"] for item in receipt["checks"]}, receipt
assert "game-reward-receipt-matrix" in {item["id"] for item in receipt["checks"]}, receipt
assert "microgame-window-policy" in {item["id"] for item in receipt["checks"]}, receipt
assert "content-pack-scaffold" in {item["id"] for item in receipt["checks"]}, receipt
assert "content-pack-locale-matrix" in {item["id"] for item in receipt["checks"]}, receipt
assert "content-pack-validator-modularity" in {item["id"] for item in receipt["checks"]}, receipt
assert "public-source-secret-audit" in {item["id"] for item in receipt["checks"]}, receipt
assert "product-boundary" in {item["id"] for item in receipt["checks"]}, receipt
PY

PACK_RECEIPT="$(PYTHONDONTWRITEBYTECODE=1 "$RUNNER" \
  --profile pack \
  --pack "$PROJECT_DIR/examples/packs/hello-workday" \
  --json)" || fail "strict example pack contribution profile failed"
assert_private_path_free "$PACK_RECEIPT"
SOURCE_RECEIPT="$PACK_RECEIPT" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["SOURCE_RECEIPT"])
assert receipt["status"] == "PASS", receipt
assert receipt["profile"] == "pack", receipt
assert receipt["passedCount"] == 4, receipt
assert receipt["failedCount"] == 0 and receipt["skippedCount"] == 0, receipt
assert [item["id"] for item in receipt["checks"]] == [
    "pack-validate", "pack-strict-audit", "pack-locale-matrix", "pack-offline-preview"
], receipt
PY

mkdir -p "$SMOKE_ROOT/broken-pack"
set +e
BROKEN_RECEIPT="$(PYTHONDONTWRITEBYTECODE=1 "$RUNNER" \
  --profile pack \
  --pack "$SMOKE_ROOT/broken-pack" \
  --json)"
BROKEN_STATUS=$?
set -e
[[ "$BROKEN_STATUS" -eq 1 ]] || fail "broken pack was accepted"
assert_private_path_free "$BROKEN_RECEIPT"
SOURCE_RECEIPT="$BROKEN_RECEIPT" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["SOURCE_RECEIPT"])
assert receipt["status"] == "FAIL", receipt
assert receipt["code"] == "CONTRIBUTOR_CHECK_FAILED", receipt
assert receipt["failedCount"] == 1, receipt
assert receipt["skippedCount"] == 3, receipt
assert receipt["checks"][0]["id"] == "pack-validate", receipt
assert receipt["checks"][0]["status"] == "FAIL", receipt
assert all(item["status"] == "SKIP" for item in receipt["checks"][1:]), receipt
assert "<pack-directory>" in receipt["recoveryAction"], receipt
PY

print "Contributor check smoke: PASS (6/6)"
print "Release state: NOT_PUBLIC_RELEASE_READY"
