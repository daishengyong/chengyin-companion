#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_dir="${script_dir:h}"
ready_v2="$repo_dir/examples/packs/hello-workday"
valid_v1="$repo_dir/Tests/Fixtures/valid-v1-pack"
matrix_root="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-pack-v2-matrix.XXXXXX")"
trap 'rm -rf "$matrix_root"' EXIT INT TERM

assert_safe_receipt() {
  local receipt="$1"
  MATRIX_RECEIPT="$receipt" python3 -c '
import json, os
receipt = json.loads(os.environ["MATRIX_RECEIPT"])
serialized = json.dumps(receipt)
assert receipt.get("recoveryAction"), receipt
assert "/Users/" not in serialized, receipt
assert "/Volumes/" not in serialized, receipt
assert "file://" not in serialized, receipt
'
}

expect_failure() {
  local label="$1"
  local pack="$2"
  local expected_code="$3"
  local json_receipt
  local text_log
  local exit_code

  set +e
  json_receipt="$(
    "$repo_dir/scripts/validate-content-pack.sh" "$pack" --json 2>&1
  )"
  exit_code=$?
  set -e
  [[ "$exit_code" -eq 1 ]] || {
    print -u2 "FAIL  $label JSON returned $exit_code"
    return 1
  }
  MATRIX_RECEIPT="$json_receipt" EXPECTED_CODE="$expected_code" python3 -c '
import json, os
receipt = json.loads(os.environ["MATRIX_RECEIPT"])
assert receipt["status"] == "FAIL", receipt
assert receipt["code"] == os.environ["EXPECTED_CODE"], receipt
'
  assert_safe_receipt "$json_receipt"

  set +e
  text_log="$(
    "$repo_dir/scripts/validate-content-pack.sh" "$pack" 2>&1
  )"
  exit_code=$?
  set -e
  [[ "$exit_code" -eq 1 ]] || {
    print -u2 "FAIL  $label log returned $exit_code"
    return 1
  }
  [[ "$text_log" == *"[$expected_code]"* ]] || {
    print -u2 "FAIL  $label log code mismatch"
    return 1
  }
  [[ "$text_log" == *"ACTION"* ]] || {
    print -u2 "FAIL  $label log has no recovery action"
    return 1
  }
  [[ "$text_log" != *"/Users/"* && "$text_log" != *"/Volumes/"* ]] || {
    print -u2 "FAIL  $label log exposed an absolute path"
    return 1
  }
}

# 1. Legal v1 remains operational but explicitly reports legacy compatibility.
v1_receipt="$(
  "$repo_dir/scripts/validate-content-pack.sh" "$valid_v1" --json
)"
V1_RECEIPT="$v1_receipt" python3 -c '
import json, os
receipt = json.loads(os.environ["V1_RECEIPT"])
assert receipt["status"] == "PASS", receipt
assert receipt["contributionMode"] == "legacy-v1", receipt
'

# 2. Legal strict v2 passes validation and strict contribution audit.
v2_receipt="$(
  "$repo_dir/scripts/validate-content-pack.sh" "$ready_v2" --json
)"
V2_RECEIPT="$v2_receipt" python3 -c '
import json, os
receipt = json.loads(os.environ["V2_RECEIPT"])
assert receipt["status"] == "PASS", receipt
assert receipt["contributionMode"] == "strict-v2", receipt
'
v2_audit="$(
  "$repo_dir/scripts/audit-content-pack.sh" "$ready_v2" --strict --json
)"
V2_AUDIT="$v2_audit" python3 -c '
import json, os
receipt = json.loads(os.environ["V2_AUDIT"])
assert receipt["qualityCandidate"] == "READY_FOR_LAB", receipt
assert receipt["contributionReady"] is True, receipt
'

# 3. Strict-v2 missing required package evidence is a stable hard failure.
cp -R "$ready_v2" "$matrix_root/missing-required"
plutil -remove contribution.package "$matrix_root/missing-required/manifest.json"
expect_failure \
  "missing required" \
  "$matrix_root/missing-required" \
  "PACK_VALIDATION_STRICT_PACKAGE_METADATA_MISSING"

