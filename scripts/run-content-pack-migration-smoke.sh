#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_dir="${script_dir:h}"
v1_pack="$repo_dir/Tests/Fixtures/valid-v1-pack"
strict_v2_pack="$repo_dir/examples/packs/hello-workday"

"$repo_dir/scripts/validate-content-pack.sh" "$v1_pack" --json >/dev/null
v1_receipt="$(
  "$repo_dir/scripts/plan-content-pack-v2-migration.sh" "$v1_pack" --json
)"
V1_MIGRATION_RECEIPT="$v1_receipt" python3 -c '
import json, os
receipt = json.loads(os.environ["V1_MIGRATION_RECEIPT"])
assert receipt["status"] == "MIGRATION_EVIDENCE_REQUIRED", receipt
assert receipt["sourceSchemaVersion"] == 1, receipt
assert receipt["targetSchemaVersion"] == 2, receipt
assert receipt["sourceMode"] == "legacy-v1", receipt
assert receipt["writesPerformed"] is False, receipt
assert receipt["rightsInferred"] is False, receipt
assert receipt["requiredPackageFields"], receipt
assert receipt["assetGaps"][0]["requiredRightsFields"], receipt
assert "/Users/" not in json.dumps(receipt), receipt
'

set +e
v1_audit="$(
  "$repo_dir/scripts/audit-content-pack.sh" "$v1_pack" --strict --json
)"
v1_audit_exit=$?
set -e
if [[ "$v1_audit_exit" -ne 3 ]]; then
  print -u2 "FAIL  v1 strict contribution audit returned $v1_audit_exit"
  exit 1
fi
V1_AUDIT_RECEIPT="$v1_audit" python3 -c '
import json, os
receipt = json.loads(os.environ["V1_AUDIT_RECEIPT"])
assert receipt["contributionMode"] == "legacy-v1", receipt
assert receipt["contributionReady"] is False, receipt
assert receipt["qualityCandidate"] == "DRAFT", receipt
assert any("no rights" in warning for warning in receipt["warnings"]), receipt
'

v2_receipt="$(
  "$repo_dir/scripts/plan-content-pack-v2-migration.sh" "$strict_v2_pack" --json
)"
V2_MIGRATION_RECEIPT="$v2_receipt" python3 -c '
import json, os
receipt = json.loads(os.environ["V2_MIGRATION_RECEIPT"])
assert receipt["status"] == "STRICT_V2_COMPLETE", receipt
assert receipt["sourceSchemaVersion"] == 2, receipt
assert receipt["sourceMode"] == "strict-v2", receipt
assert receipt["writesPerformed"] is False, receipt
assert receipt["rightsInferred"] is False, receipt
assert receipt["requiredPackageFields"] == [], receipt
assert all(not gap["requiredRightsFields"] for gap in receipt["assetGaps"]), receipt
assert all(not gap["requiredAccessibilityFields"] for gap in receipt["assetGaps"]), receipt
assert all(not gap["requiredFallbackFields"] for gap in receipt["assetGaps"]), receipt
'

print "Content-pack migration receipt checks passed (3/3)."
