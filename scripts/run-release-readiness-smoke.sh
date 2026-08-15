#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
receipt="$(python3 "$PROJECT_DIR/scripts/release-readiness-audit.py" --json)"

RECEIPT="$receipt" python3 - <<'PY'
import json
import os

receipt = json.loads(os.environ["RECEIPT"])
assert receipt["schemaVersion"] == "chengyin.release-readiness/v1"
assert receipt["status"] == "NOT_PUBLIC_RELEASE_READY"
assert receipt["publicReleaseReady"] is False
assert receipt["ownerActionRequired"] is True
states = receipt["states"]
if states["engineeringInstallable"]:
    assert isinstance(receipt["buildIdentity"], str) and receipt["buildIdentity"], receipt
else:
    assert receipt["buildIdentity"] is None, receipt
required = {
    "engineeringInstallable",
    "personalPreview",
    "mediaRightsPassed",
    "finalLicenseApproved",
    "developerIDSigned",
    "notarized",
    "ownerReleaseApprovalGranted",
}
assert set(states) == required
assert states["mediaRightsPassed"] is False
assert states["finalLicenseApproved"] is False
assert states["developerIDSigned"] is False
assert states["notarized"] is False
assert states["ownerReleaseApprovalGranted"] is False
starter = receipt["starterMediaContract"]
assert starter["status"] == "PASS_WITH_PENDING"
assert starter["assetCount"] == 198
assert starter["rightsApprovedAssetCount"] == 0
assert starter["publicDistributionReady"] is False
assert set(receipt["blockingGates"]) == {key for key, value in states.items() if not value}
encoded = json.dumps(receipt, ensure_ascii=False)
assert "/Users/" not in encoded
assert "/Volumes/" not in encoded
print("Release readiness state smoke: PASS")
PY