# 4. Rights can be explicitly pending: playable, but never contribution-ready.
cp -R "$ready_v2" "$matrix_root/rights-pending"
plutil -replace contribution.package.review.status -string pending \
  "$matrix_root/rights-pending/manifest.json"
plutil -replace contribution.rights.0.review.status -string pending \
  "$matrix_root/rights-pending/manifest.json"
pending_validation="$(
  "$repo_dir/scripts/validate-content-pack.sh" \
    "$matrix_root/rights-pending" --json
)"
PENDING_VALIDATION="$pending_validation" python3 -c '
import json, os
receipt = json.loads(os.environ["PENDING_VALIDATION"])
assert receipt["status"] == "PASS", receipt
assert receipt["contributionMode"] == "strict-v2", receipt
'
set +e
pending_audit="$(
  "$repo_dir/scripts/audit-content-pack.sh" \
    "$matrix_root/rights-pending" --strict --json
)"
pending_exit=$?
set -e
[[ "$pending_exit" -eq 3 ]]
PENDING_AUDIT="$pending_audit" python3 -c '
import json, os
receipt = json.loads(os.environ["PENDING_AUDIT"])
assert receipt["qualityCandidate"] == "DRAFT", receipt
assert receipt["contributionReady"] is False, receipt
assert any("pending" in warning for warning in receipt["warnings"]), receipt
'

# 5. Strict-v2 accessibility coverage cannot silently disappear.
cp -R "$ready_v2" "$matrix_root/accessibility-missing"
plutil -replace contribution.accessibility -json '[]' \
  "$matrix_root/accessibility-missing/manifest.json"
expect_failure \
  "accessibility missing" \
  "$matrix_root/accessibility-missing" \
  "PACK_VALIDATION_STRICT_ACCESSIBILITY_METADATA_MISSING"

# 6. Unknown fields are rejected at the untrusted manifest boundary.
cp -R "$ready_v2" "$matrix_root/malicious-unknown"
plutil -insert unexpectedPayload -bool YES \
  "$matrix_root/malicious-unknown/manifest.json"
expect_failure \
  "malicious unknown field" \
  "$matrix_root/malicious-unknown" \
  "PACK_VALIDATION_UNKNOWN_MANIFEST_FIELD"

# 7. Corrupt media is rejected, while the declaration proves Starter fallback.
cp -R "$ready_v2" "$matrix_root/media-fallback"
cp "$repo_dir/Tests/Fixtures/invalid-content-pack/manifest.json" \
  "$matrix_root/media-fallback/localization/zh-Hans.json"
corrupt_hash="$(
  shasum -a 256 "$matrix_root/media-fallback/localization/zh-Hans.json" \
    | awk '{print $1}'
)"
plutil -replace assets.0.sha256 -string "$corrupt_hash" \
  "$matrix_root/media-fallback/manifest.json"
MEDIA_FALLBACK_MANIFEST="$matrix_root/media-fallback/manifest.json" python3 -c '
import json, os
manifest = json.load(open(os.environ["MEDIA_FALLBACK_MANIFEST"], encoding="utf-8"))
assert manifest["contribution"]["fallback"]["strategy"] == "starter", manifest
assert manifest["contribution"]["fallback"]["assets"][0]["strategy"] == "skip", manifest
'
expect_failure \
  "media failure with fallback" \
  "$matrix_root/media-fallback" \
  "PACK_MEDIA_INVALID_JSON"

# 8. No manifest means there is no pack-level fallback to trust.
mkdir "$matrix_root/unrecoverable"
expect_failure \
  "fully unrecoverable" \
  "$matrix_root/unrecoverable" \
  "PACK_VALIDATION_MANIFEST_MISSING"

print "Content Pack v2 contract matrix passed (8/8)."
