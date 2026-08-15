#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
scaffold="$project_dir/scripts/new-content-pack.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-pack-scaffold.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT INT TERM

fail() {
  print -u2 "FAIL  $1"
  exit 1
}

expect_failure() {
  local expected_code="$1"
  local expected_exit="$2"
  shift 2
  local receipt
  local actual_exit
  set +e
  receipt="$("$@")"
  actual_exit=$?
  set -e
  [[ "$actual_exit" -eq "$expected_exit" ]] \
    || fail "$expected_code returned $actual_exit instead of $expected_exit"
  SCAFFOLD_RECEIPT="$receipt" EXPECTED_CODE="$expected_code" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["SCAFFOLD_RECEIPT"])
assert receipt["status"] == "FAIL", receipt
assert receipt["code"] == os.environ["EXPECTED_CODE"], receipt
assert receipt["writesPerformed"] is False, receipt
assert receipt["destinationCreated"] is False, receipt
assert receipt["rightsInferred"] is False, receipt
assert receipt["recoveryAction"], receipt
encoded = json.dumps(receipt)
assert "/Users/" not in encoded and "/private/" not in encoded, receipt
PY
}

default_receipt="$($scaffold \
  "$fixture_root/default" \
  cc.example.default-draft \
  starter \
  en-US \
  --json)"
SCAFFOLD_RECEIPT="$default_receipt" PACK="$fixture_root/default" PROJECT="$project_dir" python3 - <<'PY'
import json, os, pathlib, plistlib
receipt = json.loads(os.environ["SCAFFOLD_RECEIPT"])
pack = pathlib.Path(os.environ["PACK"])
project = pathlib.Path(os.environ["PROJECT"])
manifest = json.loads((pack / "manifest.json").read_text(encoding="utf-8"))
with (project / "Info.plist").open("rb") as stream:
    version = plistlib.load(stream)["CFBundleShortVersionString"]
assert receipt["status"] == "PASS", receipt
assert receipt["contract"] == "chengyin.content-pack-scaffold/v1", receipt
assert receipt["contributionMode"] == "compatibility-v2", receipt
assert receipt["reviewState"] == "pending-creator-evidence", receipt
assert receipt["rightsInferred"] is False, receipt
assert receipt["atomicPublish"] is True, receipt
assert receipt["networkRequired"] is False, receipt
assert receipt["providerCredentialsRequired"] is False, receipt
assert receipt["releaseState"] == "NOT_PUBLIC_RELEASE_READY", receipt
assert manifest["minAppVersion"] == version, manifest
assert manifest["license"] == "LicenseRef-Pending-Creator-Review", manifest
assert manifest["contribution"] == {
    "rights": [],
    "accessibility": [],
    "fallback": {"strategy": "starter"},
}, manifest
assert "contractVersion" not in manifest["contribution"], manifest
assert all((pack / name).is_dir() for name in ("media", "localization", "games"))
encoded = json.dumps(receipt)
assert "/Users/" not in encoded and "/private/" not in encoded, receipt
PY
python3 -m json.tool "$fixture_root/default/manifest.json" >/dev/null
"$project_dir/scripts/validate-content-pack.sh" \
  "$fixture_root/default" --json >/dev/null
set +e
draft_audit="$($project_dir/scripts/audit-content-pack.sh \
  "$fixture_root/default" --strict --json)"
draft_exit=$?
set -e
[[ "$draft_exit" -eq 3 ]] || fail "strict draft audit did not remain pending"
DRAFT_AUDIT="$draft_audit" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["DRAFT_AUDIT"])
assert receipt["status"] == "PASS_WITH_WARNINGS", receipt
assert receipt["contributionMode"] == "compatibility-v2", receipt
assert receipt["contributionReady"] is False, receipt
assert receipt["qualityCandidate"] == "DRAFT", receipt
PY
print "PASS  atomic path-safe compatibility draft"

multi_receipt="$($scaffold \
  "$fixture_root/multi" \
  cc.example.global-draft \
  companion.luna \
  --locale zh-Hans \
  --locale en-US \
  --locale ja \
  --json)"
