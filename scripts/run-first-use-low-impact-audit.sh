#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
failures=0
pending=0
zero_authorization=0

usage() {
  echo "Usage: ./scripts/run-first-use-low-impact-audit.sh [--zero-authorization]"
  echo
  echo "  --zero-authorization  Validate source-only guarantees and report install/GUI gates pending."
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --zero-authorization)
      zero_authorization=1
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

pass() {
  echo "PASS  $1"
}

fail() {
  echo "FAIL  $1" >&2
  failures=$((failures + 1))
}

mark_pending() {
  echo "PENDING  $1"
  echo "RECOVERY $2"
  pending=$((pending + 1))
}

check_file() {
  if [[ -f "$1" ]]; then
    pass "$2"
  else
    fail "$2"
  fi
}

bootstrap_args=(--check-only)
preflight_label="New Mac source-install preflight"
if [[ "$zero_authorization" -eq 1 ]]; then
  bootstrap_args+=(--source-only)
  preflight_label="New Mac source prerequisites"
fi
if "$PROJECT_DIR/scripts/bootstrap-local.sh" "${bootstrap_args[@]}" >/dev/null; then
  pass "$preflight_label"
else
  fail "$preflight_label"
fi
if [[ "$zero_authorization" -eq 1 ]]; then
  mark_pending \
    "Local application replacement and on-screen GUI verification were not executed under the zero-authorization policy." \
    "Run the strict audit and transactional installer only when the owner permits installation validation."
fi

minimum_system="$(
  /usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' \
    "$PROJECT_DIR/Info.plist" 2>/dev/null || true
)"
if [[ "$minimum_system" == "14.0" ]]; then
  pass "Declared macOS 14 minimum"
else
  fail "Declared macOS 14 minimum"
fi

if /usr/libexec/PlistBuddy -c 'Print :NSMicrophoneUsageDescription' \
  "$PROJECT_DIR/Info.plist" >/dev/null 2>&1; then
  fail "No microphone permission declaration"
else
  pass "No microphone permission declaration"
fi

if grep -Eq '(^|[[:space:]])(curl|wget|osascript|open)([[:space:]]|$)' \
  "$PROJECT_DIR/scripts/bootstrap-local.sh"; then
  fail "Bootstrap has no network or GUI automation command"
else
  pass "Bootstrap has no network or GUI automation command"
fi

if grep -Eq '(ARK_API_KEY|VOLCENGINE_|ACCESS_TOKEN|SECRET_ACCESS_KEY)' \
  "$PROJECT_DIR/scripts/bootstrap-local.sh"; then
  fail "Bootstrap is independent of generation credentials"
else
  pass "Bootstrap is independent of generation credentials"
fi

check_file \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionPerformancePolicy.swift" \
  "Shared low-impact performance policy"
check_file \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionWindowPolicy.swift" \
  "Shared window placement policy"
check_file \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionPlayPaletteLayout.swift" \
  "Shared adaptive play-palette layout"
check_file \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionPresentationProjection.swift" \
  "Shared media projection policy"
check_file \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionPresentationEnvironment.swift" \
  "Shared accessible appearance and display-selection policy"
check_file \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionVideoPlayer.swift" \
  "Focused AVFoundation projection binding"
check_file \
  "$PROJECT_DIR/docs/FIRST-USE-AND-LOW-IMPACT-AUDIT.md" \
  "First-use and low-impact operator guide"

policy="$PROJECT_DIR/Sources/CompanionContracts/CompanionPerformancePolicy.swift"
settings="$PROJECT_DIR/Sources/CompanionContracts/CompanionSettings.swift"
contract_checks="$PROJECT_DIR/Tests/CompanionContractsTests/main.swift"
view_model="$PROJECT_DIR/Sources/CompanionApp/CompanionViewModel.swift"
app_shell="$PROJECT_DIR/Sources/CompanionApp/CompanionApp.swift"
content_view="$PROJECT_DIR/Sources/CompanionApp/ContentView.swift"
pet_interaction="$PROJECT_DIR/Sources/CompanionApp/CompanionPetInteractionSurface.swift"
video_player="$PROJECT_DIR/Sources/CompanionApp/CompanionVideoPlayer.swift"
projection_policy="$PROJECT_DIR/Sources/CompanionContracts/CompanionPresentationProjection.swift"

if grep -Fq 'reducedDynamicEffectsEnabled ? .audioOnly' "$policy" \
  && grep -Fq 'public var permitsLoopingVideo' "$policy" \
  && grep -Fq 'public var permitsVideoExperiences' "$policy" \
  && grep -Fq 'public var usesAnimatedTransitions' "$policy"; then
  pass "Low-impact media and transition gates"
else
  fail "Low-impact media and transition gates"
fi

if grep -Fq 'reducedDynamicEffectsEnabled' "$settings" \
  && grep -Fq 'decodeIfPresent' "$settings" \
  && grep -Fq 'Low-impact policy disables video work' "$contract_checks"; then
  pass "Low-impact preference migration and executable contract"
else
  fail "Low-impact preference migration and executable contract"
fi

if grep -Fq 'playbackMode = .audioOnly' "$view_model" \
  && grep -Fq 'contentSequenceRuntime.cancelActive()' "$view_model" \
  && grep -Fq 'interactionSpeaker.stop()' "$view_model"; then
  pass "Enabling low-impact stops active rich media"
else
  fail "Enabling low-impact stops active rich media"
fi

if grep -Fq 'animatesTransitions: !viewModel.reducedDynamicEffectsEnabled' "$app_shell" \
  && grep -Fq 'CompanionWindowPolicy.initialOrigin' "$app_shell" \
  && grep -Fq 'CompanionWindowPolicy.dockedPetOrigin' "$pet_interaction"; then
  pass "Low-impact window transitions and shared placement rules"
else
  fail "Low-impact window transitions and shared placement rules"
fi

if grep -Fq 'case staticFallback' "$projection_policy" \
  && grep -Fq 'reducedDynamicEffectsEnabled' "$projection_policy" \
  && grep -Fq 'playerLayer.frame = projection.playerLayerFrame(' "$video_player" \
  && grep -Fq 'atMilliseconds: currentMilliseconds' "$video_player"; then
  pass "Low-impact media projection and bounded crop geometry"
else
  fail "Low-impact media projection and bounded crop geometry"
fi

if python3 "$PROJECT_DIR/scripts/check-presentation-environment-integration.py" \
  >/dev/null; then
  pass "Accessible surfaces, multi-display recovery and privacy-minimal persistence"
else
  fail "Accessible surfaces, multi-display recovery and privacy-minimal persistence"
fi

if PYTHONDONTWRITEBYTECODE=1 python3 \
  "$PROJECT_DIR/scripts/audit-accessibility-localization.py" --json \
  >/dev/null; then
  pass "Bilingual critical-control semantics and stable accessibility identifiers"
else
  fail "Bilingual critical-control semantics and stable accessibility identifiers"
fi

if [[ "$failures" -eq 0 ]]; then
  if [[ "$pending" -gt 0 ]]; then
    echo "First-use and low-impact audit: PASS_WITH_PENDING ($pending owner gate)"
  else
    echo "First-use and low-impact audit: PASS"
  fi
  exit 0
fi

echo "First-use and low-impact audit: FAIL ($failures checks)" >&2
exit 1
