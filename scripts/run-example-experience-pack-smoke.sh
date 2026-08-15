#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
CHECKER="$SCRIPT_DIR/check-example-experience-pack.py"
SOURCE_PACK="$PROJECT_DIR/examples/packs/hello-workday"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-example-pack.XXXXXX")"
trap '/bin/rm -rf "$FIXTURE_ROOT"' EXIT INT TERM

python3 "$CHECKER" >/dev/null

expect_rejection() {
  local name="$1"
  local fixture="$FIXTURE_ROOT/$name"
  cp -R "$SOURCE_PACK" "$fixture"
  shift
  "$@" "$fixture"
  set +e
  local output
  output="$(python3 "$CHECKER" --pack "$fixture" 2>&1)"
  local command_status=$?
  set -e
  [[ "$command_status" -eq 1 ]] || {
    print -u2 "FAIL  canonical example case unexpectedly passed: $name"
    exit 1
  }
  [[ "$output" == "Canonical experience pack check: FAIL ("* ]] || {
    print -u2 "FAIL  canonical example case lost its stable failure envelope: $name"
    exit 1
  }
  [[ "$output" != *"/Users/"* && "$output" != *"/Volumes/"* ]] || {
    print -u2 "FAIL  canonical example case exposed an absolute path: $name"
    exit 1
  }
}

mutate_empty_experiences() {
  plutil -replace experiences -json '[]' "$1/manifest.json"
}

mutate_missing_locale() {
  plutil -replace locales -json '["zh-Hans"]' "$1/manifest.json"
}

mutate_role_order() {
  plutil -replace experiences.0.steps.1.role -string notice "$1/manifest.json"
}

mutate_direct_trigger() {
  plutil -replace assets.2.triggers -json '["singleTap"]' "$1/manifest.json"
}

mutate_audio_declaration() {
  plutil -replace assets.2.hasNativeAudio -bool NO "$1/manifest.json"
}

mutate_accessibility_locale() {
  plutil -remove contribution.accessibility.2.captions.en-US "$1/manifest.json"
}

mutate_fallback_coverage() {
  plutil -remove contribution.fallback.assets.4 "$1/manifest.json"
}

mutate_executable_asset() {
  cp "$1/media/shared-win-enter.mov" "$1/media/payload.sh"
  plutil -replace assets.2.path -string media/payload.sh "$1/manifest.json"
}

expect_rejection empty-experiences mutate_empty_experiences
expect_rejection missing-locale mutate_missing_locale
expect_rejection role-order mutate_role_order
expect_rejection direct-trigger mutate_direct_trigger
expect_rejection audio-declaration mutate_audio_declaration
expect_rejection accessibility-locale mutate_accessibility_locale
expect_rejection fallback-coverage mutate_fallback_coverage
expect_rejection executable-asset mutate_executable_asset

print "Canonical experience pack smoke: PASS (1 complete + 8 rejection cases)"
