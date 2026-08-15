#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
DIST_APP="$PROJECT_DIR/dist/Chengyin Companion.app"
IDENTITY_AUDITOR="$PROJECT_DIR/scripts/audit-local-runtime-identity.py"
DRIVER_SOURCE="$PROJECT_DIR/scripts/english-first-use-visual-audit.swift"
SOURCE_ONLY=0
OUTPUT_ROOT=""

source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"

usage() {
  echo "Usage: ./scripts/run-english-first-use-visual-audit.sh [--source-only] [--output DIR]"
  echo
  echo "  --source-only  Verify the reproducible audit contract without launching a GUI."
  echo "  --output DIR   Store current-run screenshots and receipt in DIR."
}

fail_receipt() {
  local code="$1"
  local message="$2"
  local recovery="$3"
  CODE="$code" MESSAGE="$message" RECOVERY="$recovery" python3 - <<'PY'
import json, os
print(json.dumps({
  "schemaVersion": 1,
  "contract": "chengyin.english-first-use-visual-audit/v1",
  "status": "FAIL",
  "code": os.environ["CODE"],
  "message": os.environ["MESSAGE"],
  "recoveryAction": os.environ["RECOVERY"],
  "environment": "ISOLATED_LOCAL_LAB",
  "locale": "en-US",
  "steps": [],
  "runtimeAccessibility": "NOT_EVALUATED",
  "humanVoiceOverAudit": "PENDING_HUMAN_REVIEW",
  "physicalCleanMacAudit": "PENDING_EXTERNAL_DEVICE",
  "proofStrength": "failed-before-complete-current-run-evidence",
  "releaseState": "NOT_PUBLIC_RELEASE_READY"
}, ensure_ascii=False, sort_keys=True))
PY
  exit 1
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --source-only)
      SOURCE_ONLY=1
      ;;
    --output)
      shift
      [[ "$#" -gt 0 ]] || {
        usage >&2
        exit 2
      }
      OUTPUT_ROOT="$1"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

for required in \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionRuntimeEnvironment.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionFirstSessionCoach.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/Resources/en.lproj/Localizable.strings" \
  "$DRIVER_SOURCE" \
  "$PROJECT_DIR/Schemas/english-first-use-visual-audit-v1.schema.json"; do
  [[ -f "$required" && ! -L "$required" ]] || fail_receipt \
    "FIRST_USE_VISUAL_AUDIT_RUNTIME_UNAVAILABLE" \
    "The isolated English first-use audit contract is incomplete." \
    "Restore the missing source artifact from the current package and retry."
done

if [[ "$SOURCE_ONLY" -eq 1 ]]; then
  python3 - <<'PY'
import json
print(json.dumps({
  "schemaVersion": 1,
  "contract": "chengyin.english-first-use-visual-audit/v1",
  "status": "PASS_WITH_PENDING",
  "code": None,
  "message": "The isolated English first-use audit contract is source-verifiable; GUI capture was intentionally not executed.",
  "recoveryAction": "Run the visual audit on a Mac with existing capture access, then complete a physical clean-Mac human VoiceOver review.",
  "environment": "SOURCE_ONLY",
  "locale": "en-US",
  "steps": [],
  "runtimeAccessibility": "PENDING_GUI_RUN",
  "humanVoiceOverAudit": "PENDING_HUMAN_REVIEW",
  "physicalCleanMacAudit": "PENDING_EXTERNAL_DEVICE",
  "proofStrength": "source-contract-only-not-gui-human_review_required-physical_clean_mac_required",
  "releaseState": "NOT_PUBLIC_RELEASE_READY"
}, ensure_ascii=False, sort_keys=True))
PY
  exit 0
fi

[[ -d "$DIST_APP" && ! -L "$DIST_APP" ]] || fail_receipt \
  "FIRST_USE_VISUAL_AUDIT_RUNTIME_UNAVAILABLE" \
  "The current project preview is unavailable." \
  "Build the current preview and rerun the isolated English first-use audit."

identity_receipt="$(PYTHONDONTWRITEBYTECODE=1 python3 "$IDENTITY_AUDITOR" --json)" || true
IDENTITY_RECEIPT="$identity_receipt" python3 - <<'PY' || fail_receipt \
  "FIRST_USE_VISUAL_AUDIT_RUNTIME_UNAVAILABLE" \
  "The project preview does not match the current source." \
  "Build the current preview and rerun the isolated English first-use audit."
import json, os
value = json.loads(os.environ["IDENTITY_RECEIPT"])
assert value["dist"]["current"] is True, value
PY

AUDIT_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-english-first-use.XXXXXX")"
LAB_APP="$AUDIT_TEMP/Chengyin First-Use Audit.app"
LAB_RUNTIME="$AUDIT_TEMP/runtime"
DRIVER_BIN="$AUDIT_TEMP/english-first-use-visual-audit"
APP_PID=""

