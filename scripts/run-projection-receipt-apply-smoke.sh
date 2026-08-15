#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-projection-apply.XXXXXX")"
PACK="$SMOKE_ROOT/valid-pack"
ROLLBACK_PACK="$SMOKE_ROOT/rollback-pack"
NO_VIDEO_PACK="$SMOKE_ROOT/no-video-pack"
RECEIPT="$SMOKE_ROOT/receipt.json"
INVALID_SAFE="$SMOKE_ROOT/invalid-safe.json"
UNKNOWN_FIELD="$SMOKE_ROOT/unknown-field.json"
APPLIER="$PROJECT_DIR/scripts/apply-content-pack-projection.py"
EDITOR_HTML="$SMOKE_ROOT/editor.html"

cleanup() {
  if [[ -n "${SMOKE_ROOT:-}" \
    && "$SMOKE_ROOT" == "${TMPDIR:-/tmp}"/chengyin-projection-apply.* \
    && -d "$SMOKE_ROOT" ]]; then
    /bin/rm -rf "$SMOKE_ROOT"
  fi
}
trap cleanup EXIT INT TERM

fail() {
  print -u2 "FAIL  $1"
  exit 1
}

mkdir -p "$PACK/media"
cp -R "$PROJECT_DIR/Tests/Fixtures/valid-v1-pack" "$NO_VIDEO_PACK"
cp "$PROJECT_DIR/Sources/CompanionApp/Resources/companion-master-landscape.mov" \
  "$PACK/media/editor.mov"

PACK_PATH="$PACK" RECEIPT_PATH="$RECEIPT" \
INVALID_SAFE_PATH="$INVALID_SAFE" UNKNOWN_FIELD_PATH="$UNKNOWN_FIELD" \
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import hashlib, json, os
from pathlib import Path

