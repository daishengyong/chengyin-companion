#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_dir="${script_dir:h}"
fixture="$repo_dir/Tests/Fixtures/invalid-content-pack"
expected_code="PACK_VALIDATION_MANIFEST_INVALID_JSON"

validate_json_failure() {
  local command="$1"
  local receipt
  local exit_code
  set +e
  receipt="$($command "$fixture" --json 2>&1)"
  exit_code=$?
  set -e
  if [[ "$exit_code" -ne 1 ]]; then
    print -u2 "FAIL  $command returned $exit_code instead of 1"
    return 1
  fi
  CREATOR_FAILURE_RECEIPT="$receipt" EXPECTED_CODE="$expected_code" python3 -c '
import json, os
receipt = json.loads(os.environ["CREATOR_FAILURE_RECEIPT"])
assert receipt["code"] == os.environ["EXPECTED_CODE"], receipt
assert receipt["message"] == "manifest.json is not valid Content Pack JSON.", receipt
assert receipt["status"] == "FAIL", receipt
assert "validate-content-pack.sh" in receipt["recoveryAction"] or "audit-content-pack.sh" in receipt["recoveryAction"], receipt
serialized = json.dumps(receipt)
assert "/Users/" not in serialized and "/Volumes/" not in serialized, receipt
'
}

validate_json_failure "$repo_dir/scripts/validate-content-pack.sh"
validate_json_failure "$repo_dir/scripts/audit-content-pack.sh"

preview_output="$(mktemp "${TMPDIR:-/tmp}/chengyin-invalid-preview.XXXXXX.html")"
preview_log="$(mktemp "${TMPDIR:-/tmp}/chengyin-invalid-preview.XXXXXX.log")"
trap 'rm -f "$preview_output" "$preview_log"' EXIT INT TERM
set +e
"$repo_dir/scripts/preview-content-pack.sh" \
  "$fixture" \
  --output "$preview_output" \
  --no-open \
  >"$preview_log" 2>&1
preview_status=$?
set -e
if [[ "$preview_status" -ne 1 ]]; then
  print -u2 "FAIL  preview returned $preview_status instead of 1"
  exit 1
fi
grep -Fq "[$expected_code]" "$preview_log"
grep -Fq "ACTION" "$preview_log"

print "Creator error receipt smoke checks passed (3/3)."
