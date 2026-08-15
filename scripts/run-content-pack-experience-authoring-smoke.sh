#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-experience-author.XXXXXX")"
PACK="$SMOKE_ROOT/workday-pack"
AUTHOR="$PROJECT_DIR/scripts/author-content-pack-experience.sh"
VALIDATOR="$PROJECT_DIR/scripts/validate-content-pack.sh"

cleanup() {
  if [[ -n "${SMOKE_ROOT:-}" \
    && "$SMOKE_ROOT" == "${TMPDIR:-/tmp}"/chengyin-experience-author.* \
    && -d "$SMOKE_ROOT" ]]; then
    /bin/rm -rf "$SMOKE_ROOT"
  fi
}
trap cleanup EXIT INT TERM

fail() {
  print -u2 "FAIL  $1"
  exit 1
}

assert_private_path_safe() {
  local payload="$1"
  [[ "$payload" != *"/Users/"* \
    && "$payload" != *"/Volumes/"* \
    && "$payload" != *"$USER"* ]] \
    || fail "authoring receipt exposed a private path or username"
}

expect_failure() {
  local expected_code="$1"
  shift
  local receipt exit_status
  set +e
  receipt="$("$@" 2>&1)"
  exit_status=$?
  set -e
  [[ "$exit_status" -eq 1 ]] || fail "$expected_code case was accepted"
  RECEIPT_JSON="$receipt" EXPECTED_CODE="$expected_code" python3 - <<'PY'
import json, os
value = json.loads(os.environ["RECEIPT_JSON"])
assert value["schemaVersion"] == "chengyin.experience-authoring-receipt/v1", value
assert value["status"] == "FAIL" and value["code"] == os.environ["EXPECTED_CODE"], value
assert value["recoveryAction"], value
encoded = json.dumps(value)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, value
PY
  assert_private_path_safe "$receipt"
}

mkdir -p "$PACK/media" "$PACK/localization"
cp "$PROJECT_DIR/Sources/CompanionApp/Resources/companion-master-landscape.mov" \
  "$PACK/media/workday.mov"

PACK_PATH="$PACK" PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import hashlib, json, os
from pathlib import Path

pack = Path(os.environ["PACK_PATH"])
copy_path = pack / "localization/en.json"
copy_path.write_text(json.dumps({"hello": "Hello"}) + "\n", encoding="utf-8")
video = pack / "media/workday.mov"
manifest = {
    "schemaVersion": 2,
    "id": "cc.chengyin.smoke.experience-author",
    "version": "1.0.0",
    "minAppVersion": "0.19.42",
    "tier": "local",
    "character": "smoke-character",
    "locales": ["en"],
    "assets": [
        {
            "id": "workday-video",
            "kind": "video",
            "path": "media/workday.mov",
            "sha256": hashlib.sha256(video.read_bytes()).hexdigest(),
            "durationMs": 4096,
            "width": 1280,
            "height": 720,
            "aspectRatio": "16:9",
            "hasNativeAudio": True,
            "loop": False,
            "triggers": ["singleTap"],
            "tags": ["smoke"],
            "cooldownSeconds": 0,
            "weight": 1
        },
        {
            "id": "localized-copy",
            "kind": "localization",
            "path": "localization/en.json",
            "sha256": hashlib.sha256(copy_path.read_bytes()).hexdigest(),
            "triggers": [],
            "tags": ["smoke"]
        }
    ],
    "license": "LicenseRef-Smoke",
    "experiences": []
}
(pack / "manifest.json").write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
PY

"$VALIDATOR" "$PACK" --app-version 0.19.42 --json >/dev/null \
  || fail "source fixture did not pass the unchanged validator"

manifest_before="$(shasum -a 256 "$PACK/manifest.json" | awk '{print $1}')"
check_receipt="$("$AUTHOR" "$PACK" \
  --id ritual.shared-win \
  --kind ritual \
  --trigger taskCompleted \
  --trigger taskStarted \
  --step workday-video:enter:700:crossfade \
  --step workday-video:react::cut \
  --step workday-video:exit::crossfade \
  --locale en \
  --cooldown 900 \
  --weight 1.5 \
  --return-policy previousMode \
  --check --json)"
RECEIPT_JSON="$check_receipt" python3 - <<'PY'
import json, os
value = json.loads(os.environ["RECEIPT_JSON"])
assert value["status"] == "PASS" and value["code"] is None, value
assert value["operation"] == "check" and value["writesPerformed"] is False, value
assert value["backupReference"] is None, value
assert (value["stepCount"], value["triggerCount"], value["localeCount"]) == (3, 2, 1), value
PY
assert_private_path_safe "$check_receipt"
manifest_after="$(shasum -a 256 "$PACK/manifest.json" | awk '{print $1}')"
[[ "$manifest_before" == "$manifest_after" \
  && ! -e "$SMOKE_ROOT/.workday-pack.chengyin-experience-backups" ]] \
  || fail "check mode wrote the pack or created a backup"

create_receipt="$("$AUTHOR" "$PACK" \
  --id ritual.shared-win \
  --kind ritual \
  --trigger taskCompleted \
  --trigger taskStarted \
  --step workday-video:enter:700:crossfade \
  --step workday-video:react::cut \
  --step workday-video:exit::crossfade \
  --locale en \
  --cooldown 900 \
  --weight 1.5 \
  --return-policy previousMode \
  --json)"
