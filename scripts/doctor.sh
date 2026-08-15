#!/usr/bin/env bash

set -u
set -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
common_script="$repo_dir/scripts/app-bundle-common.sh"
build_cache_script="$repo_dir/scripts/swift-build-cache.sh"
installed_app="/Applications/Chengyin Companion.app"
dist_app="$repo_dir/dist/Chengyin Companion.app"
cd "$repo_dir" || exit 1

source "$common_script"
source "$repo_dir/scripts/swift-toolchain-env.sh"
source "$build_cache_script"

doctor_swift_build_root="$(
  chengyin_swift_build_root "$repo_dir" doctor-release
)" || exit 1

failures=0

check() {
  local label="$1"
  shift
  if "$@"; then
    echo "PASS  $label"
  else
    echo "FAIL  $label"
    failures=$((failures + 1))
  fi
}

check_file() {
  test -f "$1"
}

check_json() {
  python3 -m json.tool "$1" >/dev/null
}

echo "Chengyin Companion doctor"
echo "Workspace: $repo_dir"

if [[ ! -x "$repo_dir/scripts/check-python-runtime.sh" ]]; then
  echo "FAIL  Python runtime contract checker"
  exit 1
fi
if ! "$repo_dir/scripts/check-python-runtime.sh"; then
  exit 1
fi

check "Package manifest" check_file "$repo_dir/Package.swift"
check "Project instructions" check_file "$repo_dir/AGENTS.md"
check "Local-first product boundary" check_file "$repo_dir/docs/PRODUCT-BOUNDARY.md"
check "Local-first product boundary zh-Hans" check_file "$repo_dir/docs/PRODUCT-BOUNDARY.zh-Hans.md"
check "Contributor architecture" check_file "$repo_dir/docs/CONTRIBUTOR-ARCHITECTURE.md"
check "Compatibility policy" check_file "$repo_dir/docs/COMPATIBILITY.md"
check "Companion Event contract" check_file "$repo_dir/Sources/CompanionContracts/CompanionEvent.swift"
check "Content Pack v2 JSON Schema" \
  check_json "$repo_dir/Schemas/content-pack-v2.schema.json"
check "Projection authoring receipt JSON Schema" \
  check_json "$repo_dir/Schemas/projection-authoring-receipt-v1.schema.json"
check "Experience authoring receipt JSON Schema" \
  check_json "$repo_dir/Schemas/experience-authoring-receipt-v1.schema.json"
check "Stable error-code registry JSON" \
  check_json "$repo_dir/Schemas/error-codes-v1.json"
check "Codex App Server turn projection schema JSON" \
  check_json "$repo_dir/Schemas/codex-app-server-turn-events-v1.schema.json"
check "Release gate schema JSON" \
  check_json "$repo_dir/Schemas/release-gates-v1.schema.json"
check "Source-preview package schema JSON" \
  check_json "$repo_dir/Schemas/source-package-v1.schema.json"
check "Public Git bootstrap receipt schema JSON" \
  check_json "$repo_dir/Schemas/public-git-bootstrap-receipt-v1.schema.json"
check "Product boundary receipt schema JSON" \
  check_json "$repo_dir/Schemas/product-boundary-receipt-v1.schema.json"
check "Public source secret-audit schema JSON" \
  check_json "$repo_dir/Schemas/public-source-secret-audit-v1.schema.json"
check "All-game live reward receipt schema JSON" \
  check_json "$repo_dir/Schemas/all-game-rewards-v1.schema.json"
check "Core module boundary baseline JSON" \
  check_json "$repo_dir/Schemas/core-module-boundary-baseline-v1.json"
check "Starter media contract schema JSON" \
  check_json "$repo_dir/Schemas/starter-media-v1.schema.json"
check "Release gate registry JSON" \
  check_json "$repo_dir/release/release-gates.json"
check "Community pack index schema JSON" \
  check_json "$repo_dir/Schemas/community-pack-index-v1.schema.json"
check "Reviewed community pack index JSON" \
  check_json "$repo_dir/community/index.json"
check "Module stewardship schema JSON" \
  check_json "$repo_dir/Schemas/module-stewardship-v1.schema.json"
check "Module stewardship policy JSON" \
  check_json "$repo_dir/community/module-stewardship.json"
check "Build script syntax" zsh -n "$repo_dir/scripts/build-app.sh"
check "Swift build cache syntax" bash -n "$build_cache_script"
check "Swift build cache smoke" \
  "$repo_dir/scripts/run-swift-build-cache-smoke.sh"
check "Local installer syntax" zsh -n "$repo_dir/scripts/install-local-app.sh"
check "Local runtime identity auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/audit-local-runtime-identity.py', encoding='utf-8').read(), 'audit-local-runtime-identity.py', 'exec')"
check "Permission-minimal process inspection syntax" \
  python3 -c "compile(open('$repo_dir/scripts/macos_process_inspection.py', encoding='utf-8').read(), 'macos_process_inspection.py', 'exec')"
check "Local runtime identity smoke syntax" \
  bash -n "$repo_dir/scripts/run-local-runtime-identity-smoke.sh"
check "Direct-play runtime auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/audit-direct-play-runtime.py', encoding='utf-8').read(), 'audit-direct-play-runtime.py', 'exec')"
check "Direct-play window receipt typecheck" \
  xcrun swiftc -typecheck "$repo_dir/scripts/direct-play-window-audit.swift"
check "All-game reward auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/audit-all-game-rewards.py', encoding='utf-8').read(), 'audit-all-game-rewards.py', 'exec')"
check "All-game reward receipt contract syntax" \
  python3 -c "compile(open('$repo_dir/scripts/game_reward_receipt_contract.py', encoding='utf-8').read(), 'game_reward_receipt_contract.py', 'exec')"
