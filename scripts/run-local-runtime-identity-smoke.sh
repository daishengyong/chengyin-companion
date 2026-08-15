#!/usr/bin/env bash

set -u
set -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
auditor="$script_dir/audit-local-runtime-identity.py"
common="$script_dir/app-bundle-common.sh"
smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-runtime-identity.XXXXXX")"
fixture_root="$smoke_root/source"

cleanup() {
  if [ -n "${smoke_root:-}" ] \
    && [ "$smoke_root" != "/" ] \
    && [ -d "$smoke_root" ]; then
    /bin/rm -rf "$smoke_root"
  fi
}
trap cleanup EXIT

source "$common"

mkdir -p \
  "$fixture_root/scripts" \
  "$fixture_root/Sources/CompanionApp" \
  "$fixture_root/Sources/CompanionContracts" \
  "$fixture_root/Tools/CompanionEventEmitter" \
  "$fixture_root/dist"
for relative in \
  Package.swift \
  Info.plist \
  scripts/build-app.sh \
  scripts/swift-build-cache.sh \
  scripts/swift-toolchain-env.sh \
  scripts/install-local-app.sh \
  scripts/app-bundle-common.sh \
  Sources/CompanionApp/App.swift \
  Sources/CompanionContracts/Policy.swift \
  Tools/CompanionEventEmitter/main.swift; do
  printf 'runtime identity fixture: %s\n' "$relative" \
    > "$fixture_root/$relative"
done

source_fingerprint="$(chengyin_source_fingerprint "$fixture_root")"
stale_fingerprint="$(printf '%064d' 0 | tr 0 b)"

make_app() {
  local app_path="$1"
  local fingerprint="$2"
  local identity_mode="${3:-valid}"
  local short

  short="$(chengyin_short_fingerprint "$fingerprint")"
  mkdir -p "$app_path/Contents/MacOS"
  plutil -create xml1 "$app_path/Contents/Info.plist"
  /usr/libexec/PlistBuddy \
    -c "Add :CFBundleIdentifier string local.zidong.chengyin-companion" \
    -c "Add :CFBundleShortVersionString string 0.19.37" \
    -c "Add :CFBundleVersion string 62" \
    -c "Add :ChengyinSourceFingerprint string $fingerprint" \
    -c "Add :ChengyinBuildIdentity string 0.19.37+62.$short" \
    "$app_path/Contents/Info.plist"
  if [ "$identity_mode" = "invalid" ]; then
    /usr/libexec/PlistBuddy \
      -c "Set :ChengyinBuildIdentity malformed" \
      "$app_path/Contents/Info.plist"
  fi
  printf '#!/bin/sh\nexit 0\n' \
    > "$app_path/Contents/MacOS/ChengyinCompanion"
  chmod +x "$app_path/Contents/MacOS/ChengyinCompanion"
}

dist_app="$fixture_root/dist/Chengyin Companion.app"
installed_current="$smoke_root/installed-current/Chengyin Companion.app"
installed_stale="$smoke_root/installed-stale/Chengyin Companion.app"
other_current="$smoke_root/copied/Chengyin Companion.app"
invalid_dist="$smoke_root/invalid/Chengyin Companion.app"
missing_install="$smoke_root/missing/Chengyin Companion.app"
make_app "$dist_app" "$source_fingerprint"
make_app "$installed_current" "$source_fingerprint"
make_app "$installed_stale" "$stale_fingerprint"
make_app "$other_current" "$source_fingerprint"
make_app "$invalid_dist" "$source_fingerprint" invalid

checks=0
failures=0

checks=$((checks + 1))
if grep -Fq 'audit-local-runtime-identity.py' "$repo_dir/scripts/doctor.sh" \
  && grep -Fq 'run-local-runtime-identity-smoke.sh' "$repo_dir/.github/workflows/ci.yml" \
  && grep -Fq 'scripts/audit-local-runtime-identity.py' "$repo_dir/scripts/build-portable-source.sh" \
  && grep -Fq 'scripts/macos_process_inspection.py' "$repo_dir/scripts/build-portable-source.sh" \
  && grep -Fq 'scripts/run-local-runtime-identity-smoke.sh' "$repo_dir/scripts/audit-portable-source.py" \
  && grep -Fq 'UI_RUNTIME_IDENTITY_INSTALL_REQUIRED' "$repo_dir/Schemas/error-codes-v1.json" \
  && grep -Fq 'UI_RUNTIME_IDENTITY_PROCESS_INSPECTION_UNAVAILABLE' "$repo_dir/Schemas/error-codes-v1.json" \
  && ! grep -Fq 'Running app PID' "$repo_dir/scripts/doctor.sh" \
  && ! grep -Fq 'Running app did not launch from the installed application' "$repo_dir/scripts/doctor.sh"; then
  echo "PASS  Doctor, CI, source package and stable-code integration"
