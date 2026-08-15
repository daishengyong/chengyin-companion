#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
AUDITOR="$PROJECT_DIR/scripts/audit-swift-compiler-boundaries.py"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-compiler-boundary-smoke.XXXXXX")"
trap 'rm -rf "$SMOKE_ROOT"' EXIT INT TERM
passed=0
expected=9

make_fixture() {
  local name="$1"
  local destination="$SMOKE_ROOT/$name"
  python3 - "$destination" <<'PY'
import pathlib, sys

root = pathlib.Path(sys.argv[1])
files = {
    "Sources/CompanionContracts/Contracts.swift": """import Foundation

public struct CompanionChemistryInteractionDirector {}
public struct CompanionDisplaySelectionPolicy {}
public struct CompanionExperienceDirector {}
public struct CompanionFirstSessionJourney {}
public struct CompanionLifestyleMemoryStore {}
public struct CompanionLifestyleScheduler {}
public enum CompanionLocaleResolutionPolicy {}
public struct CompanionMicrogameCompletionPolicy {}
public struct CompanionMicrogameSession {}
public struct CompanionMicrogameWindowPlacement {}
public enum CompanionMicrogameWindowPolicy {}
public enum CompanionPetDragPolicy {}
public struct CompanionPlaybackHealthAccumulator {}
public enum CompanionPlayPaletteLayout {}
public struct CompanionPlayPaletteLayoutPlan {}
public struct CompanionPresentationLifecycle {}
public struct CompanionPresentationProjection {}
public struct CompanionPresentationSession {}
public struct CompanionProjectionAuthoringReceipt {}
public struct CompanionRuntimeReadiness {}
public struct CompanionTaskCompletionPolicy {}
public struct CompanionUserPresentationPolicy {}
public struct CompanionWindowPolicy {}
public struct CompanionWorkdayExperiencePolicy {}
public enum CompanionWorkdaySignalSourcePolicy {}
public enum CompanionWorkdaySignalTrustPolicy {}
public struct CompanionWorkdayStateStore {}
""",
    "Sources/CompanionApp/App.swift": """import Foundation
import CompanionContracts

struct FixtureApp {}
""",
    "Tests/CompanionContractsTests/Checks.swift": """import Foundation
import CompanionContracts

struct FixtureChecks {}
""",
    "Tools/CompanionEventEmitter/main.swift": """import Foundation
import CompanionContracts

struct FixtureEmitter {}
""",
}
for relative, content in files.items():
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
PY
  print -r -- "$destination"
}

assert_private_receipt() {
  local receipt_path="$1"
  if grep -Eq '/Users/|/Volumes/|/private/var/|/private/tmp/|/tmp/|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+' "$receipt_path"; then
    print -u2 "FAIL  compiler boundary receipt exposed a local path or identity"
    exit 1
  fi
}

expect_failure() {
  local expected_code="$1"
  local fixture="$2"
  shift 2
  local receipt_path="$SMOKE_ROOT/receipt-$passed.json"
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" \
    --root "$fixture" --json "$@" >"$receipt_path" 2>&1
  local exit_status=$?
  set -e
  [[ "$exit_status" -eq 1 ]] || {
    print -u2 "FAIL  expected $expected_code exit 1"
    exit 1
  }
  assert_private_receipt "$receipt_path"
  local observed_code
  observed_code="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["code"])' "$receipt_path")"
  [[ "$observed_code" == "$expected_code" ]] || {
    print -u2 "FAIL  expected $expected_code, received $observed_code"
    exit 1
  }
  passed=$((passed + 1))
  print "PASS  $expected_code"
}

valid="$(make_fixture valid)"
valid_receipt="$SMOKE_ROOT/valid.json"
PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" --root "$valid" --json >"$valid_receipt"
assert_private_receipt "$valid_receipt"
python3 - "$valid_receipt" <<'PY'
import json, sys
value = json.load(open(sys.argv[1], encoding="utf-8"))
assert value["status"] == "PASS", value
assert value["targetCount"] == 4, value
assert value["swiftFileCount"] == 4, value
assert value["requiredPublicCoreDeclarationCount"] == 27, value
assert value["sourceExecuted"] is False, value
assert value["networkRequired"] is False, value
assert value["proofStrength"].endswith("not-typechecked-dependency-or-sandbox-proof"), value
PY
passed=$((passed + 1))
print "PASS  compiler-parsed valid fixture"

forbidden="$(make_fixture forbidden-import)"
python3 - "$forbidden/Sources/CompanionContracts/Contracts.swift" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
path.write_text("import AppKit\n" + path.read_text(encoding="utf-8"), encoding="utf-8")
PY
expect_failure SWIFT_COMPILER_BOUNDARY_IMPORT_VIOLATION "$forbidden"

missing_edge="$(make_fixture missing-edge)"
python3 - "$missing_edge/Sources/CompanionApp/App.swift" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8").replace("import CompanionContracts\n", "", 1), encoding="utf-8")
PY
expect_failure SWIFT_COMPILER_BOUNDARY_DEPENDENCY_EDGE_MISSING "$missing_edge"

missing_public="$(make_fixture missing-public)"
python3 - "$missing_public/Sources/CompanionContracts/Contracts.swift" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8").replace("public struct CompanionWindowPolicy", "struct CompanionWindowPolicy", 1), encoding="utf-8")
PY
expect_failure SWIFT_COMPILER_BOUNDARY_PUBLIC_SURFACE_MISSING "$missing_public"

malformed="$(make_fixture malformed)"
python3 - "$malformed/Sources/CompanionApp/App.swift" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8") + "\nstruct Broken {\n", encoding="utf-8")
PY
expect_failure SWIFT_COMPILER_BOUNDARY_PARSE_FAILED "$malformed"

linked="$(make_fixture linked)"
ln -s Contracts.swift "$linked/Sources/CompanionContracts/Linked.swift"
expect_failure SWIFT_COMPILER_BOUNDARY_SOURCE_UNSAFE "$linked"

oversized="$(make_fixture oversized)"
python3 - "$oversized/Sources/CompanionContracts/Oversized.swift" <<'PY'
import pathlib, sys
pathlib.Path(sys.argv[1]).write_text("// bounded fixture\n" + (" " * (513 * 1024)), encoding="utf-8")
PY
expect_failure SWIFT_COMPILER_BOUNDARY_SOURCE_LIMIT_EXCEEDED "$oversized"

missing_root="$(make_fixture missing-root)"
mv "$missing_root/Tools/CompanionEventEmitter" "$missing_root/Tools/EmitterMoved"
expect_failure SWIFT_COMPILER_BOUNDARY_SOURCE_ROOT_MISSING "$missing_root"

invalid_receipt="$SMOKE_ROOT/invalid-argument.json"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" --unsupported --json >"$invalid_receipt" 2>&1
invalid_status=$?
set -e
[[ "$invalid_status" -eq 1 ]] || {
  print -u2 "FAIL  invalid argument was accepted"
  exit 1
}
assert_private_receipt "$invalid_receipt"
[[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["code"])' "$invalid_receipt")" == "SWIFT_COMPILER_BOUNDARY_INVALID_ARGUMENT" ]] \
  || { print -u2 "FAIL  invalid argument error code"; exit 1; }
passed=$((passed + 1))
print "PASS  SWIFT_COMPILER_BOUNDARY_INVALID_ARGUMENT"

print "Swift compiler boundary smoke: PASS ($passed/$expected)"