RECEIPT_JSON="$create_receipt" PACK_PATH="$PACK" python3 - <<'PY'
import json, os
from pathlib import Path
value = json.loads(os.environ["RECEIPT_JSON"])
assert value["status"] == "PASS" and value["operation"] == "create", value
assert value["writesPerformed"] is True and value["backupReference"], value
manifest = json.loads((Path(os.environ["PACK_PATH"]) / "manifest.json").read_text())
experience = manifest["experiences"][0]
assert list(experience) == [
    "cooldownSeconds", "id", "kind", "locales", "returnPolicy", "steps", "triggers", "weight"
], experience
assert [step["role"] for step in experience["steps"]] == ["enter", "react", "exit"], experience
assert experience["triggers"] == ["taskCompleted", "taskStarted"], experience
backup = Path(os.environ["PACK_PATH"]).parent / value["backupReference"]
assert backup.is_file() and not backup.is_symlink(), backup
assert backup.stat().st_mode & 0o777 == 0o600, oct(backup.stat().st_mode)
PY
assert_private_path_safe "$create_receipt"
"$VALIDATOR" "$PACK" --app-version 0.19.42 --json >/dev/null \
  || fail "created experience did not pass the canonical validator"

duplicate_before="$(shasum -a 256 "$PACK/manifest.json" | awk '{print $1}')"
expect_failure EXPERIENCE_AUTHOR_DUPLICATE_ID \
  "$AUTHOR" "$PACK" --id ritual.shared-win --kind reaction \
  --trigger singleTap --step workday-video:react --json
duplicate_after="$(shasum -a 256 "$PACK/manifest.json" | awk '{print $1}')"
[[ "$duplicate_before" == "$duplicate_after" ]] \
  || fail "duplicate rejection changed the manifest"

replace_receipt="$("$AUTHOR" "$PACK" \
  --id ritual.shared-win --kind reaction --trigger doubleTap \
  --step workday-video:react:1200:crossfade \
  --return-policy remainExpanded --replace --json)"
RECEIPT_JSON="$replace_receipt" PACK_PATH="$PACK" python3 - <<'PY'
import json, os
from pathlib import Path
value = json.loads(os.environ["RECEIPT_JSON"])
assert value["status"] == "PASS" and value["operation"] == "replace", value
manifest = json.loads((Path(os.environ["PACK_PATH"]) / "manifest.json").read_text())
assert len(manifest["experiences"]) == 1, manifest
experience = manifest["experiences"][0]
assert experience == {
    "id": "ritual.shared-win",
    "kind": "reaction",
    "returnPolicy": "remainExpanded",
    "steps": [{
        "assetID": "workday-video", "minimumPlaybackMs": 1200,
        "role": "react", "transition": "crossfade"
    }],
    "triggers": ["doubleTap"]
}, experience
PY
assert_private_path_safe "$replace_receipt"

for expected_and_args in \
  "EXPERIENCE_AUTHOR_ASSET_NOT_FOUND|missing-video:react" \
  "EXPERIENCE_AUTHOR_ASSET_NOT_VIDEO|localized-copy:react" \
  "EXPERIENCE_AUTHOR_INVALID_STEP|workday-video:unknown"; do
  expected="${expected_and_args%%|*}"
  step="${expected_and_args#*|}"
  expect_failure "$expected" \
    "$AUTHOR" "$PACK" --id reaction.invalid --kind reaction \
    --trigger singleTap --step "$step" --json
done

expect_failure EXPERIENCE_AUTHOR_INVALID_ARGUMENT \
  "$AUTHOR" "$PACK" --id reaction.invalid --kind reaction \
  --trigger singleTap --step workday-video:react --unknown-option --json

ln -s "$PACK" "$SMOKE_ROOT/linked-pack"
expect_failure EXPERIENCE_AUTHOR_UNSAFE_INPUT \
  "$AUTHOR" "$SMOKE_ROOT/linked-pack" --id reaction.invalid --kind reaction \
  --trigger singleTap --step workday-video:react --json

rollback_before="$(shasum -a 256 "$PACK/manifest.json" | awk '{print $1}')"
set +e
rollback_receipt="$("$AUTHOR" "$PACK" \
  --id reaction.locale-rollback --kind reaction --trigger singleTap \
  --step workday-video:react --locale fr --json 2>&1)"
rollback_status=$?
set -e
[[ "$rollback_status" -eq 1 ]] || fail "post-write validation failure was accepted"
RECEIPT_JSON="$rollback_receipt" python3 - <<'PY'
import json, os
value = json.loads(os.environ["RECEIPT_JSON"])
assert value["code"] == "EXPERIENCE_AUTHOR_VALIDATION_FAILED", value
assert value["rolledBack"] is True and value["backupReference"], value
PY
assert_private_path_safe "$rollback_receipt"
rollback_after="$(shasum -a 256 "$PACK/manifest.json" | awk '{print $1}')"
[[ "$rollback_before" == "$rollback_after" ]] \
  || fail "failed post-write validation did not restore the exact manifest"

"$VALIDATOR" "$PACK" --app-version 0.19.42 --json >/dev/null \
  || fail "final authored fixture no longer validates"
find "$PACK" -name '.DS_Store' -o -name '__pycache__' | grep -q . \
  && fail "authoring flow contaminated the pack"

print "Content Pack experience authoring smoke: PASS (12/12, check/create/replace/reject/rollback/privacy)"