check "All-game reward receipt matrix syntax" \
  python3 -c "compile(open('$repo_dir/scripts/run-game-reward-receipt-smoke.py', encoding='utf-8').read(), 'run-game-reward-receipt-smoke.py', 'exec')"
check "All-game reward integration syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-game-reward-audit-integration.py', encoding='utf-8').read(), 'check-game-reward-audit-integration.py', 'exec')"
check "catch game live audit typecheck" \
  xcrun swiftc -typecheck "$repo_dir/scripts/catch-game-smoke.swift"
check "hide game live audit typecheck" \
  xcrun swiftc -typecheck "$repo_dir/scripts/hide-game-smoke.swift"
check "combo game live audit typecheck" \
  xcrun swiftc -typecheck "$repo_dir/scripts/combo-game-smoke.swift"
check "heart-trace game live audit typecheck" \
  xcrun swiftc -typecheck "$repo_dir/scripts/heart-trace-smoke.swift"
check "rhythm game live audit typecheck" \
  xcrun swiftc -typecheck "$repo_dir/scripts/rhythm-game-smoke.swift"
check "feed game live audit typecheck" \
  xcrun swiftc -typecheck "$repo_dir/scripts/feed-game-smoke.swift"
check "Bounded event inbox integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-event-spool-integration.py', encoding='utf-8').read(), 'check-event-spool-integration.py', 'exec')"
check "Bounded event inbox smoke syntax" \
  zsh -n "$repo_dir/scripts/run-event-spool-smoke.sh"
check "Source bootstrap syntax" zsh -n "$repo_dir/scripts/bootstrap-local.sh"
check "Python runtime contract syntax" \
  zsh -n "$repo_dir/scripts/check-python-runtime.sh"
check "Python runtime contract smoke syntax" \
  zsh -n "$repo_dir/scripts/run-python-runtime-smoke.sh"
check "Python 3.9+ runtime contract" \
  "$repo_dir/scripts/run-python-runtime-smoke.sh"
check "Swift toolchain preflight syntax" \
  bash -n "$repo_dir/scripts/swift-toolchain-env.sh"
check "Swift toolchain cache fallback" \
  "$repo_dir/scripts/run-swift-toolchain-env-smoke.sh"
check "Creator tool build registry syntax" \
  zsh -n "$repo_dir/scripts/build-creator-tool.sh"
check "Creator tool cache smoke syntax" \
  zsh -n "$repo_dir/scripts/run-creator-tool-cache-smoke.sh"
check "Public source secret auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/audit-public-source-secrets.py', encoding='utf-8').read(), 'audit-public-source-secrets.py', 'exec')"
check "Public source secret matrix syntax" \
  zsh -n "$repo_dir/scripts/run-public-source-secret-audit-smoke.sh"
check "Product boundary auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/audit-product-boundary.py', encoding='utf-8').read(), 'audit-product-boundary.py', 'exec')"
check "Product boundary matrix syntax" \
  zsh -n "$repo_dir/scripts/run-product-boundary-smoke.sh"
check "Source bootstrap preflight" "$repo_dir/scripts/bootstrap-local.sh" --check-only
check "Creator validator syntax" zsh -n "$repo_dir/scripts/validate-content-pack.sh"
check "Content-pack archive auditor syntax" \
  zsh -n "$repo_dir/scripts/audit-content-pack-archive.sh"
check "Content-pack archive builder syntax" \
  zsh -n "$repo_dir/scripts/build-content-pack-archive.sh"
check "Content-pack archive builder implementation syntax" \
  python3 -c "compile(open('$repo_dir/scripts/build-content-pack-archive.py', encoding='utf-8').read(), 'build-content-pack-archive.py', 'exec')"
check "Content-pack archive integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-content-pack-archive-integration.py', encoding='utf-8').read(), 'check-content-pack-archive-integration.py', 'exec')"
check "Content-pack archive threat smoke syntax" \
  zsh -n "$repo_dir/scripts/run-content-pack-archive-smoke.sh"
check "Creator preview syntax" zsh -n "$repo_dir/scripts/preview-content-pack.sh"
check "Creator projection editor syntax" \
  zsh -n "$repo_dir/scripts/edit-content-pack-projection.sh"
check "Creator projection editor smoke syntax" \
  zsh -n "$repo_dir/scripts/run-content-pack-projection-editor-smoke.sh"
check "Projection receipt apply smoke syntax" \
  zsh -n "$repo_dir/scripts/run-projection-receipt-apply-smoke.sh"
check "Projection receipt applicator syntax" \
  python3 -c "compile(open('$repo_dir/scripts/apply-content-pack-projection.py', encoding='utf-8').read(), 'apply-content-pack-projection.py', 'exec')"
check "Experience author command syntax" \
  zsh -n "$repo_dir/scripts/author-content-pack-experience.sh"
check "Experience author applicator syntax" \
  python3 -c "compile(open('$repo_dir/scripts/apply-content-pack-experience.py', encoding='utf-8').read(), 'apply-content-pack-experience.py', 'exec')"
check "Experience authoring smoke syntax" \
  zsh -n "$repo_dir/scripts/run-content-pack-experience-authoring-smoke.sh"
check "Projection authoring integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-projection-authoring-integration.py', encoding='utf-8').read(), 'check-projection-authoring-integration.py', 'exec')"
check "Presentation environment integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-presentation-environment-integration.py', encoding='utf-8').read(), 'check-presentation-environment-integration.py', 'exec')"
check "Lifestyle memory integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-lifestyle-memory-integration.py', encoding='utf-8').read(), 'check-lifestyle-memory-integration.py', 'exec')"
check "Content operations integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-content-operations-integration.py', encoding='utf-8').read(), 'check-content-operations-integration.py', 'exec')"
check "Content-pack store modularity auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-content-pack-store-modularity.py', encoding='utf-8').read(), 'check-content-pack-store-modularity.py', 'exec')"
check "Content-pack validator modularity auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-content-pack-validator-modularity.py', encoding='utf-8').read(), 'check-content-pack-validator-modularity.py', 'exec')"
check "Shared-workday integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-workday-integration.py', encoding='utf-8').read(), 'check-workday-integration.py', 'exec')"
check "Shared-workday runtime coordinator smoke syntax" \
  zsh -n "$repo_dir/scripts/run-workday-runtime-coordinator-smoke.sh"
