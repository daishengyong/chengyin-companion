#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_dir="${script_dir:h}"
source "$repo_dir/scripts/swift-toolchain-env.sh"
source "$repo_dir/scripts/swift-build-cache.sh"
build_root="$(chengyin_swift_build_root "$repo_dir" core-policy-smokes)"
smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-core-smokes.XXXXXX")"
work_bin="$smoke_root/work-director-smoke"
chemistry_bin="$smoke_root/chemistry-director-smoke"
lifestyle_bin="$smoke_root/lifestyle-scheduler-smoke"
lifestyle_runtime_bin="$smoke_root/lifestyle-runtime-coordinator-smoke"
feedback_bin="$smoke_root/relationship-feedback-smoke"
watcher_bin="$smoke_root/codex-event-watcher-smoke"

cleanup() {
  rm -f "$work_bin" "$chemistry_bin" "$lifestyle_bin" "$lifestyle_runtime_bin" "$feedback_bin" "$watcher_bin"
  rmdir "$smoke_root" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

xcrun swiftc \
  "$repo_dir/Sources/CompanionContracts/CompanionEvent.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionWorkdayState.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionWorkDirector.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionWorkdaySignalTrustPolicy.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionWorkdayExperiencePolicy.swift" \
  "$repo_dir/scripts/work-director-smoke.swift" \
  -o "$work_bin"
"$work_bin"

xcrun swiftc \
  "$repo_dir/Sources/CompanionContracts/CompanionSettings.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionPlayPaletteLayout.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionWindowPolicy.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionPresentationEnvironment.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionChemistryInteractionDirector.swift" \
  "$repo_dir/scripts/chemistry-interaction-director-smoke.swift" \
  -o "$chemistry_bin"
"$chemistry_bin"

xcrun swiftc \
  "$repo_dir/Sources/CompanionContracts/CompanionLifestyleScheduler.swift" \
  "$repo_dir/scripts/lifestyle-scheduler-smoke.swift" \
  -o "$lifestyle_bin"
"$lifestyle_bin"

xcrun swiftc \
  -D COMPANION_STANDALONE_SMOKE \
  "$repo_dir/Sources/CompanionContracts/CompanionSettings.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionWorkdayState.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionLifestyleMemory.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionLifestyleScheduler.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionLifestyleMemoryAdapter.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionLifestyleRuntimeCoordinator.swift" \
  "$repo_dir/scripts/lifestyle-runtime-coordinator-smoke.swift" \
  -o "$lifestyle_runtime_bin"
"$lifestyle_runtime_bin"

xcrun swiftc \
  "$repo_dir/Sources/CompanionApp/CompanionLocalization.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionFeedbackPresentation.swift" \
  "$repo_dir/scripts/companion-feedback-smoke.swift" \
  -o "$feedback_bin"
"$feedback_bin"

swift build --build-path "$build_root" --disable-sandbox >/dev/null
build_bin="$(swift build --build-path "$build_root" --disable-sandbox --show-bin-path)"
contract_objects=("$build_bin"/CompanionContracts.build/*.swift.o)
xcrun swiftc \
  -I "$build_bin/Modules" \
  "$repo_dir/Sources/CompanionApp/CompanionLocalization.swift" \
  "$repo_dir/Sources/CompanionApp/Models.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionEventBridgeRepair.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionEventSpool.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionEventIngress.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionEventWatcher.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionServices.swift" \
  "$repo_dir/scripts/codex-event-watcher-smoke.swift" \
  "${contract_objects[@]}" \
  -o "$watcher_bin"
"$watcher_bin"
