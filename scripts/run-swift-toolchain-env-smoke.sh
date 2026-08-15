#!/usr/bin/env bash

set -u
set -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-toolchain-smoke.XXXXXX")"
physical_smoke_root="$(cd "$smoke_root" && pwd -P)"

cleanup() {
  if [ -n "${smoke_root:-}" ] \
    && [ "$smoke_root" != "/" ] \
    && [ -d "$smoke_root" ]; then
    /bin/rm -rf "$smoke_root"
  fi
}
trap cleanup EXIT

printf 'not a directory\n' > "$smoke_root/unwritable-parent"
export TMPDIR="$smoke_root/tmp"
mkdir -p "$TMPDIR"
export CLANG_MODULE_CACHE_PATH="$smoke_root/unwritable-parent/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$smoke_root/unwritable-parent/swiftpm"

source "$script_dir/swift-toolchain-env.sh"

checks=0
failures=0
check() {
  local label="$1"
  shift
  checks=$((checks + 1))
  if "$@"; then
    echo "PASS  $label"
  else
    echo "FAIL  $label"
    failures=$((failures + 1))
  fi
}

case "$CLANG_MODULE_CACHE_PATH" in
  "$physical_smoke_root"/*) clang_fallback=0 ;;
  *) clang_fallback=1 ;;
esac
check "invalid Clang override falls back" test "$clang_fallback" -eq 0

case "$SWIFTPM_MODULECACHE_OVERRIDE" in
  "$physical_smoke_root"/*) swiftpm_fallback=0 ;;
  *) swiftpm_fallback=1 ;;
esac
check "invalid SwiftPM override falls back" test "$swiftpm_fallback" -eq 0

probe_source="$smoke_root/probe.swift"
printf '%s\n' 'import Foundation' > "$probe_source"
check "direct swiftc uses the resolved cache" \
  xcrun swiftc -typecheck "$probe_source"

check "resolved caches are regular directories" test \
  -d "$CLANG_MODULE_CACHE_PATH" \
  -a -d "$SWIFTPM_MODULECACHE_OVERRIDE"

physical_clang_cache="$(cd "$CLANG_MODULE_CACHE_PATH" && pwd -P)"
physical_swiftpm_cache="$(cd "$SWIFTPM_MODULECACHE_OVERRIDE" && pwd -P)"
check "resolved caches use one physical path spelling" test \
  "$CLANG_MODULE_CACHE_PATH" = "$physical_clang_cache" \
  -a "$SWIFTPM_MODULECACHE_OVERRIDE" = "$physical_swiftpm_cache"

unguarded_swiftc_scripts=0
for candidate in "$script_dir"/*.sh; do
  [ "$candidate" = "$script_dir/swift-toolchain-env.sh" ] && continue
  if grep -Eq '(^|[[:space:]])(xcrun[[:space:]]+)?swiftc([[:space:]\\]|$)' "$candidate" \
    && ! grep -Fq 'swift-toolchain-env.sh' "$candidate"; then
    unguarded_swiftc_scripts=$((unguarded_swiftc_scripts + 1))
  fi
done
check "every direct swiftc shell uses the shared preflight" test \
  "$unguarded_swiftc_scripts" -eq 0

check "SDK selection publication uses a unique regular staging file" \
  grep -Fq 'mktemp "$toolchain_tmp_root/.selected-sdk-${compiler_key:-unknown}.XXXXXX"' \
  "$script_dir/swift-toolchain-env.sh"

shared_preflight_tmp="$smoke_root/concurrent"
mkdir -p "$shared_preflight_tmp"
concurrent_status=0
for round in 1 2 3 4; do
  TMPDIR="$shared_preflight_tmp" bash -c \
    'source "$1" && test -n "$SDKROOT" && test -d "$CLANG_MODULE_CACHE_PATH"' \
    _ "$script_dir/swift-toolchain-env.sh" \
    >"$smoke_root/concurrent-a-$round.log" 2>&1 &
  concurrent_a_pid=$!
  TMPDIR="$shared_preflight_tmp" bash -c \
    'source "$1" && test -n "$SDKROOT" && test -d "$SWIFTPM_MODULECACHE_OVERRIDE"' \
    _ "$script_dir/swift-toolchain-env.sh" \
    >"$smoke_root/concurrent-b-$round.log" 2>&1 &
  concurrent_b_pid=$!
  wait "$concurrent_a_pid" || concurrent_status=1
  wait "$concurrent_b_pid" || concurrent_status=1
done
check "repeated concurrent preflights share one cache safely" test \
  "$concurrent_status" -eq 0

staging_leaks="$(
  find "$shared_preflight_tmp/chengyin-swift-toolchain-v2" \
    -maxdepth 1 -type f -name '.selected-sdk-*' -print 2>/dev/null \
    | wc -l | tr -d ' '
)"
check "concurrent SDK publication leaves no staging file" test \
  "$staging_leaks" -eq 0

if [ "$failures" -ne 0 ]; then
  echo "Swift toolchain environment smoke: FAIL ($failures/$checks)"
  exit 1
fi
echo "Swift toolchain environment smoke: PASS ($checks/$checks)"