check "Shared-day integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-shared-day-integration.py', encoding='utf-8').read(), 'check-shared-day-integration.py', 'exec')"
check "Shared-day runtime coordinator smoke syntax" \
  zsh -n "$repo_dir/scripts/run-shared-day-runtime-coordinator-smoke.sh"
check "First-session integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-first-session-integration.py', encoding='utf-8').read(), 'check-first-session-integration.py', 'exec')"
check "First-session runtime coordinator smoke syntax" \
  zsh -n "$repo_dir/scripts/run-first-session-runtime-coordinator-smoke.sh"
check "English first-use visual audit integration syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-english-first-use-audit-integration.py', encoding='utf-8').read(), 'check-english-first-use-audit-integration.py', 'exec')"
check "English first-use visual audit wrapper syntax" \
  zsh -n "$repo_dir/scripts/run-english-first-use-visual-audit.sh"
check "English first-use visual audit smoke syntax" \
  zsh -n "$repo_dir/scripts/run-english-first-use-visual-audit-smoke.sh"
check "English first-use visual audit driver typecheck" \
  xcrun swiftc -typecheck "$repo_dir/scripts/english-first-use-visual-audit.swift"
check "Microgame integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-microgame-integration.py', encoding='utf-8').read(), 'check-microgame-integration.py', 'exec')"
check "Microgame runtime coordinator smoke syntax" \
  zsh -n "$repo_dir/scripts/run-microgame-runtime-coordinator-smoke.sh"
check "Experience runtime integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-experience-runtime-integration.py', encoding='utf-8').read(), 'check-experience-runtime-integration.py', 'exec')"
check "Experience runtime coordinator smoke syntax" \
  zsh -n "$repo_dir/scripts/run-experience-runtime-coordinator-smoke.sh"
check "Creator projection preview smoke syntax" \
  zsh -n "$repo_dir/scripts/run-content-pack-preview-projection-smoke.sh"
check "Creator audit syntax" zsh -n "$repo_dir/scripts/audit-content-pack.sh"
check "Creator locale matrix syntax" \
  zsh -n "$repo_dir/scripts/audit-content-pack-locales.sh"
check "Creator locale matrix smoke syntax" \
  zsh -n "$repo_dir/scripts/run-content-pack-locale-matrix-smoke.sh"
check "Creator error receipt runner syntax" \
  zsh -n "$repo_dir/scripts/run-creator-error-receipt-smoke.sh"
check "Contribution metadata runner syntax" \
  zsh -n "$repo_dir/scripts/run-contribution-metadata-smoke.sh"
check "Content-pack scaffold syntax" \
  python3 -c "compile(open('$repo_dir/scripts/create-content-pack.py', encoding='utf-8').read(), 'create-content-pack.py', 'exec')"
check "Content-pack scaffold wrapper syntax" \
  zsh -n "$repo_dir/scripts/new-content-pack.sh"
check "Content-pack scaffold matrix syntax" \
  zsh -n "$repo_dir/scripts/run-content-pack-scaffold-smoke.sh"
check "Content pack migration planner syntax" \
  zsh -n "$repo_dir/scripts/plan-content-pack-v2-migration.sh"
check "Content pack migration runner syntax" \
  zsh -n "$repo_dir/scripts/run-content-pack-migration-smoke.sh"
check "Content Pack v2 contract matrix syntax" \
  zsh -n "$repo_dir/scripts/run-content-pack-v2-contract-matrix.sh"
check "Codex App Server adapter smoke syntax" \
  zsh -n "$repo_dir/scripts/run-codex-app-server-adapter-smoke.sh"
check "First-use and low-impact audit syntax" \
  zsh -n "$repo_dir/scripts/run-first-use-low-impact-audit.sh"
check "Accessibility localization auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/audit-accessibility-localization.py', encoding='utf-8').read(), 'audit-accessibility-localization.py', 'exec')"
check "Accessibility localization smoke syntax" \
  zsh -n "$repo_dir/scripts/run-accessibility-localization-smoke.sh"
check "Release readiness smoke syntax" \
  zsh -n "$repo_dir/scripts/run-release-readiness-smoke.sh"
check "Source-preview package builder syntax" \
  zsh -n "$repo_dir/scripts/build-portable-source.sh"
check "Source-preview package smoke syntax" \
  zsh -n "$repo_dir/scripts/run-portable-source-smoke.sh"
check "Source-preview package auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/audit-portable-source.py', encoding='utf-8').read(), 'audit-portable-source.py', 'exec')"
check "Public Git bootstrap syntax" \
  python3 -c "compile(open('$repo_dir/scripts/bootstrap-public-git.py', encoding='utf-8').read(), 'bootstrap-public-git.py', 'exec')"
check "Public Git bootstrap smoke syntax" \
  zsh -n "$repo_dir/scripts/run-public-git-bootstrap-smoke.sh"
check "Source-preview ZIP creator syntax" \
  python3 -c "compile(open('$repo_dir/scripts/create-portable-source-zip.py', encoding='utf-8').read(), 'create-portable-source-zip.py', 'exec')"
