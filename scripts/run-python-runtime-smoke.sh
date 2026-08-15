#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
CHECKER="$SCRIPT_DIR/check-python-runtime.sh"

fail() {
  print -u2 "FAIL  $1"
  exit 1
}

assert_receipt() {
  local receipt="$1"
  local expected_status="$2"
  local expected_code="$3"
  RECEIPT="$receipt" EXPECTED_STATUS="$expected_status" EXPECTED_CODE="$expected_code" \
    PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import json
import os

receipt = json.loads(os.environ["RECEIPT"])
assert receipt["contract"] == "chengyin.python-runtime/v1", receipt
assert receipt["schemaVersion"] == 1, receipt
assert receipt["status"] == os.environ["EXPECTED_STATUS"], receipt
expected_code = os.environ["EXPECTED_CODE"] or None
assert receipt["code"] == expected_code, receipt
assert receipt["minimumVersion"] == "3.9", receipt
encoded = json.dumps(receipt)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, receipt
PY
}

actual_receipt="$($CHECKER --json)"
assert_receipt "$actual_receipt" PASS ""
print "PASS  Current Python runtime"

minimum_receipt="$($CHECKER --json --check-version 3.9.0)"
assert_receipt "$minimum_receipt" PASS ""
print "PASS  Exact minimum version"

future_receipt="$($CHECKER --json --check-version 3.99.1)"
assert_receipt "$future_receipt" PASS ""
print "PASS  Newer compatible version"

set +e
old_receipt="$($CHECKER --json --check-version 3.8.99)"
old_status=$?
set -e
[[ "$old_status" -eq 1 ]] || fail "Python 3.8 fixture was accepted"
assert_receipt "$old_receipt" FAIL SOURCE_BOOTSTRAP_PYTHON_UNSUPPORTED
print "PASS  Python 3.8 rejection"

set +e
invalid_receipt="$($CHECKER --json --check-version not-a-version)"
invalid_status=$?
set -e
[[ "$invalid_status" -eq 1 ]] || fail "invalid Python version was accepted"
assert_receipt "$invalid_receipt" FAIL SOURCE_BOOTSTRAP_PYTHON_UNAVAILABLE
print "PASS  Invalid version rejection"

set +e
missing_receipt="$($CHECKER --json --command chengyin-python-command-does-not-exist)"
missing_status=$?
set -e
[[ "$missing_status" -eq 1 ]] || fail "missing Python command was accepted"
assert_receipt "$missing_receipt" FAIL SOURCE_BOOTSTRAP_PYTHON_UNAVAILABLE
print "PASS  Missing interpreter rejection"

set +e
argument_receipt="$($CHECKER --json --unknown-option)"
argument_status=$?
set -e
[[ "$argument_status" -eq 1 ]] || fail "unknown checker option was accepted"
assert_receipt "$argument_receipt" FAIL SOURCE_BOOTSTRAP_INVALID_ARGUMENT
print "PASS  Invalid argument rejection"

print "Python runtime contract smoke: PASS (7/7)"
