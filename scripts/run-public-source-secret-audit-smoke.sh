#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
AUDITOR="$PROJECT_DIR/scripts/audit-public-source-secrets.py"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-secret-audit.XXXXXX")"

cleanup() {
  if [[ -n "${SMOKE_ROOT:-}" \
    && "$SMOKE_ROOT" == "${TMPDIR:-/tmp}"/chengyin-secret-audit.* \
    && -d "$SMOKE_ROOT" ]]; then
    /bin/rm -rf "$SMOKE_ROOT"
  fi
}
trap cleanup EXIT INT TERM

fail() {
  print -u2 "FAIL  public source secret audit: $1"
  exit 1
}

make_case() {
  local name="$1"
  local root="$SMOKE_ROOT/$name"
  mkdir -p "$root/Sources" "$root/scripts" "$root/video-production"
  print -r -- '# fixture' >"$root/README.md"
  print -r -- 'let keyName = "ARK_API_KEY"' >"$root/Sources/App.swift"
  print -r -- 'ARK_API_KEY=your_key_here' >"$root/.env.example"
  print -r -- 'ignored private producer state' >"$root/video-production/.env"
  print -r -- "$root"
}

expect_failure() {
  local expected="$1"
  local root="$2"
  local output="$SMOKE_ROOT/receipt.json"
  shift 2
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" --root "$root" "$@" --json >"$output"
  local exit_status=$?
  set -e
  [[ "$exit_status" -eq 1 ]] || fail "$expected did not fail"
  python3 - "$output" "$expected" <<'PY'
import json, pathlib, sys
r=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert r["status"] == "FAIL", r
assert r["code"] == sys.argv[2], r
assert r["recoveryAction"], r
assert r["networkRequired"] is False, r
assert r["environmentValuesRead"] is False, r
assert r["privateDirectoriesScanned"] is False, r
assert r["contentExcerptsIncluded"] is False, r
encoded=json.dumps(r, ensure_ascii=False)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, r
PY
}

clean="$(make_case clean)"
PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" --root "$clean" --json >"$SMOKE_ROOT/clean.json"
python3 - "$SMOKE_ROOT/clean.json" <<'PY'
import json, pathlib, sys
r=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert r["contract"] == "chengyin.public-source-secret-audit/v1", r
assert r["status"] == "PASS" and r["code"] is None, r
assert r["findingCount"] == 0 and r["findings"] == [], r
assert r["textFilesScanned"] == 2, r
assert r["privateDirectoriesScanned"] is False, r
PY

high_risk="$(make_case high-risk)"
print -r -- 'fixture' >"$high_risk/Sources/.env"
expect_failure SOURCE_SECRET_AUDIT_FINDINGS "$high_risk"

private_key="$(make_case private-key)"
print -r -- '-----BEGIN PRI''VATE KEY-----' >"$private_key/Sources/leak.txt"
expect_failure SOURCE_SECRET_AUDIT_FINDINGS "$private_key"

provider="$(make_case provider)"
print -r -- 'token = "gh''p_0123456789abcdefghijklmnop"' >"$provider/Sources/leak.swift"
expect_failure SOURCE_SECRET_AUDIT_FINDINGS "$provider"

assignment="$(make_case assignment)"
print -r -- '"client_secret": "actualvalue0123456789"' >"$assignment/Sources/leak.json"
expect_failure SOURCE_SECRET_AUDIT_FINDINGS "$assignment"

basic_auth="$(make_case basic-auth)"
basic_prefix='https://demo:'
basic_middle='strongpassword123'
basic_suffix='@example.invalid/path'
print -r -- "$basic_prefix$basic_middle$basic_suffix" >"$basic_auth/Sources/leak.txt"
expect_failure SOURCE_SECRET_AUDIT_FINDINGS "$basic_auth"

unsafe="$(make_case unsafe)"
ln -s "$SMOKE_ROOT/outside" "$unsafe/Sources/escape"
expect_failure SOURCE_SECRET_AUDIT_UNSAFE_PATH "$unsafe"

oversized="$(make_case oversized)"
dd if=/dev/zero bs=1048576 count=3 2>/dev/null | tr '\0' x >"$oversized/Sources/generated.txt"
expect_failure SOURCE_SECRET_AUDIT_RESOURCE_LIMIT "$oversized"

undecodable="$(make_case undecodable)"
printf '\377\376\375' >"$undecodable/Sources/opaque.data"
expect_failure SOURCE_SECRET_AUDIT_UNREADABLE_FILE "$undecodable"

missing="$(make_case missing-root)"
expect_failure SOURCE_SECRET_AUDIT_INVALID_ARGUMENT "$missing/no-such-directory"

set +e
PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" --future --json >"$SMOKE_ROOT/unknown.json"
unknown_status=$?
set -e
[[ "$unknown_status" -eq 1 ]] || fail "unknown option did not fail"
python3 - "$SMOKE_ROOT/unknown.json" <<'PY'
import json, pathlib, sys
r=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert r["code"] == "SOURCE_SECRET_AUDIT_UNKNOWN_OPTION", r
assert "/Users/" not in json.dumps(r), r
PY

PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" --help >"$SMOKE_ROOT/help.txt"
grep -Fq 'Usage: python3 scripts/audit-public-source-secrets.py' "$SMOKE_ROOT/help.txt" \
  || fail "help contract is missing"

python3 -m json.tool "$PROJECT_DIR/Schemas/public-source-secret-audit-v1.schema.json" >/dev/null \
  || fail "receipt schema is invalid"

print "Public source secret audit smoke: PASS (12/12)"
