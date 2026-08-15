#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
GENERATOR="$PROJECT_DIR/scripts/refresh-starter-media-manifest.py"
AUDITOR="$PROJECT_DIR/scripts/audit-starter-media.py"
RESOURCES="$PROJECT_DIR/Sources/CompanionApp/Resources"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-starter-media-smoke.XXXXXX")"
trap 'rm -rf "$SMOKE_ROOT"' EXIT INT TERM

fail() {
  print -u2 "FAIL  $1"
  exit 1
}

expect_failure() {
  local expected_code="$1"
  local resources="$2"
  shift 2
  local receipt
  local exit_status
  set +e
  receipt="$($AUDITOR --resources "$resources" --json "$@")"
  exit_status=$?
  set -e
  [[ "$exit_status" -eq 1 ]] \
    || fail "expected $expected_code exit 1, received $exit_status"
  STARTER_RECEIPT="$receipt" EXPECTED_CODE="$expected_code" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["STARTER_RECEIPT"])
assert receipt["status"] == "FAIL", receipt
assert receipt["code"] == os.environ["EXPECTED_CODE"], receipt
assert receipt["recoveryAction"], receipt
encoded = json.dumps(receipt)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, receipt
PY
}

"$GENERATOR" --check >/dev/null
receipt="$($AUDITOR --json)"
STARTER_RECEIPT="$receipt" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["STARTER_RECEIPT"])
assert receipt["status"] == "PASS_WITH_PENDING", receipt
assert receipt["assetCount"] == 198, receipt
assert receipt["rightsApprovedAssetCount"] == 0, receipt
assert receipt["publicDistributionReady"] is False, receipt
assert receipt["providerCredentialsRequiredAtBuild"] is False, receipt
assert receipt["distributionState"] == "INTERNAL_PREVIEW_ONLY", receipt
PY

set +e
strict_receipt="$($AUDITOR --strict --json)"
strict_status=$?
set -e
[[ "$strict_status" -eq 3 ]] || fail "strict pending audit did not exit 3"
STARTER_RECEIPT="$strict_receipt" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["STARTER_RECEIPT"])
assert receipt["status"] == "NOT_READY", receipt
assert receipt["code"] == "STARTER_MEDIA_RIGHTS_PENDING", receipt
assert receipt["publicDistributionReady"] is False, receipt
PY

make_fixture() {
  local destination="$1"
  mkdir -p "$destination"
  python3 - "$destination" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
(root / "voice-lines.json").write_text("[]\n", encoding="utf-8")
(root / "sample.png").write_bytes(b"starter-fixture-png")
PY
  "$GENERATOR" --resources "$destination" --write >/dev/null
}

fresh="$SMOKE_ROOT/fresh"
make_fixture "$fresh"
fresh_receipt="$($AUDITOR --resources "$fresh" --json)"
STARTER_RECEIPT="$fresh_receipt" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["STARTER_RECEIPT"])
assert receipt["status"] == "PASS_WITH_PENDING", receipt
assert receipt["assetCount"] == 2, receipt
PY

unlisted="$SMOKE_ROOT/unlisted"
cp -R "$fresh" "$unlisted"
python3 -c 'from pathlib import Path; Path("'$unlisted'/new.png").write_bytes(b"new")'
expect_failure STARTER_MEDIA_INVENTORY_MISMATCH "$unlisted"

tampered="$SMOKE_ROOT/tampered"
cp -R "$fresh" "$tampered"
python3 -c 'from pathlib import Path; p=Path("'$tampered'/sample.png"); d=bytearray(p.read_bytes()); d[0] ^= 1; p.write_bytes(d)'
expect_failure STARTER_MEDIA_HASH_MISMATCH "$tampered"

missing="$SMOKE_ROOT/missing"
cp -R "$fresh" "$missing"
mv "$missing/starter-media.json" "$SMOKE_ROOT/missing-manifest.json"
expect_failure STARTER_MEDIA_MANIFEST_MISSING "$missing"

unknown="$SMOKE_ROOT/unknown"
cp -R "$fresh" "$unknown"
python3 - "$unknown/starter-media.json" <<'PY'
from pathlib import Path
import json, sys
p = Path(sys.argv[1])
data = json.loads(p.read_text())
data["unknownField"] = True
p.write_text(json.dumps(data), encoding="utf-8")
PY
expect_failure STARTER_MEDIA_CONTRACT_INVALID "$unknown"

duplicate="$SMOKE_ROOT/duplicate"
cp -R "$fresh" "$duplicate"
python3 - "$duplicate/starter-media.json" <<'PY'
from pathlib import Path
import json, sys
p = Path(sys.argv[1])
data = json.loads(p.read_text())
data["assets"][1]["id"] = data["assets"][0]["id"]
p.write_text(json.dumps(data), encoding="utf-8")
PY
expect_failure STARTER_MEDIA_CONTRACT_INVALID "$duplicate"

private="$SMOKE_ROOT/private"
cp -R "$fresh" "$private"
python3 - "$private/starter-media.json" <<'PY'
from pathlib import Path
import json, sys
p = Path(sys.argv[1])
data = json.loads(p.read_text())
data["assets"][0]["provenance"]["evidenceID"] = "/Users/example/private/evidence"
p.write_text(json.dumps(data), encoding="utf-8")
PY
expect_failure STARTER_MEDIA_PRIVATE_PATH_DISCLOSURE "$private"

