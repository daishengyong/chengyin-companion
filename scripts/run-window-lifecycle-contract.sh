#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"

CONTRACT_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-window-contract.XXXXXX")"
CONTRACT_BIN="$CONTRACT_ROOT/chengyin-window-contract"
cleanup() {
  rm -f "$CONTRACT_BIN"
  rmdir "$CONTRACT_ROOT" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

xcrun swiftc \
  "$PROJECT_DIR/scripts/window-presence-audit.swift" \
  -o "$CONTRACT_BIN"

set +e
receipt="$(CHENGYIN_WINDOW_AUDIT_TEST_NO_PROCESS=1 "$CONTRACT_BIN")"
audit_exit=$?
set -e
if [[ "$audit_exit" -ne 1 ]]; then
  echo "FAIL  no-process window audit returned $audit_exit instead of 1" >&2
  exit 1
fi

WINDOW_RECEIPT="$receipt" python3 -c '
import json, os
receipt = json.loads(os.environ["WINDOW_RECEIPT"])
assert receipt["status"] == "FAIL", receipt
assert receipt["code"] == "UI_PROCESS_NOT_DISCOVERABLE", receipt
assert receipt["processCount"] == 0, receipt
assert receipt["windowCount"] == 0, receipt
assert receipt["recoveryAction"], receipt
encoded = json.dumps(receipt)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, receipt
'

app_source="$PROJECT_DIR/Sources/CompanionApp/CompanionApp.swift"
visibility_source="$PROJECT_DIR/Sources/CompanionApp/CompanionWindowVisibilityKeeper.swift"
installer="$PROJECT_DIR/scripts/install-local-app.sh"
grep -Fq 'private final class CompanionPanel: NSPanel' "$app_source"
grep -Fq 'styleMask: [.borderless, .nonactivatingPanel]' "$app_source"
grep -Fq 'panel.isFloatingPanel = true' "$app_source"
grep -Fq 'override var canBecomeKey: Bool { true }' "$app_source"
grep -Fq 'panel.becomesKeyOnlyIfNeeded = false' "$app_source"
grep -Fq 'window.isRestorable = false' "$app_source"
grep -Fq 'applicationShouldHandleReopen' "$app_source"
grep -Fq 'applicationShouldTerminateAfterLastWindowClosed' "$app_source"
grep -Fq 'transient popover must not terminate' "$app_source"
grep -Fq 'CompanionWindowVisibilityKeeper(application: NSApp)' "$app_source"
grep -Fq 'activeSpaceDidChangeNotification' "$visibility_source"
grep -Fq 'DispatchSource.makeTimerSource(queue: .main)' "$visibility_source"
grep -Fq 'repeating: 5' "$visibility_source"
grep -Fq '.canJoinAllApplications' "$visibility_source"
grep -Fq '.fullScreenAuxiliary' "$visibility_source"
grep -Fq '.canJoinAllSpaces' "$visibility_source"
grep -Fq '.stationary' "$visibility_source"
grep -Fq 'window.canHide = false' "$visibility_source"
grep -Fq 'guard !window.isMiniaturized' "$visibility_source"
grep -Fq 'window.orderFrontRegardless()' "$visibility_source"
grep -Fq 'WINDOW_AUDIT_BIN' "$installer"
grep -Fq 'previous app was restored' "$installer"

echo "Window lifecycle contract: PASS"
