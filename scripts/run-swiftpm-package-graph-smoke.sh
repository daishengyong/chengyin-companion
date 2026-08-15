#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
AUDITOR="$PROJECT_DIR/scripts/audit-swiftpm-package-graph.py"
grep -Fq 'swift-toolchain-env.sh' "$AUDITOR" || {
  print -u2 "FAIL  graph auditor bypassed the shared Swift toolchain preflight"
  exit 1
}
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-swiftpm-graph-smoke.XXXXXX")"
trap 'rm -rf "$SMOKE_ROOT"' EXIT INT TERM
passed=0
expected=10

make_fixture() {
  local name="$1"
  local destination="$SMOKE_ROOT/$name"
  mkdir -p "$destination"
  cp "$PROJECT_DIR/Package.swift" "$destination/Package.swift"
  print -r -- "$destination"
}

assert_private_receipt() {
  local receipt_path="$1"
  if grep -Eq '/Users/|/Volumes/|/private/var/|/tmp/|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+' "$receipt_path"; then
    print -u2 "FAIL  SwiftPM graph receipt exposed a local path or identity"
    exit 1
  fi
}

expect_failure() {
  local expected_code="$1"
  local fixture="$2"
  local receipt_path="$SMOKE_ROOT/receipt-$passed.json"
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" \
    --root "$fixture" --json >"$receipt_path" 2>&1
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

replace_manifest() {
  local fixture="$1"
  local old="$2"
  local new="$3"
  OLD_TEXT="$old" NEW_TEXT="$new" python3 - "$fixture/Package.swift" <<'PY'
import os, pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = os.environ["OLD_TEXT"]
if old not in text:
    raise SystemExit("fixture replacement anchor missing")
path.write_text(text.replace(old, os.environ["NEW_TEXT"], 1), encoding="utf-8")
PY
}

baseline="$(make_fixture baseline)"
baseline_receipt="$SMOKE_ROOT/baseline.json"
PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" \
  --root "$baseline" --json >"$baseline_receipt"
assert_private_receipt "$baseline_receipt"
[[ "$(python3 -c 'import json,sys; value=json.load(open(sys.argv[1], encoding="utf-8")); print(value["status"] if value["manifestSandboxed"] or value["outerSandboxFallback"] else "INVALID")' "$baseline_receipt")" == "PASS" ]] \
  || { print -u2 "FAIL  baseline evaluated package graph"; exit 1; }
passed=$((passed + 1))
print "PASS  evaluated baseline"

external="$(make_fixture external)"
replace_manifest "$external" \
  $'    ],\n    targets: [' \
  $'    ],\n    dependencies: [.package(url: "https://example.invalid/review-me.git", from: "1.0.0")],\n    targets: ['
expect_failure SWIFTPM_GRAPH_EXTERNAL_DEPENDENCY "$external"

core_dependency="$(make_fixture core-dependency)"
replace_manifest "$core_dependency" \
  $'        .target(\n            name: "CompanionContracts",\n            path: "Sources/CompanionContracts"\n        ),' \
  $'        .target(\n            name: "CompanionContracts",\n            dependencies: ["CompanionApp"],\n            path: "Sources/CompanionContracts"\n        ),'
expect_failure SWIFTPM_GRAPH_DEPENDENCY_VIOLATION "$core_dependency"

missing_edge="$(make_fixture missing-edge)"
replace_manifest "$missing_edge" \
  $'        .executableTarget(\n            name: "CompanionApp",\n            dependencies: ["CompanionContracts"],' \
  $'        .executableTarget(\n            name: "CompanionApp",\n            dependencies: [],'
expect_failure SWIFTPM_GRAPH_DEPENDENCY_VIOLATION "$missing_edge"

extra_target="$(make_fixture extra-target)"
replace_manifest "$extra_target" \
  '    targets: [' \
  $'    targets: [\n        .target(name: "UnexpectedBridge", path: "Sources/UnexpectedBridge"),'
expect_failure SWIFTPM_GRAPH_TARGET_DRIFT "$extra_target"

core_setting="$(make_fixture core-setting)"
replace_manifest "$core_setting" \
  $'            name: "CompanionContracts",\n            path: "Sources/CompanionContracts"' \
  $'            name: "CompanionContracts",\n            path: "Sources/CompanionContracts",\n            swiftSettings: [.unsafeFlags(["-DCORE_UNSAFE"])]'
expect_failure SWIFTPM_GRAPH_SETTING_VIOLATION "$core_setting"

resource="$(make_fixture resource)"
replace_manifest "$resource" '.process("Resources")' '.process("OtherResources")'
expect_failure SWIFTPM_GRAPH_RESOURCE_DRIFT "$resource"

platform="$(make_fixture platform)"
replace_manifest "$platform" '.macOS(.v14)' '.macOS(.v13)'
expect_failure SWIFTPM_GRAPH_PLATFORM_DRIFT "$platform"

malformed="$(make_fixture malformed)"
python3 - "$malformed/Package.swift" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8") + "\nthis is not Swift\n", encoding="utf-8")
PY
expect_failure SWIFTPM_GRAPH_EVALUATION_FAILED "$malformed"

invalid_receipt="$SMOKE_ROOT/invalid-argument.json"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 "$AUDITOR" --unsupported --json \
  >"$invalid_receipt" 2>&1
invalid_status=$?
set -e
[[ "$invalid_status" -eq 1 ]] || {
  print -u2 "FAIL  invalid argument was accepted"
  exit 1
}
assert_private_receipt "$invalid_receipt"
[[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["code"])' "$invalid_receipt")" == "SWIFTPM_GRAPH_INVALID_ARGUMENT" ]] \
  || { print -u2 "FAIL  invalid argument error code"; exit 1; }
passed=$((passed + 1))
print "PASS  SWIFTPM_GRAPH_INVALID_ARGUMENT"

print "SwiftPM package graph smoke: PASS ($passed/$expected)"
