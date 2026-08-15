#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
CHECK_ONLY=0
SOURCE_ONLY=0
MINIMUM_FREE_KB=$((2 * 1024 * 1024))

usage() {
  echo "Usage: ./scripts/bootstrap-local.sh [--check-only] [--source-only]"
  echo
  echo "  --check-only  Inspect this Mac without building or installing anything."
  echo "  --source-only With --check-only, do not inspect the install target; report it pending."
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --check-only)
      CHECK_ONLY=1
      ;;
    --source-only)
      SOURCE_ONLY=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ "$SOURCE_ONLY" -eq 1 && "$CHECK_ONLY" -ne 1 ]]; then
  echo "--source-only is valid only with --check-only." >&2
  usage >&2
  exit 2
fi

fail() {
  echo "FAIL  $1" >&2
  exit 1
}

pass() {
  echo "PASS  $1"
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "Chengyin Companion currently requires macOS."
fi

macos_version="$(sw_vers -productVersion)"
macos_major="${macos_version%%.*}"
if [[ "$macos_major" != <-> || "$macos_major" -lt 14 ]]; then
  fail "macOS 14 or newer is required; found $macos_version."
fi
pass "macOS $macos_version"

architecture="$(uname -m)"
if [[ "$architecture" != "arm64" ]]; then
  fail "The current Starter build supports Apple Silicon; found $architecture."
fi
pass "Apple Silicon"

if ! xcode-select -p >/dev/null 2>&1; then
  fail "Xcode Command Line Tools are missing. Run: xcode-select --install"
fi
pass "Xcode Command Line Tools"

if ! command -v swift >/dev/null 2>&1; then
  fail "Swift is unavailable after Command Line Tools setup."
fi
swift_version="$(swift --version 2>&1 | awk 'NR == 1 { print; exit }')"
pass "$swift_version"

if [[ ! -x "$SCRIPT_DIR/check-python-runtime.sh" ]]; then
  fail "Repository is incomplete: missing executable scripts/check-python-runtime.sh."
fi
set +e
python_runtime_receipt="$($SCRIPT_DIR/check-python-runtime.sh 2>&1)"
python_runtime_status=$?
set -e
print -r -- "$python_runtime_receipt"
[[ "$python_runtime_status" -eq 0 ]] || exit "$python_runtime_status"

for required_file in Package.swift Info.plist AGENTS.md scripts/doctor.sh scripts/install-local-app.sh scripts/swift-toolchain-env.sh scripts/check-python-runtime.sh; do
  if [[ ! -f "$PROJECT_DIR/$required_file" ]]; then
    fail "Repository is incomplete: missing $required_file."
  fi
done
pass "Repository structure"

source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"
pass "Compatible macOS SDK"

available_kb="$(df -Pk "$PROJECT_DIR" | awk 'NR == 2 { print $4 }')"
if [[ "$available_kb" != <-> || "$available_kb" -lt "$MINIMUM_FREE_KB" ]]; then
  fail "At least 2 GB of free workspace storage is required."
fi
pass "Workspace free space"

if [[ "$SOURCE_ONLY" -eq 1 ]]; then
  echo "PENDING  Local Applications install target — zero-authorization source-only mode did not inspect or modify it."
  echo "RECOVERY Rerun --check-only without --source-only only when the owner permits local installation validation."
else
  if [[ ! -w "/Applications" ]]; then
    fail "/Applications is not writable by this account; use an administrator account for the source install."
  fi
  pass "Local Applications install target"
fi

echo "INFO  This flow is local-only: it does not call Seedance/TTS, read API keys, edit Codex config, enable a microphone, create an account or upload diagnostics."

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  if [[ "$SOURCE_ONLY" -eq 1 ]]; then
    echo "Bootstrap source preflight: PASS_WITH_PENDING"
  else
    echo "Bootstrap preflight: PASS"
  fi
  exit 0
fi

cd "$PROJECT_DIR"

echo "STEP  1/4  Validate privacy and lifecycle contracts"
swift run --disable-sandbox CompanionContractChecks

echo "STEP  2/4  Validate the executable-free example content pack"
./scripts/validate-content-pack.sh examples/packs/hello-workday --json

echo "STEP  3/4  Build, transactionally install and relaunch"
./scripts/install-local-app.sh

echo "STEP  4/4  Verify the installed and running product"
./scripts/doctor.sh

echo "Bootstrap result: PASS"
echo "Chengyin Companion is installed in /Applications and running."
echo "Codex task notifications remain opt-in and were not configured."
