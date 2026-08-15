#!/usr/bin/env bash

# Shared Swift toolchain preflight. A Command Line Tools update can leave the
# unversioned macOS SDK symlink ahead of the installed Swift compiler. Probe
# installed SDKs so contributors do not need to discover and export SDKROOT.

chengyin_writable_toolchain_cache() {
  local requested="${1:-}"
  local fallback="${2:-}"
  local namespace="${3:-}"
  local candidate
  local cache
  local physical
  local probe

  case "$namespace" in
    ""|*/*|.|..) return 1 ;;
  esac
  for candidate in "$requested" "$fallback"; do
    case "$candidate" in
      /*) ;;
      *) continue ;;
    esac
    if ! mkdir -p "$candidate" 2>/dev/null; then
      continue
    fi
    physical="$(cd "$candidate" 2>/dev/null && pwd -P)"
    if [ -z "$physical" ]; then
      continue
    fi
    case "$physical" in
      */"$namespace") cache="$physical" ;;
      *) cache="$physical/$namespace" ;;
    esac
    if ! mkdir -p "$cache" 2>/dev/null; then
      continue
    fi
    physical="$(cd "$cache" 2>/dev/null && pwd -P)"
    if [ -z "$physical" ]; then
      continue
    fi
    probe="$(mktemp "$physical/.chengyin-cache-probe.XXXXXX" 2>/dev/null)"
    if [ -z "$probe" ] || [ ! -f "$probe" ]; then
      continue
    fi
    /bin/rm -f "$probe"
    printf '%s\n' "$physical"
    return 0
  done
  echo "Swift toolchain cache is unavailable." >&2
  return 1
}

chengyin_configure_swift_toolchain() {
  local temp_parent
  local toolchain_tmp_root
  local probe_run_root
  local probe_source
  local probe_cache
  local developer_root
  local compiler_key
  local selection_file
  local cached_sdk
  local candidate
  local physical_candidate
  local seen_candidates
  local selected_sdk
  local selection_staging
  local cache_key
  local clang_namespace
  local swiftpm_namespace

  temp_parent="${TMPDIR:-/tmp}"
  mkdir -p "$temp_parent" || return 1
  temp_parent="$(cd "$temp_parent" 2>/dev/null && pwd -P)"
  [ -n "$temp_parent" ] || return 1
  toolchain_tmp_root="$temp_parent/chengyin-swift-toolchain-v2"
  mkdir -p "$toolchain_tmp_root" || return 1
  probe_run_root="$(mktemp -d "$toolchain_tmp_root/probe.XXXXXX")" || return 1
  probe_source="$probe_run_root/probe.swift"
  probe_cache="$probe_run_root/module-cache"
  mkdir -p "$probe_cache" || {
    rm -rf "$probe_run_root"
    return 1
  }
  printf '%s\n' 'import Foundation' > "$probe_source" || {
    rm -rf "$probe_run_root"
    return 1
  }

  developer_root="$(xcode-select -p 2>/dev/null || true)"
  if [ -z "$developer_root" ]; then
    echo "Swift toolchain unavailable. Install Xcode Command Line Tools." >&2
    rm -rf "$probe_run_root"
    return 1
  fi

  # `swift --version` may initialize the interactive driver and trap in a
  # restricted runtime even though the compiler is healthy. The creator tools
  # only require swiftc, so fingerprint and probe that executable directly.
  compiler_key="$(xcrun swiftc --version 2>/dev/null | shasum -a 256 | awk '{ print $1 }')"
  selection_file="$toolchain_tmp_root/selected-sdk-${compiler_key:-unknown}"
  cached_sdk=""
  if [ -f "$selection_file" ]; then
    IFS= read -r cached_sdk < "$selection_file" || cached_sdk=""
  fi

  seen_candidates="|"
  selected_sdk=""
  for candidate in \
    "$cached_sdk" \
    "${SDKROOT:-}" \
    "$developer_root/SDKs/MacOSX.sdk" \
    "$developer_root/SDKs"/MacOSX*.sdk; do
    if [ -z "$candidate" ] || [ ! -d "$candidate" ]; then
      continue
    fi
    physical_candidate="$(cd "$candidate" 2>/dev/null && pwd -P)"
    if [ -z "$physical_candidate" ]; then
      continue
    fi
    case "$seen_candidates" in
      *"|$physical_candidate|"*)
        continue
        ;;
    esac
    seen_candidates="${seen_candidates}${physical_candidate}|"
    if xcrun swiftc \
      -sdk "$physical_candidate" \
      -module-cache-path "$probe_cache" \
      -typecheck "$probe_source" \
      >/dev/null 2>&1; then
      selected_sdk="$physical_candidate"
      break
    fi
  done

  rm -rf "$probe_run_root"
  if [ -z "$selected_sdk" ]; then
    echo "No installed macOS SDK is compatible with the active Swift compiler." >&2
    echo "Recovery: update or reinstall Xcode Command Line Tools, then rerun." >&2
    return 1
  fi

  export SDKROOT="$selected_sdk"
  cache_key="$({
    printf '%s\n' "${compiler_key:-unknown}"
    printf '%s\n' "$selected_sdk"
    printf '%s\n' 'chengyin-toolchain-cache-v2'
  } | shasum -a 256 | awk '{ print substr($1, 1, 20) }')"
  [ -n "$cache_key" ] || return 1
  clang_namespace="clang-$cache_key"
  swiftpm_namespace="swiftpm-$cache_key"
  CLANG_MODULE_CACHE_PATH="$(
    chengyin_writable_toolchain_cache \
      "${CLANG_MODULE_CACHE_PATH:-}" \
      "$toolchain_tmp_root" \
      "$clang_namespace"
  )" || return 1
  SWIFTPM_MODULECACHE_OVERRIDE="$(
    chengyin_writable_toolchain_cache \
      "${SWIFTPM_MODULECACHE_OVERRIDE:-}" \
      "$toolchain_tmp_root" \
      "$swiftpm_namespace"
  )" || return 1
  export CLANG_MODULE_CACHE_PATH
  export SWIFTPM_MODULECACHE_OVERRIDE
  selection_staging="$(
    mktemp "$toolchain_tmp_root/.selected-sdk-${compiler_key:-unknown}.XXXXXX"
  )" || return 1
  if [ ! -f "$selection_staging" ] \
    || [ -L "$selection_staging" ] \
    || ! printf '%s\n' "$selected_sdk" > "$selection_staging"; then
    rm -f "$selection_staging"
    return 1
  fi
  if ! mv "$selection_staging" "$selection_file"; then
    rm -f "$selection_staging"
    return 1
  fi
}

chengyin_configure_swift_toolchain
