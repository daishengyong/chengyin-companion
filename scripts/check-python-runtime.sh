#!/bin/zsh
set -euo pipefail

MINIMUM_MAJOR=3
MINIMUM_MINOR=9
PYTHON_COMMAND="python3"
CHECK_VERSION=""
JSON_OUTPUT=0

usage() {
  print "Usage: ./scripts/check-python-runtime.sh [--json] [--command <python>] [--check-version <x.y.z>]"
  print
  print "  --json                 Emit a machine-readable, path-free receipt."
  print "  --command <python>     Probe a specific Python executable (default: python3)."
  print "  --check-version <x.y.z> Validate a deterministic version fixture without executing Python."
}

emit_failure() {
  local code="$1"
  local message="$2"
  local action="$3"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    printf '{"code":"%s","contract":"chengyin.python-runtime/v1","detectedVersion":null,"message":"%s","minimumVersion":"3.9","recoveryAction":"%s","schemaVersion":1,"status":"FAIL"}\n' \
      "$code" "$message" "$action"
  else
    print -u2 "FAIL  [$code] $message"
    print -u2 "ACTION  $action"
  fi
  exit 1
}

emit_unsupported() {
  local detected_version="$1"
  local message="Python 3.9 or newer is required; the detected interpreter is too old."
  local action="Install Python 3.9 or newer from python.org or Homebrew, ensure python3 resolves to it, then rerun the preflight."
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    printf '{"code":"SOURCE_BOOTSTRAP_PYTHON_UNSUPPORTED","contract":"chengyin.python-runtime/v1","detectedVersion":"%s","message":"%s","minimumVersion":"3.9","recoveryAction":"%s","schemaVersion":1,"status":"FAIL"}\n' \
      "$detected_version" "$message" "$action"
  else
    print -u2 "FAIL  [SOURCE_BOOTSTRAP_PYTHON_UNSUPPORTED] $message"
    print -u2 "ACTION  $action"
  fi
  exit 1
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_OUTPUT=1
      shift
      ;;
    --command)
      [[ "$#" -ge 2 ]] || emit_failure \
        "SOURCE_BOOTSTRAP_INVALID_ARGUMENT" \
        "The Python runtime checker is missing a command value." \
        "Provide --command followed by one executable name, then retry."
      PYTHON_COMMAND="$2"
      shift 2
      ;;
    --check-version)
      [[ "$#" -ge 2 ]] || emit_failure \
        "SOURCE_BOOTSTRAP_INVALID_ARGUMENT" \
        "The Python runtime checker is missing a version fixture." \
        "Provide --check-version followed by x.y.z, then retry."
      CHECK_VERSION="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      emit_failure \
        "SOURCE_BOOTSTRAP_INVALID_ARGUMENT" \
        "The Python runtime checker received an unknown option." \
        "Run scripts/check-python-runtime.sh --help, correct the command, then retry."
      ;;
  esac
done

if [[ -n "$CHECK_VERSION" ]]; then
  detected_version="$CHECK_VERSION"
else
  if ! command -v -- "$PYTHON_COMMAND" >/dev/null 2>&1; then
    emit_failure \
      "SOURCE_BOOTSTRAP_PYTHON_UNAVAILABLE" \
      "A usable Python 3 interpreter was not found." \
      "Install Python 3.9 or newer from python.org or Homebrew, ensure python3 is available, then rerun the preflight."
  fi
  if ! detected_version="$($PYTHON_COMMAND -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>/dev/null)"; then
    emit_failure \
      "SOURCE_BOOTSTRAP_PYTHON_UNAVAILABLE" \
      "The detected Python 3 interpreter could not run the compatibility probe." \
      "Install or select a working Python 3.9 or newer interpreter, then rerun the preflight."
  fi
fi

if [[ ! "$detected_version" =~ '^([0-9]+)\.([0-9]+)\.([0-9]+)$' ]]; then
  emit_failure \
    "SOURCE_BOOTSTRAP_PYTHON_UNAVAILABLE" \
    "The detected Python 3 interpreter returned an invalid version." \
    "Install or select a working Python 3.9 or newer interpreter, then rerun the preflight."
fi

major="${match[1]}"
minor="${match[2]}"
if (( major < MINIMUM_MAJOR || (major == MINIMUM_MAJOR && minor < MINIMUM_MINOR) )); then
  emit_unsupported "$detected_version"
fi

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '{"code":null,"contract":"chengyin.python-runtime/v1","detectedVersion":"%s","message":"Python runtime is compatible.","minimumVersion":"3.9","recoveryAction":null,"schemaVersion":1,"status":"PASS"}\n' \
    "$detected_version"
else
  print "PASS  Python $detected_version (minimum 3.9)"
fi
