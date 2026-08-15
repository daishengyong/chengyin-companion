#!/bin/zsh

set -u
set -o pipefail

failures=0
warnings=0

pass() { print "PASS  $1"; }
warn() { print "WARN  $1"; warnings=$((warnings + 1)); }
fail() { print "FAIL  $1"; failures=$((failures + 1)); }

check_command() {
  local name="$1"
  local requirement="$2"
  if command -v "$name" >/dev/null 2>&1; then
    pass "$requirement"
  else
    fail "$requirement"
  fi
}

print "Chengyin Companion producer environment check"
print "This check does not install tools, read secret values, or call an API."

if [[ "$(uname -s)" == "Darwin" ]]; then
  pass "macOS detected"
  if [[ "$(uname -m)" == "arm64" ]]; then
    pass "Apple Silicon detected"
  else
    warn "The companion app package targets Apple Silicon; editing assets is still possible"
  fi
else
  warn "Non-macOS: editing is possible, but the companion app cannot be demonstrated locally"
fi

check_command unzip "ZIP extraction tool"
check_command shasum "SHA256 verification tool"
check_command ffmpeg "FFmpeg"
check_command ffprobe "FFprobe"
check_command python3 "Python 3"
check_command git "Git"

if command -v swift >/dev/null 2>&1; then
  pass "Swift toolchain (needed for source modification)"
else
  warn "Swift is missing; direct app installation and video editing still work"
fi

if xcode-select -p >/dev/null 2>&1; then
  pass "Xcode Command Line Tools"
else
  warn "Xcode Command Line Tools are missing; source builds will not work"
fi

if [[ -n "${ARK_API_KEY:-}" ]]; then
  pass "ARK_API_KEY is set (value hidden)"
else
  warn "ARK_API_KEY is not set; existing assets remain fully usable"
fi

if [[ -n "${VOLCENGINE_ACCOUNT_ACCESS_KEY_ID:-}" && -n "${VOLCENGINE_ACCOUNT_SECRET_ACCESS_KEY:-}" && -n "${CHENGYIN_TOS_BUCKET:-}" ]]; then
  pass "TOS reference-upload variables are set (values hidden)"
else
  warn "TOS variables are incomplete; only reference video/audio generation needs them"
fi

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$root_dir/SHA256SUMS.txt" ]]; then
  pass "Package checksum list exists"
else
  fail "Package checksum list exists"
fi

video_count="$(find "$root_dir/editorial-assets/app-resources" -type f -name '*.mov' 2>/dev/null | wc -l | tr -d ' ')"
mp3_count="$(find "$root_dir/editorial-assets/app-resources" -type f -name '*.mp3' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$video_count" == "26" ]]; then
  pass "26 final companion videos"
else
  fail "Expected 26 final companion videos; found $video_count"
fi
if [[ "$mp3_count" == "159" ]]; then
  pass "159 pre-generated MP3 voice lines"
else
  fail "Expected 159 MP3 voice lines; found $mp3_count"
fi

print "Summary: failures=$failures warnings=$warnings"
exit "$failures"