check "Core module boundary auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/audit-core-module-boundaries.py', encoding='utf-8').read(), 'audit-core-module-boundaries.py', 'exec')"
check "Swift compiler boundary auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/audit-swift-compiler-boundaries.py', encoding='utf-8').read(), 'audit-swift-compiler-boundaries.py', 'exec')"
check "Swift compiler boundary smoke syntax" \
  zsh -n "$repo_dir/scripts/run-swift-compiler-boundary-smoke.sh"
check "SwiftPM package graph auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/audit-swiftpm-package-graph.py', encoding='utf-8').read(), 'audit-swiftpm-package-graph.py', 'exec')"
check "SwiftPM package graph smoke syntax" \
  zsh -n "$repo_dir/scripts/run-swiftpm-package-graph-smoke.sh"
check "Presentation runtime integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-presentation-runtime-integration.py', encoding='utf-8').read(), 'check-presentation-runtime-integration.py', 'exec')"
check "Pet feedback runtime integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-pet-feedback-runtime-integration.py', encoding='utf-8').read(), 'check-pet-feedback-runtime-integration.py', 'exec')"
check "Content library runtime integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-content-library-runtime-integration.py', encoding='utf-8').read(), 'check-content-library-runtime-integration.py', 'exec')"
check "Preference store integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-preference-store-integration.py', encoding='utf-8').read(), 'check-preference-store-integration.py', 'exec')"
check "Voice selection runtime integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-voice-selection-runtime-integration.py', encoding='utf-8').read(), 'check-voice-selection-runtime-integration.py', 'exec')"
check "Settings backup projection integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-settings-backup-projection-integration.py', encoding='utf-8').read(), 'check-settings-backup-projection-integration.py', 'exec')"
check "Runtime support integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-runtime-support-integration.py', encoding='utf-8').read(), 'check-runtime-support-integration.py', 'exec')"
check "Relationship runtime integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-relationship-runtime-integration.py', encoding='utf-8').read(), 'check-relationship-runtime-integration.py', 'exec')"
check "Runtime repair smoke syntax" \
  zsh -n "$repo_dir/scripts/run-runtime-repair-smoke.sh"
check "Relationship runtime smoke syntax" \
  zsh -n "$repo_dir/scripts/run-relationship-runtime-coordinator-smoke.sh"
check "Gesture discovery coordinator smoke syntax" \
  zsh -n "$repo_dir/scripts/run-gesture-discovery-coordinator-smoke.sh"
check "Presentation runtime coordinator smoke syntax" \
  zsh -n "$repo_dir/scripts/run-presentation-runtime-coordinator-smoke.sh"
  python3 -c "compile(open('$repo_dir/scripts/check-microgame-window-policy-integration.py', encoding='utf-8').read(), 'check-microgame-window-policy-integration.py', 'exec')"
  zsh -n "$repo_dir/scripts/run-microgame-window-policy-smoke.sh"
check "Pet feedback runtime coordinator smoke syntax" \
  zsh -n "$repo_dir/scripts/run-pet-feedback-runtime-coordinator-smoke.sh"
check "Content library runtime coordinator smoke syntax" \
  zsh -n "$repo_dir/scripts/run-content-library-runtime-coordinator-smoke.sh"
check "Preference store smoke syntax" \
  zsh -n "$repo_dir/scripts/run-preference-store-smoke.sh"
check "Voice selection runtime smoke syntax" \
  zsh -n "$repo_dir/scripts/run-voice-selection-runtime-smoke.sh"
check "Settings backup projection smoke syntax" \
  zsh -n "$repo_dir/scripts/run-settings-backup-projection-smoke.sh"
check "Playback media soak runner syntax" \
  zsh -n "$repo_dir/scripts/run-playback-media-soak.sh"
check "Playback media soak smoke syntax" \
  zsh -n "$repo_dir/scripts/run-playback-media-soak-smoke.sh"
check "Core module boundary smoke syntax" \
  zsh -n "$repo_dir/scripts/run-core-module-boundary-smoke.sh"
check "Starter media manifest generator syntax" \
  python3 -c "compile(open('$repo_dir/scripts/refresh-starter-media-manifest.py', encoding='utf-8').read(), 'refresh-starter-media-manifest.py', 'exec')"
check "Starter media auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/audit-starter-media.py', encoding='utf-8').read(), 'audit-starter-media.py', 'exec')"
check "Starter media smoke syntax" \
  zsh -n "$repo_dir/scripts/run-starter-media-contract-smoke.sh"
check "Release readiness auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/release-readiness-audit.py', encoding='utf-8').read(), 'release-readiness-audit.py', 'exec')"
check "Community pack index auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/audit-community-pack-index.py', encoding='utf-8').read(), 'audit-community-pack-index.py', 'exec')"
check "Community pack index smoke syntax" \
  zsh -n "$repo_dir/scripts/run-community-pack-index-smoke.sh"
check "Module stewardship auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/audit-module-stewardship.py', encoding='utf-8').read(), 'audit-module-stewardship.py', 'exec')"
check "Module stewardship smoke syntax" \
  zsh -n "$repo_dir/scripts/run-module-stewardship-smoke.sh"
check "Content pack smoke runner syntax" \
  zsh -n "$repo_dir/scripts/run-content-pack-smoke.sh"
check "Core policy smoke runner syntax" \
  zsh -n "$repo_dir/scripts/run-core-policy-smokes.sh"
check "Window presence audit syntax" \
  zsh -n "$repo_dir/scripts/run-window-presence-audit.sh"
check "Window visibility integration auditor syntax" \
  python3 -c "compile(open('$repo_dir/scripts/check-window-visibility-integration.py', encoding='utf-8').read(), 'check-window-visibility-integration.py', 'exec')"
check "Window lifecycle contract syntax" \
  zsh -n "$repo_dir/scripts/run-window-lifecycle-contract.sh"