forged="$SMOKE_ROOT/forged"
cp -R "$fresh" "$forged"
python3 - "$forged/starter-media.json" <<'PY'
from pathlib import Path
import json, sys
p = Path(sys.argv[1])
data = json.loads(p.read_text())
data["distributionClass"] = "publicCandidate"
data["rightsConclusion"] = "approved"
data["accessibilityConclusion"] = "approved"
data["publicDistributionReady"] = True
p.write_text(json.dumps(data), encoding="utf-8")
PY
expect_failure STARTER_MEDIA_APPROVAL_MISMATCH "$forged"

wrong_types="$SMOKE_ROOT/wrong-types"
cp -R "$fresh" "$wrong_types"
python3 - "$wrong_types/starter-media.json" <<'PY'
from pathlib import Path
import json, sys
p = Path(sys.argv[1])
data = json.loads(p.read_text())
data["privacy"]["containsAPIKeys"] = 0
p.write_text(json.dumps(data), encoding="utf-8")
PY
expect_failure STARTER_MEDIA_CONTRACT_INVALID "$wrong_types"

bundle="$SMOKE_ROOT/bundle"
mkdir -p "$bundle"
cp "$fresh/voice-lines.json" "$bundle/voice-lines.json"
cp "$fresh/sample.png" "$bundle/sample.png"
cp "$fresh/starter-media.json" "$bundle/starter-media.json"
"$AUDITOR" --resources "$fresh" --bundle "$bundle" --json >/dev/null
python3 - "$bundle/Info.plist" <<'PY'
from pathlib import Path
import plistlib, sys
Path(sys.argv[1]).write_bytes(plistlib.dumps({"CFBundleDevelopmentRegion": "zh-Hans"}))
PY
"$AUDITOR" \
  --resources "$fresh" \
  --bundle "$bundle" \
  --allow-swiftpm-metadata \
  --json >/dev/null
expect_failure STARTER_MEDIA_BUNDLE_MISMATCH "$fresh" --bundle "$bundle"
python3 - "$bundle/Info.plist" <<'PY'
from pathlib import Path
import plistlib, sys
Path(sys.argv[1]).write_bytes(plistlib.dumps({
    "CFBundleDevelopmentRegion": "zh-Hans",
    "unexpected": True,
}))
PY
expect_failure \
  STARTER_MEDIA_BUNDLE_MISMATCH \
  "$fresh" \
  --bundle "$bundle" \
  --allow-swiftpm-metadata
rm "$bundle/Info.plist"
python3 -c 'from pathlib import Path; Path("'$bundle'/legacy.zip").write_bytes(b"stale")'
expect_failure STARTER_MEDIA_BUNDLE_MISMATCH "$fresh" --bundle "$bundle"
mv "$bundle/legacy.zip" "$SMOKE_ROOT/stale-bundle-resource.zip"
python3 -c 'from pathlib import Path; p=Path("'$bundle'/sample.png"); p.write_bytes(p.read_bytes()+b"bundle-tamper")'
expect_failure STARTER_MEDIA_BUNDLE_MISMATCH "$fresh" --bundle "$bundle"

reset="$SMOKE_ROOT/reset"
cp -R "$fresh" "$reset"
python3 - "$reset/starter-media.json" <<'PY'
from pathlib import Path
import json, sys
p = Path(sys.argv[1])
data = json.loads(p.read_text())
asset = next(item for item in data["assets"] if item["path"] == "sample.png")
asset["provenance"].update({
    "license": "Fixture-License",
    "authorizationBasis": "owned",
    "allowedUses": ["localUse", "backup", "freeRedistributionWithCore", "accessibilityAdaptation"],
    "attribution": {"required": False, "text": None},
    "adultFictionStatus": "noPeople",
    "evidenceID": "fixture.evidence.001",
    "review": {"status": "approved", "reviewerID": "fixture.reviewer", "reviewedAt": "2026-08-07T00:00:00Z", "version": 1},
})
p.write_text(json.dumps(data), encoding="utf-8")
PY
python3 -c 'from pathlib import Path; p=Path("'$reset'/sample.png"); p.write_bytes(p.read_bytes()+b"revision")'
"$GENERATOR" --resources "$reset" --write >/dev/null
python3 - "$reset/starter-media.json" <<'PY'
from pathlib import Path
import json, sys
data = json.loads(Path(sys.argv[1]).read_text())
asset = next(item for item in data["assets"] if item["path"] == "sample.png")
assert asset["provenance"]["review"]["status"] == "pending", asset
assert asset["provenance"]["license"] is None, asset
assert asset["provenance"]["authorizationBasis"] is None, asset
assert asset["provenance"]["allowedUses"] == [], asset
PY

python3 - "$RESOURCES" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
for path in root.rglob("*"):
    if path.is_file():
        assert path.name != ".DS_Store", path
        assert path.suffix.lower() != ".zip", path
PY

print "Starter media contract smoke: PASS (16/16)"
print "Distribution state: INTERNAL_PREVIEW_ONLY"
