#!/usr/bin/env bash

# Shared, read-only identity helpers for the local app build, installer and
# doctor. Keep this file compatible with macOS Bash 3.2 and zsh.

chengyin_plist_value() {
  local app_path="$1"
  local key="$2"
  /usr/libexec/PlistBuddy \
    -c "Print :$key" \
    "$app_path/Contents/Info.plist" \
    2>/dev/null
}

chengyin_source_fingerprint() {
  local repo_path="$1"
  (
    cd "$repo_path" || exit 1
    {
      printf '%s\0' \
        "Package.swift" \
        "Info.plist" \
        "scripts/build-app.sh" \
        "scripts/swift-build-cache.sh" \
        "scripts/swift-toolchain-env.sh" \
        "scripts/macos_process_inspection.py" \
        "scripts/install-local-app.sh" \
        "scripts/app-bundle-common.sh"
      find \
        Sources/CompanionApp \
        Sources/CompanionContracts \
        Tools/CompanionEventEmitter \
        -type f \
        ! -name '.DS_Store' \
        -print0
    } |
      sort -zu |
      while IFS= read -r -d '' relative_path; do
        if [ ! -f "$relative_path" ]; then
          continue
        fi
        printf '%s\0' "$relative_path"
        shasum -a 256 "$relative_path" | awk '{ printf "%s%c", $1, 0 }'
      done |
      shasum -a 256 |
      awk '{ print $1 }'
  )
}

chengyin_bundle_fingerprint() {
  local app_path="$1"
  (
    cd "$app_path" || exit 1
    find Contents \
      -type f \
      ! -name '.DS_Store' \
      -print0 |
      sort -z |
      while IFS= read -r -d '' relative_path; do
        printf '%s\0' "$relative_path"
        shasum -a 256 "$relative_path" | awk '{ printf "%s%c", $1, 0 }'
      done |
      shasum -a 256 |
      awk '{ print $1 }'
  )
}

chengyin_bundle_label() {
  local app_path="$1"
  local version
  local build
  local identity
  version="$(chengyin_plist_value "$app_path" CFBundleShortVersionString || true)"
  build="$(chengyin_plist_value "$app_path" CFBundleVersion || true)"
  identity="$(chengyin_plist_value "$app_path" ChengyinBuildIdentity || true)"

  if [ -z "$version" ]; then
    version="unknown"
  fi
  if [ -z "$build" ]; then
    build="unknown"
  fi
  if [ -z "$identity" ]; then
    identity="legacy-no-build-identity"
  fi
  printf '%s (%s), %s\n' "$version" "$build" "$identity"
}

chengyin_short_fingerprint() {
  printf '%.12s\n' "$1"
}

chengyin_apps_have_same_build_identity() {
  local candidate_path="$1"
  local installed_path="$2"
  local key
  local candidate_value
  local installed_value
  local source_fingerprint
  local expected_identity

  # Bundle contents are not a stable build identity: packaging timestamps and
  # ad-hoc code signatures can change across builds of the same source. Compare
  # the deterministic fields embedded by build-app.sh instead.
  for key in \
    CFBundleIdentifier \
    CFBundleShortVersionString \
    CFBundleVersion \
    ChengyinSourceFingerprint \
    ChengyinBuildIdentity; do
    candidate_value="$(
      chengyin_plist_value "$candidate_path" "$key" || true
    )"
    installed_value="$(
      chengyin_plist_value "$installed_path" "$key" || true
    )"
    if [ -z "$candidate_value" ] \
      || [ "$candidate_value" != "$installed_value" ]; then
      return 1
    fi
  done

  source_fingerprint="$(
    chengyin_plist_value "$candidate_path" ChengyinSourceFingerprint || true
  )"
  case "$source_fingerprint" in
    ''|*[!0-9a-f]*)
      return 1
      ;;
  esac
  if [ "${#source_fingerprint}" -ne 64 ]; then
    return 1
  fi

  expected_identity="$(
    chengyin_plist_value "$candidate_path" CFBundleShortVersionString
  )+$(
    chengyin_plist_value "$candidate_path" CFBundleVersion
  ).$(chengyin_short_fingerprint "$source_fingerprint")"
  candidate_value="$(
    chengyin_plist_value "$candidate_path" ChengyinBuildIdentity || true
  )"
  [ "$candidate_value" = "$expected_identity" ]
}

chengyin_user_state_fingerprint() {
  local user_home="$1"
  local preferences_path="$user_home/Library/Preferences/local.zidong.chengyin-companion.plist"
  local content_store_path="$user_home/Library/Application Support/Chengyin/content-store"
  local legacy_support_path="$user_home/Library/Application Support/ChengyinCompanion"

  {
    for state_path in \
      "$preferences_path" \
      "$content_store_path" \
      "$legacy_support_path"; do
      if [ -f "$state_path" ]; then
        printf 'file:%s\0' "$state_path"
        shasum -a 256 "$state_path" | awk '{ printf "%s%c", $1, 0 }'
      elif [ -d "$state_path" ]; then
        printf 'directory:%s\0' "$state_path"
        (
          cd "$state_path" || exit 1
          find . \
            -type f \
            ! -name '.pack-store.lock' \
            ! -name '.DS_Store' \
            -print0 |
            sort -z |
            while IFS= read -r -d '' relative_path; do
              printf '%s\0' "$relative_path"
              shasum -a 256 "$relative_path" |
                awk '{ printf "%s%c", $1, 0 }'
            done
        )
      else
        printf 'missing:%s\0' "$state_path"
      fi
    done
  } |
    shasum -a 256 |
    awk '{ print $1 }'
}
