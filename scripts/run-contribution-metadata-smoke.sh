#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_dir="${script_dir:h}"
ready_pack="$repo_dir/examples/packs/hello-workday"
incomplete_pack="$repo_dir/Tests/Fixtures/incomplete-contribution-pack"

"$repo_dir/scripts/validate-content-pack.sh" "$ready_pack" --json >/dev/null
ready_receipt="$($repo_dir/scripts/audit-content-pack.sh "$ready_pack" --strict --json)"
READY_RECEIPT="$ready_receipt" python3 -c '
import json, os
receipt = json.loads(os.environ["READY_RECEIPT"])
assert receipt["status"] == "PASS", receipt
assert receipt["qualityCandidate"] == "READY_FOR_LAB", receipt
assert receipt["rightsCoveredAssetCount"] == 5, receipt
assert receipt["accessibilityCoveredAssetCount"] == 5, receipt
assert receipt["fallbackStrategy"] == "starter", receipt
assert receipt["contributionReady"] is True, receipt
assert receipt["contributionMode"] == "strict-v2", receipt
assert receipt["packageReviewStatus"] == "approved", receipt
'

"$repo_dir/scripts/validate-content-pack.sh" "$incomplete_pack" --json >/dev/null
set +e
incomplete_receipt="$($repo_dir/scripts/audit-content-pack.sh "$incomplete_pack" --strict --json)"
audit_exit=$?
set -e
if [[ "$audit_exit" -ne 3 ]]; then
  print -u2 "FAIL  strict incomplete contribution audit returned $audit_exit instead of 3"
  exit 1
fi
INCOMPLETE_RECEIPT="$incomplete_receipt" python3 -c '
import json, os
receipt = json.loads(os.environ["INCOMPLETE_RECEIPT"])
assert receipt["status"] == "PASS_WITH_WARNINGS", receipt
assert receipt["qualityCandidate"] == "DRAFT", receipt
assert receipt["rightsCoveredAssetCount"] == 0, receipt
assert receipt["accessibilityCoveredAssetCount"] == 0, receipt
assert receipt.get("fallbackStrategy") is None, receipt
assert receipt["contributionReady"] is False, receipt
assert any("compatibility v2 mode" in warning for warning in receipt["warnings"]), receipt
'

preview="$(mktemp "${TMPDIR:-/tmp}/chengyin-contribution-preview.XXXXXX.html")"
draft_root="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-contribution-draft.XXXXXX")"
trap 'rm -f "$preview"; rm -rf "$draft_root"' EXIT INT TERM
"$repo_dir/scripts/preview-content-pack.sh" \
  "$incomplete_pack" \
  --output "$preview" \
  --no-open \
  >/dev/null
grep -Fq "compatibility-v2" "$preview"
grep -Fq "contribution audit will block readiness" "$preview"

"$repo_dir/scripts/new-content-pack.sh" \
  "$draft_root/sample" \
  cc.example.contribution-draft \
  starter \
  en-US \
  >/dev/null
set +e
draft_receipt="$($repo_dir/scripts/audit-content-pack.sh "$draft_root/sample" --strict --json)"
draft_exit=$?
set -e
if [[ "$draft_exit" -ne 3 ]]; then
  print -u2 "FAIL  strict scaffold audit returned $draft_exit instead of 3"
  exit 1
fi
DRAFT_RECEIPT="$draft_receipt" python3 -c '
import json, os
receipt = json.loads(os.environ["DRAFT_RECEIPT"])
assert receipt["status"] == "PASS_WITH_WARNINGS", receipt
assert receipt["qualityCandidate"] == "DRAFT", receipt
assert receipt["rightsCoveredAssetCount"] == 0, receipt
assert receipt["accessibilityCoveredAssetCount"] == 0, receipt
assert receipt["fallbackStrategy"] == "starter", receipt
assert receipt["contributionReady"] is False, receipt
assert receipt["contributionMode"] == "compatibility-v2", receipt
assert any("rights approval is not" in warning or "compatibility v2 mode" in warning for warning in receipt["warnings"]), receipt
'

print "Contribution metadata smoke checks passed (4/4)."
