#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
AUDITOR="$PROJECT_DIR/scripts/audit-product-boundary.py"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-product-boundary.XXXXXX")"

cleanup() {
  if [[ -n "${SMOKE_ROOT:-}" \
    && "$SMOKE_ROOT" == "${TMPDIR:-/tmp}"/chengyin-product-boundary.* \
    && -d "$SMOKE_ROOT" ]]; then
    /bin/rm -rf "$SMOKE_ROOT"
  fi
}
trap cleanup EXIT INT TERM

fail() {
  print -u2 "FAIL  product boundary smoke: $1"
  exit 1
}

make_public_fixture() {
  local root="$SMOKE_ROOT/public-base"
  mkdir -p "$root/Sources/App" "$root/docs"
  print -r -- '// fixture package' >"$root/Package.swift"
  print -r -- '<?xml version="1.0"?><plist><dict></dict></plist>' >"$root/Info.plist"
  print -r -- 'import Foundation' >"$root/Sources/App/App.swift"
  print -r -- '# Product boundary' >"$root/docs/PRODUCT-BOUNDARY.md"
  print -r -- '# 产品边界' >"$root/docs/PRODUCT-BOUNDARY.zh-Hans.md"
  print -r -- '# Fixture' >"$root/README.md"
  print -r -- "$root"
}

clone_case() {
  local base="$1"
  local name="$2"
  local root="$SMOKE_ROOT/$name"
  ditto "$base" "$root"
  print -r -- "$root"
}

expect_failure() {
  local expected="$1"
  local root="$2"
  local receipt="$SMOKE_ROOT/$expected.json"
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" \
    --root "$root" --scope public --json >"$receipt"
  local exit_status=$?
  set -e
  [[ "$exit_status" -eq 1 ]] || fail "$expected did not fail"
  python3 - "$receipt" "$expected" "$SMOKE_ROOT" <<'PY'
import json, pathlib, sys
r=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert r["status"] == "FAIL", r
assert r["code"] == sys.argv[2], r
assert r["recoveryAction"], r
assert r["networkRequired"] is False, r
assert r["environmentValuesRead"] is False, r
assert r["applicationsDirectoryModified"] is False, r
assert r["contentExcerptsIncluded"] is False, r
encoded=json.dumps(r, ensure_ascii=False)
assert sys.argv[3] not in encoded, r
assert "/Users/" not in encoded and "/Volumes/" not in encoded, r
PY
}

current_scope="public"
current_research_state="excluded"
if [[ -d "$PROJECT_DIR/video-production/research/commercialization" ]]; then
  current_scope="development"
  current_research_state="private-working-copy"
fi
PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" \
  --root "$PROJECT_DIR" --scope "$current_scope" --json >"$SMOKE_ROOT/current.json"
python3 - "$SMOKE_ROOT/current.json" "$current_research_state" <<'PY'
import json, pathlib, sys
r=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert r["contract"] == "chengyin.product-boundary/v1", r
assert r["status"] == "PASS" and r["code"] is None, r
assert r["historicalResearchState"] == sys.argv[2], r
assert r["policy"] == {
    "advertising": False,
    "automaticSharing": False,
    "forcedAccount": False,
    "manualLocalExport": True,
    "monetization": False,
}, r
PY

base="$(make_public_fixture)"
PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" \
  --root "$base" --scope public --json >"$SMOKE_ROOT/public.json"
python3 - "$SMOKE_ROOT/public.json" <<'PY'
import json, pathlib, sys
r=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert r["status"] == "PASS" and r["code"] is None, r
assert r["historicalResearchState"] == "excluded", r
assert r["forbiddenFindingCount"] == 0 and r["findings"] == [], r
PY

payment="$(clone_case "$base" payment)"
print -r -- 'import StoreKit' >>"$payment/Sources/App/App.swift"
expect_failure PRODUCT_BOUNDARY_FORBIDDEN_RUNTIME "$payment"

account="$(clone_case "$base" account)"
print -r -- 'import AuthenticationServices' >>"$account/Sources/App/App.swift"
expect_failure PRODUCT_BOUNDARY_FORBIDDEN_RUNTIME "$account"

advertising="$(clone_case "$base" advertising)"
print -r -- 'import AppTrackingTransparency' >>"$advertising/Sources/App/App.swift"
expect_failure PRODUCT_BOUNDARY_FORBIDDEN_RUNTIME "$advertising"

sharing="$(clone_case "$base" automatic-sharing)"
print -r -- 'let autoShareEnabled = true' >>"$sharing/Sources/App/App.swift"
expect_failure PRODUCT_BOUNDARY_FORBIDDEN_RUNTIME "$sharing"

leak="$(clone_case "$base" historical-leak)"
print -r -- '# superseded fixture' >"$leak/docs/COMMERCIAL-MASTER-PLAN.md"
expect_failure PRODUCT_BOUNDARY_PUBLIC_DOC_LEAK "$leak"

reference="$(clone_case "$base" historical-reference)"
print -r -- '[old](docs/PAYMENT-DECISION-CN.md)' >>"$reference/README.md"
expect_failure PRODUCT_BOUNDARY_PUBLIC_DOC_LEAK "$reference"

set +e
PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" --future --json >"$SMOKE_ROOT/unknown.json"
unknown_status=$?
set -e
[[ "$unknown_status" -eq 1 ]] || fail "unknown option did not fail"
python3 - "$SMOKE_ROOT/unknown.json" <<'PY'
import json, pathlib, sys
r=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert r["code"] == "PRODUCT_BOUNDARY_UNKNOWN_OPTION", r
assert r["recoveryAction"], r
assert "/Users/" not in json.dumps(r), r
PY

PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" --help >"$SMOKE_ROOT/help.txt"
grep -Fq 'Usage: python3 scripts/audit-product-boundary.py' "$SMOKE_ROOT/help.txt" \
  || fail "help contract is missing"

python3 -m json.tool \
  "$PROJECT_DIR/Schemas/product-boundary-receipt-v1.schema.json" >/dev/null \
  || fail "receipt schema is invalid"

print "Product boundary smoke: PASS (10/10)"
