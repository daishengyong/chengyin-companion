#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_dir="${script_dir:h}"
builder="$repo_dir/scripts/build-creator-tool.sh"
smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-creator-cache-smoke.XXXXXX")"
cache_root="$smoke_root/cache"
first_log="$smoke_root/first.log"
second_log="$smoke_root/second.log"
namespace_log="$smoke_root/namespace.log"
truncated_log="$smoke_root/truncated.log"
manifest_log="$smoke_root/manifest.log"

cleanup() {
  if [[ -n "${smoke_root:-}" \
    && "$smoke_root" == "${TMPDIR:-/tmp}"/chengyin-creator-cache-smoke.* \
    && -d "$smoke_root" ]]; then
    /bin/rm -rf "$smoke_root"
  fi
}
trap cleanup EXIT INT TERM

fail() {
  print -u2 "FAIL  $1"
  exit 1
}

first_binary="$(
  CHENGYIN_CREATOR_CACHE_ROOT="$cache_root" \
  CHENGYIN_CREATOR_BUILD_TRACE=1 \
  "$builder" validator 2>"$first_log"
)"
[[ -f "$first_binary" && ! -L "$first_binary" && -x "$first_binary" ]] \
  || fail "fresh cache did not produce a regular executable"
grep -Fq "CREATOR_TOOL_CACHE MISS validator" "$first_log" \
  || fail "fresh cache did not report a miss"

second_binary="$(
  CHENGYIN_CREATOR_CACHE_ROOT="$cache_root" \
  CHENGYIN_CREATOR_BUILD_TRACE=1 \
  "$builder" validator 2>"$second_log"
)"
[[ "$second_binary" == "$first_binary" ]] \
  || fail "cache hit returned a different binary"
grep -Fq "CREATOR_TOOL_CACHE HIT validator" "$second_log" \
  || fail "second build did not report a cache hit"

"$first_binary" \
  "$repo_dir/examples/packs/hello-workday" \
  --json >"$smoke_root/validator.json"
grep -Fq '"status" : "PASS"' "$smoke_root/validator.json" \
  || fail "cached validator did not execute the real example contract"

namespace_binary="$(
  CHENGYIN_CREATOR_CACHE_ROOT="$cache_root" \
  CHENGYIN_CREATOR_CACHE_NAMESPACE="smoke-v2" \
  CHENGYIN_CREATOR_BUILD_TRACE=1 \
  "$builder" validator 2>"$namespace_log"
)"
[[ "$namespace_binary" != "$first_binary" ]] \
  || fail "fingerprint namespace did not invalidate the cache"
grep -Fq "CREATOR_TOOL_CACHE MISS validator" "$namespace_log" \
  || fail "invalidated build did not report a cache miss"

first_manifest="${first_binary:h}/manifest.json"
namespace_manifest="${namespace_binary:h}/manifest.json"
for manifest in "$first_manifest" "$namespace_manifest"; do
  [[ -f "$manifest" && ! -L "$manifest" ]] \
    || fail "cache publication omitted its regular integrity manifest"
  python3 -m json.tool "$manifest" >/dev/null \
    || fail "cache manifest is not valid JSON"
  grep -Fq '"schemaVersion": "chengyin.creator-tool-cache-manifest/v1"' "$manifest" \
    || fail "cache manifest lost its versioned schema"
  grep -Fq '"compilerIdentitySHA256"' "$manifest" \
    || fail "cache manifest lost compiler identity"
  grep -Fq '"sdkIdentitySHA256"' "$manifest" \
    || fail "cache manifest lost SDK identity"
  grep -Fq '"sourceDigests"' "$manifest" \
    || fail "cache manifest lost source digests"
  manifest_contents="$(<"$manifest")"
  [[ "$manifest_contents" != *"/Users/"* \
    && "$manifest_contents" != *"/Volumes/"* ]] \
    || fail "cache manifest exposed a private absolute path"
done

printf 'truncated-cache' > "$first_binary"
set +e
truncated_receipt="$({
  CHENGYIN_CREATOR_CACHE_ROOT="$cache_root" \
  CHENGYIN_CREATOR_BUILD_TRACE=1 \
  "$builder" validator
} 2>"$truncated_log")"
truncated_status=$?
set -e
[[ "$truncated_status" -eq 1 ]] \
  || fail "truncated cached binary was accepted"
truncated_receipt="$(cat "$truncated_log")$truncated_receipt"
[[ "$truncated_receipt" == *"[CREATOR_TOOL_BUILD_CACHE_INVALID]"* \
  && "$truncated_receipt" == *"ACTION"* ]] \
  || fail "truncated cache lost its stable recovery receipt"
[[ "$truncated_receipt" != *"/Users/"* \
  && "$truncated_receipt" != *"/Volumes/"* ]] \
  || fail "truncated-cache receipt exposed a private absolute path"

chmod u+w "$namespace_manifest"
plutil -replace toolID -string audit "$namespace_manifest"
chmod 444 "$namespace_manifest"
set +e
manifest_receipt="$({
  CHENGYIN_CREATOR_CACHE_ROOT="$cache_root" \
  CHENGYIN_CREATOR_CACHE_NAMESPACE="smoke-v2" \
  CHENGYIN_CREATOR_BUILD_TRACE=1 \
  "$builder" validator
} 2>"$manifest_log")"
manifest_status=$?
set -e
[[ "$manifest_status" -eq 1 ]] \
  || fail "altered cache manifest was accepted"
manifest_receipt="$(cat "$manifest_log")$manifest_receipt"
[[ "$manifest_receipt" == *"[CREATOR_TOOL_BUILD_CACHE_INVALID]"* \
  && "$manifest_receipt" == *"ACTION"* ]] \
  || fail "altered manifest lost its stable recovery receipt"
[[ "$manifest_receipt" != *"/Users/"* \
  && "$manifest_receipt" != *"/Volumes/"* ]] \
  || fail "altered-manifest receipt exposed a private absolute path"

set +e
unknown_receipt="$("$builder" unsupported-tool 2>&1)"
unknown_status=$?
set -e
[[ "$unknown_status" -eq 1 ]] \
  || fail "unknown tool did not return a stable failure"
[[ "$unknown_receipt" == *"[CREATOR_TOOL_BUILD_UNKNOWN_TOOL]"* \
  && "$unknown_receipt" == *"ACTION"* ]] \
  || fail "unknown tool receipt lost its code or recovery action"
[[ "$unknown_receipt" != *"/Users/"* \
  && "$unknown_receipt" != *"/Volumes/"* ]] \
  || fail "unknown tool receipt exposed a private absolute path"

for wrapper in \
  validate-content-pack.sh \
  audit-content-pack.sh \
  audit-content-pack-locales.sh \
  audit-content-pack-archive.sh \
  preview-content-pack.sh \
  edit-content-pack-projection.sh \
  plan-content-pack-v2-migration.sh; do
  if grep -Fq "swiftc" "$repo_dir/scripts/$wrapper"; then
    fail "$wrapper still owns a duplicate compiler source list"
  fi
done

print "Creator-tool cache smoke: PASS (9/9)"
