#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
AUDITOR="$($SCRIPT_DIR/build-creator-tool.sh archive-audit)"
BUILDER="$SCRIPT_DIR/build-content-pack-archive.sh"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-pack-archive-smoke.XXXXXX")"
FIXTURE_ROOT="$SMOKE_ROOT/fixtures"

cleanup() {
  if [[ -n "${SMOKE_ROOT:-}" \
    && "$SMOKE_ROOT" == "${TMPDIR:-/tmp}"/chengyin-pack-archive-smoke.* \
    && -d "$SMOKE_ROOT" ]]; then
    /bin/rm -rf "$SMOKE_ROOT"
  fi
}
trap cleanup EXIT INT TERM

fail() {
  print -u2 "FAIL  $1"
  exit 1
}

assert_pass() {
  local archive="$1"
  local expected_layout="$2"
  local receipt
  receipt="$("$AUDITOR" "$archive" --json)" || fail "valid archive was rejected"
  RECEIPT="$receipt" EXPECTED_LAYOUT="$expected_layout" python3 -c '
import json, os
r = json.loads(os.environ["RECEIPT"])
assert r["status"] == "PASS", r
assert r["layout"] == os.environ["EXPECTED_LAYOUT"], r
assert r["writesPerformed"] is False, r
assert r["validationScope"] == "zip-structure-manifest-hashes-and-media-decode", r
assert r["releaseState"] == "NOT_PUBLIC_RELEASE_READY", r
assert "/Users/" not in os.environ["RECEIPT"], r
assert "/Volumes/" not in os.environ["RECEIPT"], r
' || fail "valid archive receipt contract failed"
}

assert_failure() {
  local archive="$1"
  local expected_code="$2"
  local receipt
  local command_status
  set +e
  receipt="$("$AUDITOR" "$archive" --json 2>&1)"
  command_status=$?
  set -e
  [[ "$command_status" -eq 1 ]] || fail "negative archive unexpectedly passed"
  RECEIPT="$receipt" EXPECTED_CODE="$expected_code" python3 -c '
import json, os
r = json.loads(os.environ["RECEIPT"])
assert r["status"] == "FAIL", r
assert r["code"] == os.environ["EXPECTED_CODE"], r
assert r["recoveryAction"], r
assert "/Users/" not in os.environ["RECEIPT"], r
assert "/Volumes/" not in os.environ["RECEIPT"], r
' || fail "negative archive lost its stable path-free receipt"
}

PYTHONDONTWRITEBYTECODE=1 python3 "$SCRIPT_DIR/content-pack-archive-fixtures.py" \
  "$PROJECT_DIR/examples/packs/hello-workday" \
  "$FIXTURE_ROOT"

assert_pass "$FIXTURE_ROOT/valid-flat.chengyinpack" flat
assert_pass "$FIXTURE_ROOT/valid-wrapped.chengyinpack" single-root
assert_failure "$FIXTURE_ROOT/traversal.chengyinpack" PACK_ARCHIVE_UNSAFE_ENTRY
assert_failure "$FIXTURE_ROOT/symlink.chengyinpack" PACK_ARCHIVE_UNSUPPORTED_FEATURE
assert_failure "$FIXTURE_ROOT/duplicate.chengyinpack" PACK_ARCHIVE_UNSAFE_ENTRY
assert_failure "$FIXTURE_ROOT/case-collision.chengyinpack" PACK_ARCHIVE_UNSAFE_ENTRY
assert_failure "$FIXTURE_ROOT/local-header-mismatch.chengyinpack" PACK_ARCHIVE_UNSAFE_ENTRY
assert_failure "$FIXTURE_ROOT/encrypted.chengyinpack" PACK_ARCHIVE_UNSUPPORTED_FEATURE
assert_failure "$FIXTURE_ROOT/unsupported-method.chengyinpack" PACK_ARCHIVE_UNSUPPORTED_FEATURE
assert_failure "$FIXTURE_ROOT/oversized-entry.chengyinpack" PACK_ARCHIVE_RESOURCE_LIMIT
assert_failure "$FIXTURE_ROOT/compression-bomb.chengyinpack" PACK_ARCHIVE_RESOURCE_LIMIT
assert_failure "$FIXTURE_ROOT/missing-manifest.chengyinpack" PACK_ARCHIVE_PACKAGE_ROOT_MISSING
assert_failure "$FIXTURE_ROOT/corrupt.chengyinpack" PACK_ARCHIVE_INVALID_ZIP

built="$SMOKE_ROOT/built.chengyinpack"
build_receipt="$($BUILDER \
  "$PROJECT_DIR/examples/packs/hello-workday" \
  "$built" \
  --json)" || fail "archive builder rejected the valid example"
BUILD_RECEIPT="$build_receipt" python3 -c '
import json, os
r = json.loads(os.environ["BUILD_RECEIPT"])
assert r["status"] == "PASS", r
assert r["writesPerformed"] is True, r
assert len(r["archiveSHA256"]) == 64, r
assert r["releaseState"] == "NOT_PUBLIC_RELEASE_READY", r
assert "/Users/" not in os.environ["BUILD_RECEIPT"], r
assert "/Volumes/" not in os.environ["BUILD_RECEIPT"], r
' || fail "archive build receipt contract failed"
assert_pass "$built" flat

set +e
overwrite_receipt="$($BUILDER \
  "$PROJECT_DIR/examples/packs/hello-workday" \
  "$built" \
  --json 2>&1)"
overwrite_status=$?
set -e
[[ "$overwrite_status" -eq 1 ]] || fail "builder overwrote an existing archive"
OVERWRITE_RECEIPT="$overwrite_receipt" python3 -c '
import json, os
r = json.loads(os.environ["OVERWRITE_RECEIPT"])
assert r["code"] == "PACK_ARCHIVE_BUILD_INVALID_TARGET", r
assert r["writesPerformed"] is False, r
' || fail "overwrite rejection lost its stable receipt"

print "Content-pack archive smoke: PASS (16/16)"
