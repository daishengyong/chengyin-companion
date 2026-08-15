#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-public-git-smoke.XXXXXX")"
VALID_DESTINATION="$SMOKE_ROOT/public-repository"
SCHEMA="$PROJECT_DIR/Schemas/public-git-bootstrap-receipt-v1.schema.json"

cleanup() {
  if [[ -n "${SMOKE_ROOT:-}" \
    && "$SMOKE_ROOT" == "${TMPDIR:-/tmp}"/chengyin-public-git-smoke.* \
    && -d "$SMOKE_ROOT" ]]; then
    /bin/rm -rf "$SMOKE_ROOT"
  fi
}
trap cleanup EXIT INT TERM

fail() {
  print -u2 "FAIL  $1"
  exit 1
}

source_sha_before="$(shasum -a 256 \
  "$PROJECT_DIR/scripts/bootstrap-public-git.py" \
  "$PROJECT_DIR/scripts/build-portable-source.sh" \
  "$PROJECT_DIR/scripts/audit-portable-source.py" \
  "$PROJECT_DIR/scripts/audit-public-source-secrets.py" \
  | shasum -a 256 | awk '{ print $1 }')"

receipt="$(PYTHONDONTWRITEBYTECODE=1 python3 \
  "$PROJECT_DIR/scripts/bootstrap-public-git.py" \
  --destination "$VALID_DESTINATION" \
  --json)"
PUBLIC_GIT_RECEIPT="$receipt" SCHEMA="$SCHEMA" python3 - <<'PY'
import json, os
receipt=json.loads(os.environ["PUBLIC_GIT_RECEIPT"])
schema=json.load(open(os.environ["SCHEMA"], encoding="utf-8"))
assert schema["additionalProperties"] is False, schema
assert receipt["status"] == "PASS", receipt
assert receipt["repositoryState"] == "staged-unborn-main", receipt
assert receipt["branch"] == "main", receipt
assert receipt["stagedFileCount"] > 100, receipt
assert receipt["commitCreated"] is False, receipt
assert receipt["remoteConfigured"] is False, receipt
assert receipt["destinationCreated"] is True, receipt
assert receipt["sourcePackageAudit"] == "PASS", receipt
assert receipt["credentialAudit"] == "PASS", receipt
assert receipt["networkRequired"] is False, receipt
assert receipt["authoritativeSourceMutation"] is False, receipt
assert receipt["releaseState"] == "NOT_PUBLIC_RELEASE_READY", receipt
encoded=json.dumps(receipt)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, receipt
PY

[[ -d "$VALID_DESTINATION/.git" && ! -L "$VALID_DESTINATION/.git" ]] \
  || fail "valid bootstrap did not create a regular Git directory"
[[ "$(git -C "$VALID_DESTINATION" symbolic-ref --short HEAD)" == "main" ]] \
  || fail "valid bootstrap did not preserve the unborn main branch"
[[ -z "$(git -C "$VALID_DESTINATION" remote)" ]] \
  || fail "valid bootstrap configured a remote"
set +e
git -C "$VALID_DESTINATION" rev-parse --verify HEAD >/dev/null 2>&1
head_status=$?
set -e
[[ "$head_status" -ne 0 ]] || fail "valid bootstrap created an owner commit"
tracked_count="$(VALID_DESTINATION="$VALID_DESTINATION" python3 - <<'PY'
import os, subprocess
listed=subprocess.run(
    ["git", "-C", os.environ["VALID_DESTINATION"], "ls-files", "-z"],
    check=True,
    stdout=subprocess.PIPE,
).stdout
print(sum(1 for item in listed.split(b"\0") if item))
PY
)"
PUBLIC_GIT_RECEIPT="$receipt" TRACKED_COUNT="$tracked_count" python3 - <<'PY'
import json, os
receipt=json.loads(os.environ["PUBLIC_GIT_RECEIPT"])
assert receipt["stagedFileCount"] == int(os.environ["TRACKED_COUNT"]), receipt
PY

for forbidden in .ai-bridge .build .gitmodules dist video-production release/generated-artifacts; do
  [[ ! -e "$VALID_DESTINATION/$forbidden" ]] \
    || fail "valid bootstrap included a private or generated root"
done
release_files="$(find "$VALID_DESTINATION/release" -type f | wc -l | tr -d ' ')"
[[ "$release_files" == "2" ]] \
  || fail "valid bootstrap included generated release artifacts"
PYTHONDONTWRITEBYTECODE=1 python3 \
  "$VALID_DESTINATION/scripts/audit-public-source-secrets.py" \
  --root "$VALID_DESTINATION" \
  --json >/dev/null

expect_failure() {
  local label="$1"
  local expected_code="$2"
  shift 2
  local output
  local exit_status
  set +e
  output="$(PYTHONDONTWRITEBYTECODE=1 python3 \
    "$PROJECT_DIR/scripts/bootstrap-public-git.py" "$@" --json 2>&1)"
  exit_status=$?
  set -e
  [[ "$exit_status" -eq 1 ]] || fail "$label returned $exit_status"
  PUBLIC_GIT_RECEIPT="$output" EXPECTED_CODE="$expected_code" python3 - <<'PY'
import json, os
receipt=json.loads(os.environ["PUBLIC_GIT_RECEIPT"])
assert receipt["status"] == "FAIL", receipt
assert receipt["code"] == os.environ["EXPECTED_CODE"], receipt
assert receipt["destinationCreated"] is False, receipt
assert receipt["commitCreated"] is False, receipt
assert receipt["remoteConfigured"] is False, receipt
assert receipt["recoveryAction"], receipt
encoded=json.dumps(receipt)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, receipt
PY
}

expect_failure \
  "relative destination" \
  "PUBLIC_GIT_BOOTSTRAP_INVALID_ARGUMENT" \
  --destination relative-public-repository
expect_failure \
  "existing destination" \
  "PUBLIC_GIT_BOOTSTRAP_DESTINATION_EXISTS" \
  --destination "$VALID_DESTINATION"
expect_failure \
  "destination inside source" \
  "PUBLIC_GIT_BOOTSTRAP_UNSAFE_DESTINATION" \
  --destination "$PROJECT_DIR/public-git-output-fixture"
mkdir "$SMOKE_ROOT/real-parent"
ln -s "$SMOKE_ROOT/real-parent" "$SMOKE_ROOT/linked-parent"
expect_failure \
  "symbolic parent" \
  "PUBLIC_GIT_BOOTSTRAP_UNSAFE_DESTINATION" \
  --destination "$SMOKE_ROOT/linked-parent/repository"
expect_failure \
  "unknown option" \
  "PUBLIC_GIT_BOOTSTRAP_INVALID_ARGUMENT" \
  --unknown

source_sha_after="$(shasum -a 256 \
  "$PROJECT_DIR/scripts/bootstrap-public-git.py" \
  "$PROJECT_DIR/scripts/build-portable-source.sh" \
  "$PROJECT_DIR/scripts/audit-portable-source.py" \
  "$PROJECT_DIR/scripts/audit-public-source-secrets.py" \
  | shasum -a 256 | awk '{ print $1 }')"
[[ "$source_sha_before" == "$source_sha_after" ]] \
  || fail "bootstrap smoke modified authoritative source tools"

print "Public Git bootstrap smoke: PASS (6/6, staged public tree, no commit, no remote)"