check "Chinese/English localization parity" \
  python3 "$repo_dir/scripts/check-localization-parity.py"
check "Bilingual accessibility semantics" \
  python3 "$repo_dir/scripts/audit-accessibility-localization.py" --json
check "Accessibility localization rejection matrix" \
  "$repo_dir/scripts/run-accessibility-localization-smoke.sh"
check "Direct-play voice routing" \
  python3 "$repo_dir/scripts/check-manual-voice-routing.py"
check "Direct-play presentation integration" \
  python3 "$repo_dir/scripts/check-direct-play-integration.py"
check "All-game reward audit integration" \
  python3 "$repo_dir/scripts/check-game-reward-audit-integration.py"
check "All-game reward receipt rejection matrix (simulated; no GUI claim)" \
  env PYTHONDONTWRITEBYTECODE=1 python3 "$repo_dir/scripts/run-game-reward-receipt-smoke.py"
check "Bounded event inbox integration" \
  python3 "$repo_dir/scripts/check-event-spool-integration.py"
check "Bounded event inbox security and recovery" \
  "$repo_dir/scripts/run-event-spool-smoke.sh"
check "Lifestyle memory recovery integration" \
  python3 "$repo_dir/scripts/check-lifestyle-memory-integration.py"
check "Content transaction coordination integration" \
  python3 "$repo_dir/scripts/check-content-operations-integration.py"
check "Content-pack transaction store modularity" \
  python3 "$repo_dir/scripts/check-content-pack-store-modularity.py"
check "Content-pack validator modularity" \
  python3 "$repo_dir/scripts/check-content-pack-validator-modularity.py"
check "Shared-workday recovery integration" \
  python3 "$repo_dir/scripts/check-workday-integration.py"
check "Shared-workday runtime coordination" \
  "$repo_dir/scripts/run-workday-runtime-coordinator-smoke.sh"
check "Unified shared-day lifecycle integration" \
  python3 "$repo_dir/scripts/check-shared-day-integration.py"
check "Unified shared-day runtime coordination" \
  "$repo_dir/scripts/run-shared-day-runtime-coordinator-smoke.sh"
check "Local-first first-session integration" \
  python3 "$repo_dir/scripts/check-first-session-integration.py"
check "First-session runtime coordination" \
  "$repo_dir/scripts/run-first-session-runtime-coordinator-smoke.sh"
check "Isolated English first-use visual audit integration" \
  python3 "$repo_dir/scripts/check-english-first-use-audit-integration.py"
check "English first-use visual audit rejection and isolation matrix" \
  "$repo_dir/scripts/run-english-first-use-visual-audit-smoke.sh"
check "Content-free microgame integration" \
  python3 "$repo_dir/scripts/check-microgame-integration.py"
check "Ephemeral microgame runtime coordination" \
  "$repo_dir/scripts/run-microgame-runtime-coordinator-smoke.sh"
check "Unified experience runtime integration" \
  python3 "$repo_dir/scripts/check-experience-runtime-integration.py"
check "Unified experience runtime behavior" \
  "$repo_dir/scripts/run-experience-runtime-coordinator-smoke.sh"
check "Cross-Space window visibility integration" \
  python3 "$repo_dir/scripts/check-window-visibility-integration.py"
check "Dynamic projection runtime integration" \
  python3 "$repo_dir/scripts/check-presentation-runtime-integration.py"
check "Bounded runtime support integration" \
  python3 "$repo_dir/scripts/check-runtime-support-integration.py"
check "Bounded relationship runtime integration" \
  python3 "$repo_dir/scripts/check-relationship-runtime-integration.py"
check "Non-destructive runtime repair matrix" \
  "$repo_dir/scripts/run-runtime-repair-smoke.sh"
check "Relationship runtime deletion and cooldown matrix" \
  "$repo_dir/scripts/run-relationship-runtime-coordinator-smoke.sh"
check "Restart-safe gesture discovery coordination" \
  "$repo_dir/scripts/run-gesture-discovery-coordinator-smoke.sh"
check "Unified direct-play presentation coordination" \
  "$repo_dir/scripts/run-presentation-runtime-coordinator-smoke.sh"
  python3 "$repo_dir/scripts/check-microgame-window-policy-integration.py"
  "$repo_dir/scripts/run-microgame-window-policy-smoke.sh"
check "Generation-safe pet feedback integration" \
  python3 "$repo_dir/scripts/check-pet-feedback-runtime-integration.py"
check "Generation-safe pet feedback coordination" \
  "$repo_dir/scripts/run-pet-feedback-runtime-coordinator-smoke.sh"
check "Generation-safe content library integration" \
  python3 "$repo_dir/scripts/check-content-library-runtime-integration.py"
check "Generation-safe content library coordination" \
  "$repo_dir/scripts/run-content-library-runtime-coordinator-smoke.sh"
check "Typed preference migration and repair integration" \
  python3 "$repo_dir/scripts/check-preference-store-integration.py"
check "Typed preference migration and repair matrix" \
  "$repo_dir/scripts/run-preference-store-smoke.sh"
check "Bounded voice selection runtime integration" \
  python3 "$repo_dir/scripts/check-voice-selection-runtime-integration.py"
check "Bounded voice selection runtime matrix" \
  "$repo_dir/scripts/run-voice-selection-runtime-smoke.sh"
check "Portable settings backup projection integration" \
  python3 "$repo_dir/scripts/check-settings-backup-projection-integration.py"
check "Portable settings backup repair matrix" \
  "$repo_dir/scripts/run-settings-backup-projection-smoke.sh"
check "Playback media short soak and failure receipts" \
  "$repo_dir/scripts/run-playback-media-soak-smoke.sh"
check "Chinese/English public-document parity" \
  python3 "$repo_dir/scripts/check-public-doc-parity.py"
