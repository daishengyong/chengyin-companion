#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
AUDITOR="$PROJECT_DIR/scripts/audit-accessibility-localization.py"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-a11y-localization.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT
passed=0
expected=8

make_fixture() {
  local destination="$1"
  mkdir -p \
    "$destination/Sources/CompanionContracts" \
    "$destination/Sources/CompanionApp/Resources/en.lproj" \
    "$destination/Sources/CompanionApp/Resources/zh-Hans.lproj"
  cp "$PROJECT_DIR/Sources/CompanionContracts/CompanionLocaleResolutionPolicy.swift" \
    "$destination/Sources/CompanionContracts/CompanionLocaleResolutionPolicy.swift"
  cp "$PROJECT_DIR/Sources/CompanionApp/ContentView.swift" \
    "$destination/Sources/CompanionApp/ContentView.swift"
  cp "$PROJECT_DIR/Sources/CompanionApp/CompanionStatusOverlays.swift" \
    "$destination/Sources/CompanionApp/CompanionStatusOverlays.swift"
  cp "$PROJECT_DIR/Sources/CompanionApp/CompanionAccessibility.swift" \
    "$destination/Sources/CompanionApp/CompanionAccessibility.swift"
  cp "$PROJECT_DIR/Sources/CompanionApp/CompanionPlayControls.swift" \
    "$destination/Sources/CompanionApp/CompanionPlayControls.swift"
  cp "$PROJECT_DIR/Sources/CompanionApp/CompanionFirstSessionCoach.swift" \
    "$destination/Sources/CompanionApp/CompanionFirstSessionCoach.swift"
  cp "$PROJECT_DIR/Sources/CompanionApp/CompanionSupportDiagnosticsSection.swift" \
    "$destination/Sources/CompanionApp/CompanionSupportDiagnosticsSection.swift"
  cp "$PROJECT_DIR/Sources/CompanionApp/ContentPackRuntimeAccessibility.swift" \
    "$destination/Sources/CompanionApp/ContentPackRuntimeAccessibility.swift"
  cp "$PROJECT_DIR/Sources/CompanionApp/ContentPackPlaybackModels.swift" \
    "$destination/Sources/CompanionApp/ContentPackPlaybackModels.swift"
  cp "$PROJECT_DIR/Sources/CompanionApp/ContentPackRuntimeCatalog.swift" \
    "$destination/Sources/CompanionApp/ContentPackRuntimeCatalog.swift"
  cp "$PROJECT_DIR/Sources/CompanionApp/CompanionMediaAccessibilityPresentation.swift" \
    "$destination/Sources/CompanionApp/CompanionMediaAccessibilityPresentation.swift"
  cp "$PROJECT_DIR/Sources/CompanionApp/Resources/en.lproj/Localizable.strings" \
    "$destination/Sources/CompanionApp/Resources/en.lproj/Localizable.strings"
  cp "$PROJECT_DIR/Sources/CompanionApp/Resources/zh-Hans.lproj/Localizable.strings" \
    "$destination/Sources/CompanionApp/Resources/zh-Hans.lproj/Localizable.strings"
}

assert_private_receipt() {
  local output="$1"
  if grep -Eq '/Users/|/Volumes/|/private/var/|/tmp/|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+' "$output"; then
    echo "FAIL  receipt exposed a local path or identity" >&2
    exit 1
  fi
}

expect_failure() {
  local code="$1"
  local fixture="$2"
  local output="$TEMP_ROOT/receipt-$passed.json"
  if PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" --root "$fixture" --json >"$output" 2>&1; then
    echo "FAIL  expected $code" >&2
    exit 1
  fi
  assert_private_receipt "$output"
  if [[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["code"])' "$output")" != "$code" ]]; then
    echo "FAIL  unexpected error code" >&2
    exit 1
  fi
  passed=$((passed + 1))
  echo "PASS  $code"
}

baseline="$TEMP_ROOT/baseline"
make_fixture "$baseline"
baseline_receipt="$TEMP_ROOT/baseline.json"
PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" --root "$baseline" --json >"$baseline_receipt"
assert_private_receipt "$baseline_receipt"
if [[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["status"])' "$baseline_receipt")" != "PASS" ]]; then
  echo "FAIL  baseline accessibility contract" >&2
  exit 1
fi
passed=$((passed + 1))
echo "PASS  bilingual baseline"

overlay_missing="$TEMP_ROOT/overlay-missing"
make_fixture "$overlay_missing"
rm "$overlay_missing/Sources/CompanionApp/CompanionStatusOverlays.swift"
expect_failure ACCESSIBILITY_CONTRACT_MISSING_KEY "$overlay_missing"

missing="$TEMP_ROOT/missing"
make_fixture "$missing"
python3 - "$missing/Sources/CompanionApp/Resources/en.lproj/Localizable.strings" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text("\n".join(line for line in text.splitlines() if not line.startswith('"accessibility.pet.label"')) + "\n", encoding="utf-8")
PY
expect_failure ACCESSIBILITY_CONTRACT_MISSING_KEY "$missing"

english="$TEMP_ROOT/english"
make_fixture "$english"
python3 - "$english/Sources/CompanionApp/Resources/en.lproj/Localizable.strings" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace('"accessibility.pet.label" = "Interactive Chengyin companion";', '"accessibility.pet.label" = "澄音互动角色";')
path.write_text(text, encoding="utf-8")
PY
expect_failure ACCESSIBILITY_CONTRACT_ENGLISH_COPY_INVALID "$english"

literal="$TEMP_ROOT/literal"
make_fixture "$literal"
python3 - "$literal/Sources/CompanionApp/ContentView.swift" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8") + '\nprivate let injectedA11yFixture = Text("x").accessibilityLabel("raw")\n', encoding="utf-8")
PY
expect_failure ACCESSIBILITY_CONTRACT_HARDCODED_SEMANTIC "$literal"

identifier="$TEMP_ROOT/identifier"
make_fixture "$identifier"
python3 - "$identifier/Sources/CompanionApp/ContentView.swift" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8").replace('"chengyin.pet-interaction"', '"chengyin.pet-interaction-removed"')
path.write_text(text, encoding="utf-8")
PY
expect_failure ACCESSIBILITY_CONTRACT_IDENTIFIER_MISSING "$identifier"

runtime="$TEMP_ROOT/runtime"
make_fixture "$runtime"
python3 - "$runtime/Sources/CompanionApp/CompanionMediaAccessibilityPresentation.swift" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8").replace(
    "activeContentSequence?.resolvedAccessibility(",
    "activeContentSequence?.disconnectedAccessibility(",
)
path.write_text(text, encoding="utf-8")
PY
expect_failure ACCESSIBILITY_CONTRACT_RUNTIME_METADATA_DISCONNECTED "$runtime"

invalid_receipt="$TEMP_ROOT/invalid.json"
if PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" --bogus --json >"$invalid_receipt" 2>&1; then
  echo "FAIL  expected invalid argument rejection" >&2
  exit 1
fi
assert_private_receipt "$invalid_receipt"
if [[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["code"])' "$invalid_receipt")" != "ACCESSIBILITY_CONTRACT_INVALID_ARGUMENT" ]]; then
  echo "FAIL  invalid argument error code" >&2
  exit 1
fi
passed=$((passed + 1))
echo "PASS  ACCESSIBILITY_CONTRACT_INVALID_ARGUMENT"

echo "Accessibility localization smoke: PASS ($passed/$expected)"
