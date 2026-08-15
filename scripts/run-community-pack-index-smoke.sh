#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_dir="${script_dir:h}"
auditor="$repo_dir/scripts/audit-community-pack-index.py"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-community-index.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT INT TERM

mkdir -p "$fixture_root/examples/packs" "$fixture_root/fixtures" "$fixture_root/empty-pack"
cp -R \
  "$repo_dir/examples/packs/hello-workday" \
  "$fixture_root/examples/packs/hello-workday"
cp -R \
  "$repo_dir/Tests/Fixtures/incomplete-contribution-pack" \
  "$fixture_root/fixtures/incomplete-contribution-pack"
cp "$repo_dir/community/index.json" "$fixture_root/index-valid.json"
ln -s \
  "$fixture_root/examples/packs/hello-workday" \
  "$fixture_root/linked-pack"

valid_receipt="$(
  python3 "$auditor" \
    "$fixture_root/index-valid.json" \
    --root "$fixture_root" \
    --json
)"
COMMUNITY_RECEIPT="$valid_receipt" python3 -c '
import json, os
receipt = json.loads(os.environ["COMMUNITY_RECEIPT"])
assert receipt["status"] == "PASS", receipt
assert receipt["entryCount"] == 1, receipt
assert receipt["networkUsed"] is False, receipt
assert receipt["executablePluginsAllowed"] is False, receipt
assert receipt["entries"][0]["qualityCandidate"] == "READY_FOR_LAB", receipt
assert receipt["entries"][0]["mediaValidationBackend"] in {
    "avfoundation",
    "avfoundation+fixed-ffmpeg-full-software-decode",
}, receipt
serialized = json.dumps(receipt)
assert "/Users/" not in serialized and "/Volumes/" not in serialized, receipt
'

make_case() {
  local name="$1"
  local output="$fixture_root/index-$name.json"
  python3 - "$fixture_root/index-valid.json" "$output" "$name" "$fixture_root" <<'PY'
import hashlib
import json
import pathlib
import sys

source, output, name, root = map(pathlib.Path, sys.argv[1:])
name = name.name
document = json.loads(source.read_text(encoding="utf-8"))
entry = document["entries"][0]

if name == "unknown-field":
    document["unexpected"] = True
elif name == "duplicate":
    document["entries"].append(dict(entry))
elif name == "traversal":
    entry["packPath"] = "../outside"
elif name == "hash-mismatch":
    entry["manifestSHA256"] = "0" * 64
    entry["review"]["reviewedManifestSHA256"] = "0" * 64
elif name == "review-hash-mismatch":
    entry["review"]["reviewedManifestSHA256"] = "0" * 64
elif name == "review-pending":
    entry["review"]["status"] = "pending"
elif name == "identity-mismatch":
    entry["packID"] = "cc.chengyin.example.different"
elif name == "manifest-missing":
    entry["packPath"] = "empty-pack"
elif name == "symlink":
    entry["packPath"] = "linked-pack"
elif name == "pack-not-ready":
    pack = root / "fixtures/incomplete-contribution-pack"
    manifest_path = pack / "manifest.json"
    payload = manifest_path.read_bytes()
    manifest = json.loads(payload)
    digest = hashlib.sha256(payload).hexdigest()
    entry["packID"] = manifest["id"]
    entry["version"] = manifest["version"]
    entry["packPath"] = "fixtures/incomplete-contribution-pack"
    entry["manifestSHA256"] = digest
    entry["review"]["reviewedManifestSHA256"] = digest
elif name == "corrupt-media":
    pack = root / "examples/packs/hello-workday"
    manifest_path = pack / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    asset = next(item for item in manifest["assets"] if item["kind"] == "video")
    media_path = pack / asset["path"]
    media_path.write_bytes(b"not a decodable video fixture")
    asset["sha256"] = hashlib.sha256(media_path.read_bytes()).hexdigest()
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    digest = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
    entry["manifestSHA256"] = digest
    entry["review"]["reviewedManifestSHA256"] = digest
elif name == "invalid-json":
    output.write_text("{", encoding="utf-8")
    raise SystemExit(0)
elif name == "oversized":
    output.write_bytes(b" " * (512 * 1024 + 1))
    raise SystemExit(0)
else:
    raise SystemExit(f"unknown fixture case: {name}")

output.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
PY
  print -r -- "$output"
}

expect_failure() {
  local name="$1"
  local expected_code="$2"
  local index_path
  local receipt
  local exit_code
  index_path="$(make_case "$name")"
  set +e
  receipt="$(
    python3 "$auditor" \
      "$index_path" \
      --root "$fixture_root" \
      --json \
      2>&1
  )"
  exit_code=$?
  set -e
  if [[ "$exit_code" -ne 1 ]]; then
    print -u2 "FAIL  $name returned $exit_code instead of 1"
    exit 1
  fi
  COMMUNITY_RECEIPT="$receipt" EXPECTED_CODE="$expected_code" python3 -c '
import json, os
receipt = json.loads(os.environ["COMMUNITY_RECEIPT"])
assert receipt["status"] == "FAIL", receipt
assert receipt["code"] == os.environ["EXPECTED_CODE"], receipt
assert receipt["message"], receipt
assert receipt["recoveryAction"], receipt
serialized = json.dumps(receipt)
assert "/Users/" not in serialized and "/Volumes/" not in serialized, receipt
'
}

expect_failure unknown-field COMMUNITY_INDEX_UNKNOWN_FIELD
expect_failure duplicate COMMUNITY_INDEX_DUPLICATE_ENTRY
expect_failure traversal COMMUNITY_INDEX_UNSAFE_PATH
expect_failure hash-mismatch COMMUNITY_INDEX_MANIFEST_HASH_MISMATCH
expect_failure review-hash-mismatch COMMUNITY_INDEX_REVIEW_HASH_MISMATCH
expect_failure review-pending COMMUNITY_INDEX_REVIEW_NOT_APPROVED
expect_failure identity-mismatch COMMUNITY_INDEX_IDENTITY_MISMATCH
expect_failure manifest-missing COMMUNITY_INDEX_MANIFEST_MISSING
expect_failure symlink COMMUNITY_INDEX_SYMLINK
expect_failure pack-not-ready COMMUNITY_INDEX_PACK_NOT_READY
expect_failure corrupt-media COMMUNITY_INDEX_PACK_NOT_READY
expect_failure invalid-json COMMUNITY_INDEX_INVALID_JSON
expect_failure oversized COMMUNITY_INDEX_PAYLOAD_TOO_LARGE

set +e
argument_receipt="$(python3 "$auditor" --unknown --json 2>&1)"
argument_status=$?
set -e
if [[ "$argument_status" -ne 1 ]]; then
  print -u2 "FAIL  invalid arguments returned $argument_status instead of 1"
  exit 1
fi
COMMUNITY_RECEIPT="$argument_receipt" python3 -c '
import json, os
receipt = json.loads(os.environ["COMMUNITY_RECEIPT"])
assert receipt["code"] == "COMMUNITY_INDEX_INVALID_ARGUMENT", receipt
'

print "Community pack index smoke: PASS (1 approved + 14 rejection cases)"
