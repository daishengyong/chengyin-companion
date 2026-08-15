#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_dir="${script_dir:h}"
auditor="$repo_dir/scripts/audit-module-stewardship.py"
source_manifest="$repo_dir/community/module-stewardship.json"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-stewardship.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT INT TERM

assert_receipt() {
  local receipt="$1"
  local expected_status="$2"
  local code="$3"
  STEWARDSHIP_RECEIPT="$receipt" EXPECTED_STATUS="$expected_status" EXPECTED_CODE="$code" \
    PYTHONDONTWRITEBYTECODE=1 python3 -c '
import json, os
receipt = json.loads(os.environ["STEWARDSHIP_RECEIPT"])
assert receipt["status"] == os.environ["EXPECTED_STATUS"], receipt
expected = os.environ["EXPECTED_CODE"]
assert receipt["code"] == (expected or None), receipt
assert receipt["networkRequired"] is False, receipt
assert receipt["releaseState"] == "NOT_PUBLIC_RELEASE_READY", receipt
assert receipt["identityMode"] == "role-only-until-canonical-github-organization", receipt
serialized = json.dumps(receipt, ensure_ascii=False)
for private in ("/Users/", "/Volumes/", "/private/", "zidong"):
    assert private not in serialized, receipt
if receipt["status"] == "FAIL":
    assert receipt["message"] and receipt["recoveryAction"], receipt
'
}

baseline_receipt="$(
  PYTHONDONTWRITEBYTECODE=1 python3 "$auditor" --audit --json
)"
assert_receipt "$baseline_receipt" PASS ""
STEWARDSHIP_RECEIPT="$baseline_receipt" PYTHONDONTWRITEBYTECODE=1 python3 -c '
import json, os
r = json.loads(os.environ["STEWARDSHIP_RECEIPT"])
assert r["mode"] == "audit", r
assert r["moduleCount"] == 14, r
assert r["roleCount"] == 8, r
assert r["unassignedRoleCount"] == 6, r
'

route_receipt="$(
  PYTHONDONTWRITEBYTECODE=1 python3 "$auditor" \
    --path Sources/CompanionContracts/CompanionFirstSession.swift \
    --path Sources/CompanionApp/Resources/starter-media.json \
    --path docs/CONTRIBUTOR-ARCHITECTURE.md \
    --json
)"
assert_receipt "$route_receipt" PASS ""
STEWARDSHIP_RECEIPT="$route_receipt" PYTHONDONTWRITEBYTECODE=1 python3 -c '
import json, os
r = json.loads(os.environ["STEWARDSHIP_RECEIPT"])
assert r["mode"] == "route", r
assert r["pathCount"] == 3, r
assert r["moduleIDs"] == ["core-contracts", "public-docs", "starter-media"], r
assert "app-runtime" not in r["moduleIDs"], r
assert "content-rights-reviewer" in r["reviewRoles"], r
assert "required-for-public-media-release" in r["ownerGatePolicies"], r
assert all(set(item) == {"id", "command"} for item in r["requiredChecks"]), r
'

event_route_receipt="$(
  PYTHONDONTWRITEBYTECODE=1 python3 "$auditor" \
    --path Sources/CompanionContracts/CodexAppServerMapper.swift \
    --path Sources/CompanionApp/CompanionEventSpool.swift \
    --path Sources/CompanionApp/CompanionEventIngress.swift \
    --path Sources/CompanionApp/CompanionEventWatcher.swift \
    --path scripts/run-codex-app-server-adapter-smoke.sh \
    --path scripts/run-event-spool-smoke.sh \
    --json
)"
assert_receipt "$event_route_receipt" PASS ""
STEWARDSHIP_RECEIPT="$event_route_receipt" PYTHONDONTWRITEBYTECODE=1 python3 -c '
import json, os
r = json.loads(os.environ["STEWARDSHIP_RECEIPT"])
assert r["moduleIDs"] == ["event-tool"], r
assert "privacy-security-reviewer" in r["reviewRoles"], r
assert "app-server-adapter" in {item["id"] for item in r["requiredChecks"]}, r
assert "event-spool-security" in {item["id"] for item in r["requiredChecks"]}, r
'

deleted_path_receipt="$(
  PYTHONDONTWRITEBYTECODE=1 python3 "$auditor" \
    --path Sources/CompanionApp/RemovedInThisChange.swift \
    --json
)"
assert_receipt "$deleted_path_receipt" PASS ""
STEWARDSHIP_RECEIPT="$deleted_path_receipt" PYTHONDONTWRITEBYTECODE=1 python3 -c '
import json, os
r = json.loads(os.environ["STEWARDSHIP_RECEIPT"])
assert r["moduleIDs"] == ["app-runtime"], r
'