cleanup() {
  if [[ -n "${APP_PID:-}" ]] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
  if [[ -n "${AUDIT_TEMP:-}" \
    && "$AUDIT_TEMP" == "${TMPDIR:-/tmp}"/chengyin-english-first-use.* \
    && -d "$AUDIT_TEMP" ]]; then
    /bin/rm -rf "$AUDIT_TEMP"
  fi
}
trap cleanup EXIT INT TERM

if [[ -z "$OUTPUT_ROOT" ]]; then
  stamp="$(date -u '+%Y%m%dT%H%M%SZ')"
  OUTPUT_ROOT="$PROJECT_DIR/dist/audits/english-first-use/$stamp"
fi
if [[ -L "$OUTPUT_ROOT" ]]; then
  fail_receipt \
    "FIRST_USE_VISUAL_AUDIT_UNSAFE_OUTPUT" \
    "The requested audit output is a symbolic link." \
    "Choose a new non-symbolic-link output directory and retry."
fi
mkdir -p "$OUTPUT_ROOT"
chmod 700 "$OUTPUT_ROOT"

ditto "$DIST_APP" "$LAB_APP"
audit_suffix="$(date -u '+%Y%m%d%H%M%S').$$"
audit_bundle_id="local.zidong.chengyin-companion.first-use-audit.$audit_suffix"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $audit_bundle_id" \
  "$LAB_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Chengyin First-Use Audit" \
  "$LAB_APP/Contents/Info.plist"
if ! /usr/libexec/PlistBuddy \
  -c "Set :CFBundleDisplayName Chengyin First-Use Audit" \
  "$LAB_APP/Contents/Info.plist" 2>/dev/null; then
  /usr/libexec/PlistBuddy \
    -c "Add :CFBundleDisplayName string Chengyin First-Use Audit" \
    "$LAB_APP/Contents/Info.plist"
fi
/usr/libexec/PlistBuddy -c "Add :ChengyinFirstUseAuditMode bool true" \
  "$LAB_APP/Contents/Info.plist"
codesign --force --deep --sign - "$LAB_APP" >/dev/null
codesign --verify --deep --strict "$LAB_APP"

mkdir -p "$LAB_RUNTIME"
chmod 700 "$LAB_RUNTIME"
xcrun swiftc "$DRIVER_SOURCE" -o "$DRIVER_BIN"

CHENGYIN_FIRST_USE_AUDIT_ROOT="$LAB_RUNTIME" \
  "$LAB_APP/Contents/MacOS/ChengyinCompanion" \
  -AppleLanguages '(en)' \
  -AppleLocale en_US \
  >"$AUDIT_TEMP/app.log" 2>&1 &
APP_PID=$!

receipt="$("$DRIVER_BIN" --pid "$APP_PID" --output "$OUTPUT_ROOT")" || {
  printf '%s\n' "$receipt"
  exit 1
}
printf '%s\n' "$receipt" >"$OUTPUT_ROOT/receipt.json"
chmod 600 "$OUTPUT_ROOT/receipt.json"

runtime_receipt="$LAB_RUNTIME/runtime-environment.json"
[[ -f "$runtime_receipt" && ! -L "$runtime_receipt" ]] || fail_receipt \
  "FIRST_USE_VISUAL_AUDIT_RUNTIME_UNAVAILABLE" \
  "The audit bundle did not prove isolated writable roots." \
  "Repair the first-use audit runtime marker and rerun the walkthrough."

RUNTIME_RECEIPT="$runtime_receipt" AUDIT_BUNDLE_ID="$audit_bundle_id" python3 - <<'PY' || fail_receipt \
  "FIRST_USE_VISUAL_AUDIT_RUNTIME_UNAVAILABLE" \
  "The first-use audit runtime isolation receipt is invalid." \
  "Repair the isolated data-root contract and rerun the walkthrough."
import json, os
value = json.load(open(os.environ["RUNTIME_RECEIPT"], encoding="utf-8"))
assert value["status"] == "PASS", value
assert value["bundleIdentifier"] == os.environ["AUDIT_BUNDLE_ID"], value
assert value["sharedUserContentAccess"] is False, value
assert "/Users/" not in json.dumps(value) and "/Volumes/" not in json.dumps(value), value
PY

RECEIPT="$OUTPUT_ROOT/receipt.json" python3 - <<'PY' || fail_receipt \
  "FIRST_USE_VISUAL_AUDIT_INTERACTION_FAILED" \
  "The isolated English first-use receipt is incomplete." \
  "Inspect the current-run screenshots, repair the failed step, and retry."
import json, os
value = json.load(open(os.environ["RECEIPT"], encoding="utf-8"))
assert value["status"] == "PASS_WITH_PENDING", value
assert len(value["steps"]) == 5, value
assert all(step["status"] == "PASS" for step in value["steps"]), value
assert all(step["window"]["fullyVisible"] for step in value["steps"]), value
assert value["humanVoiceOverAudit"] == "PENDING_HUMAN_REVIEW", value
assert value["physicalCleanMacAudit"] == "PENDING_EXTERNAL_DEVICE", value
encoded = json.dumps(value)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, value
PY

printf '%s\n' "$receipt"
echo "ARTIFACT  dist/audits/english-first-use/$(basename "$OUTPUT_ROOT")"