check "Chinese/English public-document drift rejection" \
  "$repo_dir/scripts/run-public-doc-parity-smoke.sh"
check "Stable error-code contract" \
  python3 "$repo_dir/scripts/check-error-code-contract.py"
check "Audited staged public Git candidate" \
  "$repo_dir/scripts/run-public-git-bootstrap-smoke.sh"
check "Local-first noncommercial product boundary" \
  python3 "$repo_dir/scripts/audit-product-boundary.py" --scope development --json
check "Product boundary rejection matrix" \
  "$repo_dir/scripts/run-product-boundary-smoke.sh"
check "Core/App module boundary" \
  python3 "$repo_dir/scripts/audit-core-module-boundaries.py" --json
check "Swift compiler parsed source boundary" \
  python3 "$repo_dir/scripts/audit-swift-compiler-boundaries.py" --json
check "Swift compiler boundary rejection matrix" \
  "$repo_dir/scripts/run-swift-compiler-boundary-smoke.sh"
check "Evaluated SwiftPM package graph" \
  python3 "$repo_dir/scripts/audit-swiftpm-package-graph.py" --json
check "SwiftPM package graph rejection matrix" \
  "$repo_dir/scripts/run-swiftpm-package-graph-smoke.sh"
check "Core/App module boundary rejection matrix" \
  "$repo_dir/scripts/run-core-module-boundary-smoke.sh"
check "Starter media manifest is current" \
  python3 "$repo_dir/scripts/refresh-starter-media-manifest.py" --check
check "Starter media source contract" \
  python3 "$repo_dir/scripts/audit-starter-media.py" --json
check "Starter media contract rejection matrix" \
  "$repo_dir/scripts/run-starter-media-contract-smoke.sh"
check "Bundle identity helper syntax" bash -n "$common_script"
check \
  "Local update identity smoke syntax" \
  bash -n \
  "$repo_dir/scripts/local-update-identity-smoke.sh"
check \
  "Local update identity smoke" \
  "$repo_dir/scripts/local-update-identity-smoke.sh"
check \
  "Path-safe local runtime identity matrix" \
  "$repo_dir/scripts/run-local-runtime-identity-smoke.sh"
check "Release build" swift build \
  --build-path "$doctor_swift_build_root" \
  -c release \
  --disable-sandbox
release_resource_bundle="$(find "$doctor_swift_build_root" \
  -path '*/release/ChengyinCompanion_CompanionApp.bundle' \
  -type d -print -quit 2>/dev/null)"
if [[ -n "$release_resource_bundle" ]]; then
  check "Current release resource bundle matches Starter contract" \
    python3 "$repo_dir/scripts/audit-starter-media.py" \
      --bundle "$release_resource_bundle" \
      --allow-swiftpm-metadata \
      --json
else
  echo "FAIL  Current release resource bundle matches Starter contract"
  failures=$((failures + 1))
fi
check "Contract checks" swift run \
  --build-path "$doctor_swift_build_root" \
  --disable-sandbox \
  CompanionContractChecks
check \
  "New Mac first-use and low-impact policy audit" \
  "$repo_dir/scripts/run-first-use-low-impact-audit.sh"
check \
  "Public release gates remain explicit" \
  "$repo_dir/scripts/run-release-readiness-smoke.sh"
check \
  "Verifiable clone/build/contribute source package" \
  "$repo_dir/scripts/run-portable-source-smoke.sh"
check \
  "Reviewed community pack index" \
  "$repo_dir/scripts/run-community-pack-index-smoke.sh"
check \
  "Module stewardship and review routing" \
  "$repo_dir/scripts/run-module-stewardship-smoke.sh"

doctor_tmp="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-doctor.XXXXXX")"
swap_bin="$doctor_tmp/atomic-app-swap"
creator_preview="$doctor_tmp/creator-preview.html"

check \
  "Creator example validation" \
  "$repo_dir/scripts/validate-content-pack.sh" \
  "$repo_dir/examples/packs/hello-workday" \
  --json
check \
  "Creator tool cache integrity" \
  "$repo_dir/scripts/run-creator-tool-cache-smoke.sh"
check \
  "Creator stable error receipts" \
  "$repo_dir/scripts/run-creator-error-receipt-smoke.sh"
check \
  "Creator contribution metadata gate" \
  "$repo_dir/scripts/run-contribution-metadata-smoke.sh"
check \
  "Atomic path-safe content-pack scaffold" \
  "$repo_dir/scripts/run-content-pack-scaffold-smoke.sh"
check \
  "Creator v1-to-v2 migration receipts" \
  "$repo_dir/scripts/run-content-pack-migration-smoke.sh"
check \
  "Content Pack v2 eight-state contract matrix" \
  "$repo_dir/scripts/run-content-pack-v2-contract-matrix.sh"
check \
  "Content-pack archive threat matrix" \
  "$repo_dir/scripts/run-content-pack-archive-smoke.sh"
check \
  "Content-pack archive integration contract" \
  python3 "$repo_dir/scripts/check-content-pack-archive-integration.py"
check \
  "Creator three-presentation crop preview" \
  "$repo_dir/scripts/run-content-pack-preview-projection-smoke.sh"
check \
  "Creator interactive projection editor" \
  "$repo_dir/scripts/run-content-pack-projection-editor-smoke.sh"
check \
  "Projection receipt transaction and rollback" \
  "$repo_dir/scripts/run-projection-receipt-apply-smoke.sh"
check \
  "Declarative experience authoring transaction and rollback" \
  "$repo_dir/scripts/run-content-pack-experience-authoring-smoke.sh"
check \
  "Projection authoring integration contract" \
  python3 "$repo_dir/scripts/check-projection-authoring-integration.py"