SCAFFOLD_RECEIPT="$multi_receipt" PACK="$fixture_root/multi" python3 - <<'PY'
import json, os, pathlib
receipt = json.loads(os.environ["SCAFFOLD_RECEIPT"])
manifest = json.loads((pathlib.Path(os.environ["PACK"]) / "manifest.json").read_text())
assert receipt["locales"] == ["zh-Hans", "en-US", "ja"], receipt
assert manifest["locales"] == receipt["locales"], manifest
assert manifest["character"] == "companion.luna", manifest
PY
print "PASS  multi-locale global draft"

expect_failure CREATOR_SCAFFOLD_INVALID_PACK_ID 2 \
  "$scaffold" "$fixture_root/bad-id" Bad_ID starter en --json
[[ ! -e "$fixture_root/bad-id" ]] || fail "invalid ID created a destination"
print "PASS  invalid pack ID rejected"

expect_failure CREATOR_SCAFFOLD_INVALID_CHARACTER 2 \
  "$scaffold" "$fixture_root/bad-character" cc.example.bad "../face" en --json
[[ ! -e "$fixture_root/bad-character" ]] || fail "invalid character created a destination"
print "PASS  invalid character rejected"

expect_failure CREATOR_SCAFFOLD_INVALID_LOCALE 2 \
  "$scaffold" "$fixture_root/bad-locale" cc.example.bad-locale starter xx_YY --json
[[ ! -e "$fixture_root/bad-locale" ]] || fail "invalid locale created a destination"
print "PASS  invalid locale rejected"

expect_failure CREATOR_SCAFFOLD_DUPLICATE_LOCALE 2 \
  "$scaffold" "$fixture_root/duplicate-locale" cc.example.duplicate starter \
  --locale en-US --locale en-us --json
[[ ! -e "$fixture_root/duplicate-locale" ]] || fail "duplicate locale created a destination"
print "PASS  duplicate locale rejected"

mkdir -p "$fixture_root/collision"
print -r -- 'preserve-me' > "$fixture_root/collision/sentinel"
expect_failure CREATOR_SCAFFOLD_DESTINATION_EXISTS 2 \
  "$scaffold" "$fixture_root/collision" cc.example.collision starter en --json
[[ "$(<"$fixture_root/collision/sentinel")" == "preserve-me" ]] \
  || fail "destination collision changed existing content"
print "PASS  destination collision preserved"

expect_failure CREATOR_SCAFFOLD_DESTINATION_PARENT_UNSAFE 2 \
  "$scaffold" "$fixture_root/missing-parent/sample" cc.example.parent starter en --json
[[ ! -e "$fixture_root/missing-parent" ]] || fail "unsafe parent was created"
print "PASS  unresolved parent rejected"

expect_failure CREATOR_SCAFFOLD_WRITE_FAILED 1 \
  env CHENGYIN_SCAFFOLD_FAIL_AFTER_MANIFEST=1 \
  "$scaffold" "$fixture_root/injected" cc.example.injected starter en --json
[[ ! -e "$fixture_root/injected" ]] || fail "injected failure kept a destination"
if find "$fixture_root" -maxdepth 1 -name '.injected.chengyin-staging-*' | grep -q .; then
  fail "injected failure leaked staging"
fi
print "PASS  injected failure rolled back"

expect_failure CREATOR_SCAFFOLD_INVALID_ARGUMENT 2 \
  "$scaffold" "$fixture_root/unknown" cc.example.unknown starter --remote --json
[[ ! -e "$fixture_root/unknown" ]] || fail "unknown option created a destination"
print "PASS  unknown option rejected"

python3 -m json.tool \
  "$project_dir/Schemas/content-pack-scaffold-receipt-v1.schema.json" >/dev/null
SCAFFOLD_SOURCE="$project_dir/scripts/create-content-pack.py" python3 - <<'PY'
import ast, os, pathlib
source = pathlib.Path(os.environ["SCAFFOLD_SOURCE"]).read_text(encoding="utf-8")
ast.parse(source, filename="create-content-pack.py", feature_version=(3, 9))
PY
print "Content-pack scaffold smoke: PASS (10/10)"