pack = Path(os.environ["PACK_PATH"])
media = pack / "media/editor.mov"
manifest = {
    "schemaVersion": 2,
    "id": "cc.chengyin.smoke.projection-editor",
    "version": "1.0.0",
    "minAppVersion": "0.19.28",
    "tier": "local",
    "character": "smoke-character",
    "locales": ["en"],
    "assets": [{
        "id": "editor-video",
        "kind": "video",
        "path": "media/editor.mov",
        "sha256": hashlib.sha256(media.read_bytes()).hexdigest(),
        "durationMs": 4096,
        "width": 1280,
        "height": 720,
        "aspectRatio": "16:9",
        "hasNativeAudio": True,
        "loop": False,
        "cropAnchors": {
            "pet": {"x": 0.5, "y": 0.5, "scale": 2.0},
            "stage": {"x": 0.5, "y": 0.5, "scale": 1.0},
            "fullscreen": {"x": 0.5, "y": 0.5, "scale": 1.0}
        },
        "triggers": ["singleTap"],
        "tags": ["smoke"],
        "cooldownSeconds": 0,
        "weight": 1
    }],
    "license": "LicenseRef-Smoke",
    "experiences": []
}
(pack / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
receipt = {
    "schemaVersion": "chengyin.projection-authoring-receipt/v1",
    "packID": manifest["id"],
    "assetID": "editor-video",
    "generatedForAppVersion": "0.19.29",
    "focalTracks": {
        "pet": [
            {"timeMs": 0, "x": 0.5, "y": 0.5, "scale": 2.0},
            {"timeMs": 4096, "x": 0.55, "y": 0.5, "scale": 2.0}
        ],
        "stage": [
            {"timeMs": 0, "x": 0.5, "y": 0.5, "scale": 1.0},
            {"timeMs": 4096, "x": 0.5, "y": 0.5, "scale": 1.0}
        ],
        "fullscreen": [
            {"timeMs": 0, "x": 0.5, "y": 0.5, "scale": 1.0},
            {"timeMs": 4096, "x": 0.5, "y": 0.5, "scale": 1.0}
        ]
    },
    "safeAreas": {"pet": {"x": 0.3, "y": 0.3, "width": 0.35, "height": 0.35}}
}
Path(os.environ["RECEIPT_PATH"]).write_text(json.dumps(receipt, indent=2) + "\n")
invalid = json.loads(json.dumps(receipt))
invalid["safeAreas"]["pet"] = {"x": 0.01, "y": 0.01, "width": 0.2, "height": 0.2}
Path(os.environ["INVALID_SAFE_PATH"]).write_text(json.dumps(invalid) + "\n")
unknown = json.loads(json.dumps(receipt))
unknown["privatePath"] = "/Users/example/private.mov"
Path(os.environ["UNKNOWN_FIELD_PATH"]).write_text(json.dumps(unknown) + "\n")
PY

CHENGYIN_CREATOR_CACHE_ROOT="$SMOKE_ROOT/creator-cache" \
  "$PROJECT_DIR/scripts/edit-content-pack-projection.sh" \
  "$PACK" \
  --asset editor-video \
  --output "$EDITOR_HTML" \
  --no-open \
  >"$SMOKE_ROOT/editor.log"
[[ -s "$EDITOR_HTML" ]] || fail "projection editor CLI did not publish HTML"
grep -Fq "chengyin.projection-authoring-receipt/v1" "$EDITOR_HTML" \
  && fail "editor exposed decoded receipt data instead of safe base64"
grep -Fq "connect-src 'none'" "$EDITOR_HTML" \
  || fail "editor CLI output lost its no-network content policy"

set +e
no_video_receipt="$(CHENGYIN_CREATOR_CACHE_ROOT="$SMOKE_ROOT/creator-cache" \
  "$PROJECT_DIR/scripts/edit-content-pack-projection.sh" \
  "$NO_VIDEO_PACK" \
  --output "$SMOKE_ROOT/no-video.html" \
  --no-open 2>&1)"
no_video_status=$?
set -e
if [[ "$no_video_status" -ne 1 \
  || "$no_video_receipt" != *"[CREATOR_PROJECTION_EDITOR_NO_VIDEO]"* \
  || "$no_video_receipt" != *"ACTION"* ]]; then
  has_code=0
  has_action=0
  [[ "$no_video_receipt" == *"[CREATOR_PROJECTION_EDITOR_NO_VIDEO]"* ]] \
    && has_code=1
  [[ "$no_video_receipt" == *"ACTION"* ]] && has_action=1
  fail "video-free pack editor receipt mismatch (status=$no_video_status code=$has_code action=$has_action)"
fi
[[ "$no_video_receipt" != *"/Users/"* \
  && "$no_video_receipt" != *"/Volumes/"* ]] \
  || fail "projection editor failure exposed a private absolute path"

check_receipt="$(PYTHONDONTWRITEBYTECODE=1 "$APPLIER" \
  "$PACK" "$RECEIPT" --check --json)"
RECEIPT_JSON="$check_receipt" python3 - <<'PY'
import json, os
value = json.loads(os.environ["RECEIPT_JSON"])
assert value["status"] == "PASS" and value["operation"] == "CHECKED", value
assert value["backupReference"] == "not-created", value
assert "/Users/" not in json.dumps(value) and "/Volumes/" not in json.dumps(value), value
PY

apply_receipt="$(PYTHONDONTWRITEBYTECODE=1 "$APPLIER" \
  "$PACK" "$RECEIPT" --json)"
RECEIPT_JSON="$apply_receipt" PACK_PATH="$PACK" python3 - <<'PY'
import json, os
from pathlib import Path
value = json.loads(os.environ["RECEIPT_JSON"])
assert value["status"] == "PASS" and value["operation"] == "APPLIED", value
assert "/Users/" not in json.dumps(value) and "/Volumes/" not in json.dumps(value), value
manifest = json.loads((Path(os.environ["PACK_PATH"]) / "manifest.json").read_text())
asset = manifest["assets"][0]
assert set(asset["focalTracks"]) == {"pet", "stage", "fullscreen"}, asset
assert asset["safeAreas"]["pet"]["width"] == 0.35, asset
backup = Path(os.environ["PACK_PATH"]).parent / value["backupReference"]
assert backup.is_file() and not backup.is_symlink(), backup
PY

manifest_before="$(shasum -a 256 "$PACK/manifest.json" | awk '{print $1}')"
set +e
invalid_receipt="$(PYTHONDONTWRITEBYTECODE=1 "$APPLIER" \
  "$PACK" "$INVALID_SAFE" --json)"
invalid_status=$?
set -e
[[ "$invalid_status" -eq 1 ]] || fail "clipped safe area was accepted"
RECEIPT_JSON="$invalid_receipt" python3 - <<'PY'
import json, os
value = json.loads(os.environ["RECEIPT_JSON"])
assert value["code"] == "PROJECTION_RECEIPT_INVALID_SAFE_AREA", value
assert "/Users/" not in json.dumps(value) and "/Volumes/" not in json.dumps(value), value
PY
manifest_after="$(shasum -a 256 "$PACK/manifest.json" | awk '{print $1}')"
[[ "$manifest_before" == "$manifest_after" ]] \
  || fail "invalid receipt changed the manifest"

set +e
unknown_receipt="$(PYTHONDONTWRITEBYTECODE=1 "$APPLIER" \
  "$PACK" "$UNKNOWN_FIELD" --json)"
unknown_status=$?
set -e
[[ "$unknown_status" -eq 1 ]] || fail "unknown receipt field was accepted"
RECEIPT_JSON="$unknown_receipt" python3 - <<'PY'
import json, os
value = json.loads(os.environ["RECEIPT_JSON"])
assert value["code"] == "PROJECTION_RECEIPT_UNKNOWN_FIELD", value
assert "/Users/" not in json.dumps(value) and "/Volumes/" not in json.dumps(value), value
PY

cp -R "$PACK" "$ROLLBACK_PACK"
ROLLBACK_PACK_PATH="$ROLLBACK_PACK" python3 - <<'PY'
import json, os
from pathlib import Path
path = Path(os.environ["ROLLBACK_PACK_PATH"]) / "manifest.json"
value = json.loads(path.read_text())
asset = value["assets"][0]
asset.pop("focalTracks", None)
asset.pop("safeAreas", None)
value["minAppVersion"] = "0.19.27"
path.write_text(json.dumps(value, indent=2) + "\n")
PY
rollback_before="$(shasum -a 256 "$ROLLBACK_PACK/manifest.json" | awk '{print $1}')"
set +e
rollback_receipt="$(PYTHONDONTWRITEBYTECODE=1 "$APPLIER" \
  "$ROLLBACK_PACK" "$RECEIPT" --json)"
rollback_status=$?
set -e
[[ "$rollback_status" -eq 1 ]] || fail "post-validation failure was accepted"
RECEIPT_JSON="$rollback_receipt" python3 - <<'PY'
import json, os
value = json.loads(os.environ["RECEIPT_JSON"])
assert value["code"] == "PROJECTION_RECEIPT_VALIDATION_FAILED", value
assert value["rolledBack"] is True, value
assert "/Users/" not in json.dumps(value) and "/Volumes/" not in json.dumps(value), value
PY
rollback_after="$(shasum -a 256 "$ROLLBACK_PACK/manifest.json" | awk '{print $1}')"
[[ "$rollback_before" == "$rollback_after" ]] \
  || fail "failed apply did not restore the original manifest"

ln -s "$RECEIPT" "$SMOKE_ROOT/receipt-link.json"
set +e
unsafe_receipt="$(PYTHONDONTWRITEBYTECODE=1 "$APPLIER" \
  "$PACK" "$SMOKE_ROOT/receipt-link.json" --json)"
unsafe_status=$?
set -e
[[ "$unsafe_status" -eq 1 ]] || fail "symbolic-link receipt was accepted"
RECEIPT_JSON="$unsafe_receipt" python3 - <<'PY'
import json, os
value = json.loads(os.environ["RECEIPT_JSON"])
assert value["code"] == "PROJECTION_RECEIPT_UNSAFE_INPUT", value
PY

print "Projection receipt apply smoke: PASS (9/9, editor/check/apply/reject/rollback/privacy)"