check \
  "Appearance and multi-display integration contract" \
  python3 "$repo_dir/scripts/check-presentation-environment-integration.py"
check \
  "Creator example quality audit" \
  "$repo_dir/scripts/audit-content-pack.sh" \
  "$repo_dir/examples/packs/hello-workday" \
  --strict \
  --json
check \
  "Creator offline locale matrix" \
  "$repo_dir/scripts/run-content-pack-locale-matrix-smoke.sh"
check \
  "Public source credential hygiene" \
  python3 "$repo_dir/scripts/audit-public-source-secrets.py" --json
check \
  "Public source credential threat matrix" \
  "$repo_dir/scripts/run-public-source-secret-audit-smoke.sh"
check \
  "Creator preview generation" \
  "$repo_dir/scripts/preview-content-pack.sh" \
  "$repo_dir/examples/packs/hello-workday" \
  --output "$creator_preview" \
  --no-open
check "Creator preview artifact" test -s "$creator_preview"

if xcrun swiftc "$repo_dir/scripts/atomic-app-swap.swift" -o "$swap_bin"; then
  echo "PASS  Atomic app swap compile"
  swap_candidate="$doctor_tmp/swap-candidate.app"
  swap_installed="$doctor_tmp/swap-installed.app"
  mkdir "$swap_candidate" "$swap_installed"
  touch "$swap_candidate/candidate-marker"
  touch "$swap_installed/installed-marker"
  if "$swap_bin" "$swap_candidate" "$swap_installed" \
    && test -f "$swap_candidate/installed-marker" \
    && test -f "$swap_installed/candidate-marker"; then
    echo "PASS  Atomic app swap smoke"
  else
    echo "FAIL  Atomic app swap smoke"
    failures=$((failures + 1))
  fi
  rm -f \
    "$swap_candidate/installed-marker" \
    "$swap_candidate/candidate-marker" \
    "$swap_installed/installed-marker" \
    "$swap_installed/candidate-marker"
  rmdir "$swap_candidate" "$swap_installed" 2>/dev/null || true
else
  echo "FAIL  Atomic app swap compile"
  failures=$((failures + 1))
fi

check "Content pack security smoke" "$repo_dir/scripts/run-content-pack-smoke.sh"

director_bin="$doctor_tmp/content-pack-director-smoke"
if xcrun swiftc \
  "$repo_dir/Sources/CompanionContracts/CompanionSettings.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionPresentationProjection.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionLocaleResolutionPolicy.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackManifest.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackArchivePolicy.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackArchiveImporter.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionFailureReceipt.swift" \
  "$repo_dir/Sources/CompanionApp/SemanticVersion.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackTriggerContract.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackManifestFieldValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackContributionValidationSupport.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackRightsValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackAccessibilityValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackFallbackValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackContributionValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackPackageContentsValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackAssetFileValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackAssetProjectionValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackAssetValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPack.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackVideoDecodeFallback.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackNonVideoMediaProbe.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackVideoMediaProbe.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackMediaProbe.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackMediaCheckpointDecoder.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackMediaQualityProbe.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackRecoveryCatalog.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackStoreModels.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackStoreDurability.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackStoreLayout.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackActiveRecordRepository.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackStoreLockCoordinator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackStoreRepository.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackInstallPreflight.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackInstallTransactions.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackRecoveryTransactions.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackPlaybackHealthTransactions.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackStoreSnapshotProjection.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackStoreMaintenanceTransactions.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackStore.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackRuntimeAccessibility.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackPlaybackModels.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackRuntimeCatalog.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackRuntimeSelection.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionContentSequenceRuntimeCoordinator.swift" \
  "$repo_dir/scripts/content-pack-director-smoke.swift" \
  -o "$director_bin"; then
  echo "PASS  Content director smoke compile"
  check "Content director selection smoke" "$director_bin"
else
  echo "FAIL  Content director smoke compile"
  failures=$((failures + 1))
fi

diagnostics_bin="$doctor_tmp/diagnostics-smoke"
if xcrun swiftc \
  -D COMPANION_STANDALONE_SMOKE \
  "$repo_dir/Sources/CompanionContracts/CompanionPlaybackHealth.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionDiagnostics.swift" \
  "$repo_dir/scripts/diagnostics-smoke.swift" \
  -o "$diagnostics_bin"; then
  echo "PASS  Privacy-minimal diagnostics smoke compile"
  check "Privacy-minimal diagnostics smoke" "$diagnostics_bin"
else
  echo "FAIL  Privacy-minimal diagnostics smoke compile"
  failures=$((failures + 1))
fi

check "Core policy smokes" "$repo_dir/scripts/run-core-policy-smokes.sh"
check "Privacy-safe Codex App Server adapter" \
  "$repo_dir/scripts/run-codex-app-server-adapter-smoke.sh"
check \
  "Window lifecycle failure and rollback contract" \
  "$repo_dir/scripts/run-window-lifecycle-contract.sh"

rm -f \
  "$director_bin" \
  "$swap_bin"
rmdir "$doctor_tmp" 2>/dev/null || true

current_source_fingerprint="$(chengyin_source_fingerprint "$repo_dir")"
current_source_short="$(chengyin_short_fingerprint "$current_source_fingerprint")"
echo "INFO  Current source identity: $current_source_short"

