#!/usr/bin/env bash

# Resolve a stable, writable SwiftPM build root outside the source tree.
# Compatible with macOS Bash 3.2 and zsh.

chengyin_swift_build_root() {
  local project_dir="${1:-}"
  local lane="${2:-default}"
  local physical_project
  local cache_parent
  local project_key
  local candidate_root
  local physical_root
  local probe_file

  if [ -z "$project_dir" ] || [ ! -d "$project_dir" ]; then
    echo "SWIFT_BUILD_CACHE_INVALID_ARGUMENT" >&2
    return 64
  fi
  case "$lane" in
    ''|*[!A-Za-z0-9._-]*)
      echo "SWIFT_BUILD_CACHE_INVALID_ARGUMENT" >&2
      return 64
      ;;
  esac

  physical_project="$(cd "$project_dir" 2>/dev/null && pwd -P)"
  if [ -z "$physical_project" ]; then
    echo "SWIFT_BUILD_CACHE_INVALID_ARGUMENT" >&2
    return 64
  fi

  cache_parent="${CHENGYIN_SWIFT_BUILD_CACHE_ROOT:-${TMPDIR:-/tmp}/chengyin-swift-build-cache}"
  case "$cache_parent" in
    /*) ;;
    *)
      echo "SWIFT_BUILD_CACHE_INVALID_ARGUMENT" >&2
      return 64
      ;;
  esac

  project_key="$(printf '%s' "$physical_project" | shasum -a 256 | awk '{ print substr($1, 1, 16) }')"
  candidate_root="$cache_parent/$project_key-$lane"
  if ! mkdir -p "$candidate_root" 2>/dev/null; then
    echo "SWIFT_BUILD_CACHE_UNAVAILABLE" >&2
    return 73
  fi
  physical_root="$(cd "$candidate_root" 2>/dev/null && pwd -P)"
  if [ -z "$physical_root" ]; then
    echo "SWIFT_BUILD_CACHE_UNAVAILABLE" >&2
    return 73
  fi

  case "$physical_root/" in
    "$physical_project/"*)
      echo "SWIFT_BUILD_CACHE_SOURCE_POLLUTION" >&2
      return 65
      ;;
  esac

  probe_file="$(mktemp "$physical_root/.chengyin-write-probe.XXXXXX" 2>/dev/null)"
  if [ -z "$probe_file" ] || [ ! -f "$probe_file" ]; then
    echo "SWIFT_BUILD_CACHE_UNAVAILABLE" >&2
    return 73
  fi
  /bin/rm -f "$probe_file"
  printf '%s\n' "$physical_root"
}