else
  echo "FAIL  Doctor, CI, source package and stable-code integration"
  failures=$((failures + 1))
fi

expect_receipt() {
  local label="$1"
  local expected_exit="$2"
  local expected_status="$3"
  local expected_code="$4"
  shift 4
  local receipt
  local actual_exit

  set +e
  receipt="$(PYTHONDONTWRITEBYTECODE=1 python3 "$auditor" \
    --root "$fixture_root" \
    --json \
    "$@")"
  actual_exit=$?
  set -e
  checks=$((checks + 1))
  if RUNTIME_RECEIPT="$receipt" \
    EXPECTED_STATUS="$expected_status" \
    EXPECTED_CODE="$expected_code" \
    FORBIDDEN_ROOT="$smoke_root" \
    python3 - <<'PY'
import json
import os

receipt = json.loads(os.environ["RUNTIME_RECEIPT"])
assert receipt["status"] == os.environ["EXPECTED_STATUS"], receipt
expected_code = os.environ["EXPECTED_CODE"] or None
assert receipt["code"] == expected_code, receipt
assert receipt["contract"] == "chengyin.local-runtime-identity/v1", receipt
assert receipt["releaseState"] == "NOT_PUBLIC_RELEASE_READY", receipt
encoded = json.dumps(receipt, ensure_ascii=False)
assert os.environ["FORBIDDEN_ROOT"] not in encoded, receipt
assert "/Users/" not in encoded and "/Volumes/" not in encoded, receipt
PY
  then
    if [ "$actual_exit" -eq "$expected_exit" ]; then
      echo "PASS  $label"
      return
    fi
  fi
  echo "FAIL  $label"
  failures=$((failures + 1))
}

expect_receipt \
  "Current installed process" \
  0 PASS "" \
  --dist-app "$dist_app" \
  --installed-app "$installed_current" \
  --running-executable \
  "$installed_current/Contents/MacOS/ChengyinCompanion"

expect_receipt \
  "Current preview with stale installation" \
  2 PENDING UI_RUNTIME_IDENTITY_INSTALL_REQUIRED \
  --dist-app "$dist_app" \
  --installed-app "$installed_stale" \
  --running-executable "$dist_app/Contents/MacOS/ChengyinCompanion"

expect_receipt \
  "Stale running process" \
  1 FAIL UI_RUNTIME_IDENTITY_RUNNING_STALE \
  --dist-app "$dist_app" \
  --installed-app "$installed_stale" \
  --running-executable \
  "$installed_stale/Contents/MacOS/ChengyinCompanion"

expect_receipt \
  "Multiple running processes" \
  1 FAIL UI_RUNTIME_IDENTITY_MULTIPLE_PROCESSES \
  --dist-app "$dist_app" \
  --installed-app "$installed_current" \
  --running-executable "$dist_app/Contents/MacOS/ChengyinCompanion" \
  --running-executable \
  "$installed_current/Contents/MacOS/ChengyinCompanion"

expect_receipt \
  "Unverified copied application" \
  1 FAIL UI_RUNTIME_IDENTITY_ORIGIN_UNKNOWN \
  --dist-app "$dist_app" \
  --installed-app "$installed_current" \
  --running-executable "$other_current/Contents/MacOS/ChengyinCompanion"

expect_receipt \
  "Malformed local identity" \
  1 FAIL UI_RUNTIME_IDENTITY_INVALID \
  --dist-app "$invalid_dist" \
  --installed-app "$installed_current" \
  --running-executable \
  "$installed_current/Contents/MacOS/ChengyinCompanion"

expect_receipt \
  "Verified copies with no running process" \
  2 PENDING UI_RUNTIME_IDENTITY_RESTART_REQUIRED \
  --dist-app "$dist_app" \
  --installed-app "$installed_current" \
  --no-running-process

expect_receipt \
  "Current preview with missing installation" \
  2 PENDING UI_RUNTIME_IDENTITY_INSTALL_REQUIRED \
  --dist-app "$dist_app" \
  --installed-app "$missing_install" \
  --running-executable "$dist_app/Contents/MacOS/ChengyinCompanion"

if [ "$failures" -ne 0 ]; then
  echo "Local runtime identity smoke: FAIL ($failures/$checks)"
  exit 1
fi

echo "Local runtime identity smoke: PASS ($checks/$checks)"