inspect_app_currency() {
  local label="$1"
  local app_path="$2"
  local app_source_fingerprint
  local app_identity
  local english_strings
  local chinese_strings

  if [ ! -d "$app_path" ]; then
    echo "INFO  $label app not found: $app_path"
    return 0
  fi

  app_source_fingerprint="$(
    chengyin_plist_value "$app_path" ChengyinSourceFingerprint || true
  )"
  app_identity="$(chengyin_bundle_label "$app_path")"
  echo "INFO  $label app: $app_identity"

  if [ ! -x "$app_path/Contents/SharedSupport/CompanionEventEmitter" ]; then
    echo "FAIL  $label app is missing the completion event helper"
    failures=$((failures + 1))
  else
    echo "PASS  $label app contains the completion event helper"
  fi

  english_strings="$(find "$app_path/Contents/Resources" -maxdepth 2 -type f -ipath '*/en.lproj/Localizable.strings' -print -quit)"
  chinese_strings="$(find "$app_path/Contents/Resources" -maxdepth 2 -type f -ipath '*/zh-hans.lproj/Localizable.strings' -print -quit)"
  if [ -s "$english_strings" ] && [ -s "$chinese_strings" ]; then
    echo "PASS  $label app contains Chinese and English localization resources"
  else
    echo "FAIL  $label app is missing packaged localization resources"
    failures=$((failures + 1))
  fi

  if [ -z "$app_source_fingerprint" ]; then
    echo "FAIL  $label app has no reproducible build identity"
    failures=$((failures + 1))
  elif [ "$app_source_fingerprint" != "$current_source_fingerprint" ]; then
    echo "FAIL  $label app is stale relative to source $current_source_short"
    failures=$((failures + 1))
  else
    echo "PASS  $label app matches current source"
  fi
}

inspect_app_currency "Dist" "$dist_app"
inspect_app_currency "Installed" "$installed_app"

runtime_identity_receipt="$(
  PYTHONDONTWRITEBYTECODE=1 python3 \
    "$repo_dir/scripts/audit-local-runtime-identity.py" \
    --json
)"
runtime_identity_exit=$?
if ! RUNTIME_IDENTITY_RECEIPT="$runtime_identity_receipt" python3 - <<'PY'
import json
import os

receipt = json.loads(os.environ["RUNTIME_IDENTITY_RECEIPT"])
for label in ("source", "dist", "installed", "running"):
    state = receipt[label]
    print(f"INFO  Runtime identity {label}: " + json.dumps(state, sort_keys=True))
prefix = receipt["status"]
if receipt["code"]:
    prefix += f" [{receipt['code']}]"
print(f"{prefix}  {receipt['message']}")
if receipt["recoveryAction"]:
    print(f"ACTION  {receipt['recoveryAction']}")
PY
then
  echo "FAIL  Local runtime identity receipt is unreadable"
  failures=$((failures + 1))
elif [ "$runtime_identity_exit" -eq 0 ]; then
  check \
    "Installed companion has an on-screen window" \
    "$repo_dir/scripts/run-window-presence-audit.sh"
else
  failures=$((failures + 1))
fi

media_dir="$repo_dir/Sources/CompanionApp/Resources"
media_count="$(find "$media_dir" -type f -name '*.mov' | wc -l | tr -d ' ')"
echo "INFO  MOV assets: $media_count"

if command -v ffprobe >/dev/null 2>&1; then
  media_failures=0
  while IFS= read -r -d '' media_path; do
    if ! ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$media_path" >/dev/null; then
      echo "FAIL  Media decode: $media_path"
      media_failures=$((media_failures + 1))
    fi
  done < <(find "$media_dir" -type f -name '*.mov' -print0)

  if [ "$media_failures" -eq 0 ]; then
    echo "PASS  All MOV assets decode"
  else
    failures=$((failures + media_failures))
  fi
else
  echo "INFO  ffprobe unavailable; media decode check skipped"
fi

voice_manifest="$media_dir/voice-lines.json"
voice_audio_dir="$media_dir/Audio"
if command -v jq >/dev/null 2>&1; then
  voice_count="$(jq 'length' "$voice_manifest")"
  echo "INFO  Voice lines: $voice_count"
  if [ "$(jq '[.[].id] | length == (unique | length)' "$voice_manifest")" != "true" ]; then
    echo "FAIL  Voice line IDs are not unique"
    failures=$((failures + 1))
  fi

  voice_failures=0
  while IFS= read -r audio_file; do
    audio_path="$voice_audio_dir/$audio_file"
    if [ ! -s "$audio_path" ]; then
      echo "FAIL  Voice clip missing: $audio_file"
      voice_failures=$((voice_failures + 1))
    elif command -v ffprobe >/dev/null 2>&1 \
      && ! ffprobe -v error -show_entries format=duration \
        -of default=nw=1:nk=1 "$audio_path" >/dev/null; then
      echo "FAIL  Voice clip decode: $audio_file"
      voice_failures=$((voice_failures + 1))
    fi
  done < <(jq -r '.[].audioFile' "$voice_manifest")

  if [ "$voice_failures" -eq 0 ]; then
    echo "PASS  All declared voice clips exist and decode"
  else
    failures=$((failures + voice_failures))
  fi
else
  echo "INFO  jq unavailable; voice manifest integrity check skipped"
fi

microphone_declaration_found=0
for permission_plist in \
  "$repo_dir/Info.plist" \
  "$dist_app/Contents/Info.plist" \
  "$installed_app/Contents/Info.plist"; do
  if [ -f "$permission_plist" ] \
    && /usr/libexec/PlistBuddy \
      -c 'Print :NSMicrophoneUsageDescription' \
      "$permission_plist" >/dev/null 2>&1; then
    echo "FAIL  Microphone usage declaration found: $permission_plist"
    microphone_declaration_found=1
  fi
done
if [ "$microphone_declaration_found" -eq 0 ]; then
  echo "PASS  No microphone usage declaration"
else
  failures=$((failures + microphone_declaration_found))
fi

if [ "$failures" -eq 0 ]; then
  echo "Doctor result: PASS"
  exit 0
fi

echo "Doctor result: FAIL ($failures checks)"
exit 1
