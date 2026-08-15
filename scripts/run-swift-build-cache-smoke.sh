#!/usr/bin/env bash

set -u
set -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-swift-cache-smoke.XXXXXX")"
project_root="$smoke_root/project"

cleanup() {
  if [ -n "${smoke_root:-}" ] \
    && [ "$smoke_root" != "/" ] \
    && [ -d "$smoke_root" ]; then
    /bin/rm -rf "$smoke_root"
  fi
}
trap cleanup EXIT

source "$script_dir/swift-build-cache.sh"
mkdir -p "$project_root"

checks=0
failures=0

pass() {
  checks=$((checks + 1))
  echo "PASS  $1"
}

fail() {
  checks=$((checks + 1))
  failures=$((failures + 1))
  echo "FAIL  $1"
}

cache_parent="$smoke_root/cache"
first="$(
  CHENGYIN_SWIFT_BUILD_CACHE_ROOT="$cache_parent" \
    chengyin_swift_build_root "$project_root" app-release
)"
physical_cache_parent="$(cd "$cache_parent" && pwd -P)"
if [ -d "$first" ] \
  && [ "${first#"$physical_cache_parent"/}" != "$first" ]; then
  pass "default external cache"
else
  fail "default external cache"
fi

second="$(
  CHENGYIN_SWIFT_BUILD_CACHE_ROOT="$cache_parent" \
    chengyin_swift_build_root "$project_root" app-release
)"
if [ "$first" = "$second" ]; then
  pass "same project and lane are stable"
else
  fail "same project and lane are stable"
fi

doctor="$(
  CHENGYIN_SWIFT_BUILD_CACHE_ROOT="$cache_parent" \
    chengyin_swift_build_root "$project_root" doctor-release
)"
if [ "$doctor" != "$first" ] && [ -d "$doctor" ]; then
  pass "independent build lanes"
else
  fail "independent build lanes"
fi

set +e
relative_error="$(
  CHENGYIN_SWIFT_BUILD_CACHE_ROOT="relative/cache" \
    chengyin_swift_build_root "$project_root" app-release 2>&1
)"
relative_exit=$?
set -e
if [ "$relative_exit" -eq 64 ] \
  && [ "$relative_error" = "SWIFT_BUILD_CACHE_INVALID_ARGUMENT" ]; then
  pass "relative override rejected"
else
  fail "relative override rejected"
fi

set +e
pollution_error="$(
  CHENGYIN_SWIFT_BUILD_CACHE_ROOT="$project_root/derived" \
    chengyin_swift_build_root "$project_root" app-release 2>&1
)"
pollution_exit=$?
set -e
if [ "$pollution_exit" -eq 65 ] \
  && [ "$pollution_error" = "SWIFT_BUILD_CACHE_SOURCE_POLLUTION" ]; then
  pass "source-tree cache rejected"
else
  fail "source-tree cache rejected"
fi

mkdir -p "$project_root/symlink-target"
ln -s "$project_root/symlink-target" "$smoke_root/symlink-cache"
set +e
symlink_error="$(
  CHENGYIN_SWIFT_BUILD_CACHE_ROOT="$smoke_root/symlink-cache" \
    chengyin_swift_build_root "$project_root" app-release 2>&1
)"
symlink_exit=$?
set -e
if [ "$symlink_exit" -eq 65 ] \
  && [ "$symlink_error" = "SWIFT_BUILD_CACHE_SOURCE_POLLUTION" ]; then
  pass "symlink back into source rejected"
else
  fail "symlink back into source rejected"
fi

printf 'not a directory\n' > "$smoke_root/not-a-directory"
set +e
unavailable_error="$(
  CHENGYIN_SWIFT_BUILD_CACHE_ROOT="$smoke_root/not-a-directory" \
    chengyin_swift_build_root "$project_root" app-release 2>&1
)"
unavailable_exit=$?
set -e
if [ "$unavailable_exit" -eq 73 ] \
  && [ "$unavailable_error" = "SWIFT_BUILD_CACHE_UNAVAILABLE" ]; then
  pass "unavailable cache rejected"
else
  fail "unavailable cache rejected"
fi

set +e
lane_error="$(
  CHENGYIN_SWIFT_BUILD_CACHE_ROOT="$cache_parent" \
    chengyin_swift_build_root "$project_root" '../escape' 2>&1
)"
lane_exit=$?
set -e
if [ "$lane_exit" -eq 64 ] \
  && [ "$lane_error" = "SWIFT_BUILD_CACHE_INVALID_ARGUMENT" ]; then
  pass "invalid lane rejected"
else
  fail "invalid lane rejected"
fi

if [ "$failures" -ne 0 ]; then
  echo "Swift build cache smoke: FAIL ($failures/$checks)"
  exit 1
fi
echo "Swift build cache smoke: PASS ($checks/$checks)"