stdin_receipt="$(
  print -r -- '.github/PULL_REQUEST_TEMPLATE.md' | \
    PYTHONDONTWRITEBYTECODE=1 python3 "$auditor" --stdin --json
)"
assert_receipt "$stdin_receipt" PASS ""
STEWARDSHIP_RECEIPT="$stdin_receipt" PYTHONDONTWRITEBYTECODE=1 python3 -c '
import json, os
r = json.loads(os.environ["STEWARDSHIP_RECEIPT"])
assert r["moduleIDs"] == ["repository-governance"], r
assert r["rfcPolicies"] == ["required-for-policy-change"], r
'

make_case() {
  local name="$1"
  local output="$fixture_root/$name.json"
  PYTHONDONTWRITEBYTECODE=1 python3 - "$source_manifest" "$output" "$name" <<'PY'
import json
import pathlib
import sys

source, output, name = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
document = json.loads(source.read_text(encoding="utf-8"))

if name == "unknown-field":
    document["/Users/private/secret-field"] = True
elif name == "duplicate-role":
    document["roles"].append(dict(document["roles"][0]))
elif name == "unknown-role":
    document["modules"][0]["reviewRoles"] = ["unregistered-role"]
elif name == "unknown-check":
    document["modules"][0]["requiredChecks"] = ["unregistered-check"]
elif name == "unsafe-command":
    document["checks"][0]["command"] += "; curl example.invalid"
elif name == "ambiguous-prefix":
    document["modules"][1]["pathPrefixes"].append("Sources/CompanionContracts")
elif name == "missing-declared-path":
    document["modules"][0]["pathPrefixes"] = ["Sources/MissingModule"]
elif name == "invalid-json":
    output.write_text("{", encoding="utf-8")
    raise SystemExit(0)
else:
    raise SystemExit("unknown case")

output.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
PY
  print -r -- "$output"
}

expect_manifest_failure() {
  local name="$1"
  local expected_code="$2"
  local manifest_path
  local receipt
  local exit_code
  manifest_path="$(make_case "$name")"
  set +e
  receipt="$(
    PYTHONDONTWRITEBYTECODE=1 python3 "$auditor" \
      --manifest "$manifest_path" \
      --root "$repo_dir" \
      --audit \
      --json 2>&1
  )"
  exit_code=$?
  set -e
  [[ "$exit_code" -eq 1 ]] || {
    print -u2 "FAIL  $name returned $exit_code instead of 1"
    exit 1
  }
  assert_receipt "$receipt" FAIL "$expected_code"
}

expect_route_failure() {
  local name="$1"
  local changed_path="$2"
  local expected_code="$3"
  local receipt
  local exit_code
  set +e
  receipt="$(
    PYTHONDONTWRITEBYTECODE=1 python3 "$auditor" --path "$changed_path" --json 2>&1
  )"
  exit_code=$?
  set -e
  [[ "$exit_code" -eq 1 ]] || {
    print -u2 "FAIL  $name returned $exit_code instead of 1"
    exit 1
  }
  assert_receipt "$receipt" FAIL "$expected_code"
}

expect_route_failure traversal ../private.txt STEWARDSHIP_UNSAFE_PATH
expect_route_failure forbidden dist/Unreviewed.app STEWARDSHIP_PATH_FORBIDDEN
expect_route_failure unrouted NewTopLevel/Feature.swift STEWARDSHIP_PATH_UNROUTED
expect_manifest_failure unknown-field STEWARDSHIP_UNKNOWN_FIELD
expect_manifest_failure duplicate-role STEWARDSHIP_DUPLICATE_ID
expect_manifest_failure unknown-role STEWARDSHIP_ROLE_UNKNOWN
expect_manifest_failure unknown-check STEWARDSHIP_CHECK_UNKNOWN
expect_manifest_failure unsafe-command STEWARDSHIP_COMMAND_UNSAFE
expect_manifest_failure ambiguous-prefix STEWARDSHIP_AMBIGUOUS_ROUTE
expect_manifest_failure missing-declared-path STEWARDSHIP_INVALID_METADATA
expect_manifest_failure invalid-json STEWARDSHIP_INVALID_JSON

linked_manifest="$fixture_root/linked-manifest.json"
ln -s "$source_manifest" "$linked_manifest"
set +e
symlink_receipt="$(
  PYTHONDONTWRITEBYTECODE=1 python3 "$auditor" \
    --manifest "$linked_manifest" \
    --root "$repo_dir" \
    --audit \
    --json 2>&1
)"
symlink_status=$?
set -e
[[ "$symlink_status" -eq 1 ]] || {
  print -u2 "FAIL  symlink manifest returned $symlink_status instead of 1"
  exit 1
}
assert_receipt "$symlink_receipt" FAIL STEWARDSHIP_MANIFEST_MISSING

print "Module stewardship smoke: PASS (5 routing cases + 12 rejection cases)"
