#!/usr/bin/env bash

set -u
set -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
common_script="$script_dir/app-bundle-common.sh"
smoke_tmp="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-update-identity.XXXXXX")"

source "$common_script"

cleanup() {
  if [ -n "${smoke_tmp:-}" ] \
    && [ "$smoke_tmp" != "/" ] \
    && [ -d "$smoke_tmp" ]; then
    /bin/rm -rf "$smoke_tmp"
  fi
}
trap cleanup EXIT

failures=0

make_app() {
  local app_path="$1"
  local version="$2"
  local build="$3"
  local source_fingerprint="$4"
  local timestamp="$5"
  local signature_marker="$6"
  local bundle_id="${7:-local.zidong.chengyin-companion}"
  local source_short

  source_short="$(chengyin_short_fingerprint "$source_fingerprint")"
  mkdir -p \
    "$app_path/Contents/MacOS" \
    "$app_path/Contents/_CodeSignature"
  plutil -create xml1 "$app_path/Contents/Info.plist"
  /usr/libexec/PlistBuddy \
    -c "Add :CFBundleIdentifier string $bundle_id" \
    -c "Add :CFBundleShortVersionString string $version" \
    -c "Add :CFBundleVersion string $build" \
    -c "Add :ChengyinSourceFingerprint string $source_fingerprint" \
    -c "Add :ChengyinBuildIdentity string $version+$build.$source_short" \
    -c "Add :ChengyinBuildTimestamp string $timestamp" \
    "$app_path/Contents/Info.plist"
  printf '%s\n' "deterministic executable fixture" \
    > "$app_path/Contents/MacOS/ChengyinCompanion"
  printf '%s\n' "$signature_marker" \
    > "$app_path/Contents/_CodeSignature/CodeResources"
}

expect_same() {
  local label="$1"
  local candidate_path="$2"
  local installed_path="$3"

  if chengyin_apps_have_same_build_identity \
    "$candidate_path" \
    "$installed_path"; then
    echo "PASS  $label"
  else
    echo "FAIL  $label"
    failures=$((failures + 1))
  fi
}

expect_different() {
  local label="$1"
  local candidate_path="$2"
  local installed_path="$3"

  if chengyin_apps_have_same_build_identity \
    "$candidate_path" \
    "$installed_path"; then
    echo "FAIL  $label"
    failures=$((failures + 1))
  else
    echo "PASS  $label"
  fi
}

fingerprint_a="$(
  printf '%064d' 0 | tr '0' 'a'
)"
fingerprint_b="$(
  printf '%064d' 0 | tr '0' 'b'
)"
candidate_app="$smoke_tmp/candidate.app"
rebuilt_app="$smoke_tmp/rebuilt.app"
different_source_app="$smoke_tmp/different-source.app"
different_version_app="$smoke_tmp/different-version.app"
different_build_app="$smoke_tmp/different-build.app"
different_bundle_app="$smoke_tmp/different-bundle.app"
invalid_identity_app="$smoke_tmp/invalid-identity.app"

make_app \
  "$candidate_app" \
  "0.19.1" \
  "24" \
  "$fingerprint_a" \
  "2026-07-30T16:59:29Z" \
  "signature-a"
make_app \
  "$rebuilt_app" \
  "0.19.1" \
  "24" \
  "$fingerprint_a" \
  "2026-07-30T17:19:27Z" \
  "signature-b"
make_app \
  "$different_source_app" \
  "0.19.1" \
  "24" \
  "$fingerprint_b" \
  "2026-07-30T17:19:27Z" \
  "signature-b"
make_app \
  "$different_version_app" \
  "0.19.2" \
  "24" \
  "$fingerprint_a" \
  "2026-07-30T17:19:27Z" \
  "signature-b"
make_app \
  "$different_build_app" \
  "0.19.1" \
  "25" \
  "$fingerprint_a" \
  "2026-07-30T17:19:27Z" \
  "signature-b"
make_app \
  "$different_bundle_app" \
  "0.19.1" \
  "24" \
  "$fingerprint_a" \
  "2026-07-30T17:19:27Z" \
  "signature-b" \
  "local.example.other-app"
cp -R "$rebuilt_app" "$invalid_identity_app"
/usr/libexec/PlistBuddy \
  -c "Set :ChengyinBuildIdentity invalid" \
  "$invalid_identity_app/Contents/Info.plist"

candidate_bundle_fingerprint="$(
  chengyin_bundle_fingerprint "$candidate_app"
)"
rebuilt_bundle_fingerprint="$(
  chengyin_bundle_fingerprint "$rebuilt_app"
)"
if [ "$candidate_bundle_fingerprint" = "$rebuilt_bundle_fingerprint" ]; then
  echo "FAIL  Fixture bundle fingerprints differ"
  failures=$((failures + 1))
else
  echo "PASS  Fixture bundle fingerprints differ"
fi

expect_same \
  "Timestamp/signature-only rebuild is current" \
  "$candidate_app" \
  "$rebuilt_app"
expect_different \
  "Different source is not current" \
  "$candidate_app" \
  "$different_source_app"
expect_different \
  "Different version is not current" \
  "$candidate_app" \
  "$different_version_app"
expect_different \
  "Different build is not current" \
  "$candidate_app" \
  "$different_build_app"
expect_different \
  "Different bundle identifier is not current" \
  "$candidate_app" \
  "$different_bundle_app"
expect_different \
  "Malformed build identity is not current" \
  "$candidate_app" \
  "$invalid_identity_app"

if [ "$failures" -ne 0 ]; then
  echo "Local update identity smoke: FAIL ($failures checks)"
  exit 1
fi

echo "Local update identity smoke: PASS"
