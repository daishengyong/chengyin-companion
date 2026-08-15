#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-locale-matrix-smoke.XXXXXX")"
TOOL="$("$PROJECT_DIR/scripts/build-creator-tool.sh" locale-matrix)"
EXAMPLE="$PROJECT_DIR/examples/packs/hello-workday"

cleanup() {
  if [[ -n "${SMOKE_ROOT:-}" \
    && "$SMOKE_ROOT" == "${TMPDIR:-/tmp}"/chengyin-locale-matrix-smoke.* \
    && -d "$SMOKE_ROOT" ]]; then
    /bin/rm -rf "$SMOKE_ROOT"
  fi
}
trap cleanup EXIT INT TERM

fail() {
  print -u2 "FAIL  content-pack locale matrix: $1"
  exit 1
}

expect_failure() {
  local code="$1"
  shift
  local output="$SMOKE_ROOT/failure.json"
  set +e
  "$TOOL" "$@" --json >"$output"
  local exit_status=$?
  set -e
  [[ "$exit_status" -eq 1 ]] || fail "$code did not fail"
  python3 - "$output" "$code" <<'PY'
import json, pathlib, sys
receipt=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert receipt["status"] == "FAIL", receipt
assert receipt["code"] == sys.argv[2], receipt
assert receipt["recoveryAction"], receipt
encoded=json.dumps(receipt, ensure_ascii=False)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, receipt
PY
}

"$TOOL" "$EXAMPLE" \
  --locale zh_CN \
  --locale zh-TW \
  --locale en-US \
  --locale fr-FR \
  --json >"$SMOKE_ROOT/matrix.json"
python3 - "$SMOKE_ROOT/matrix.json" <<'PY'
import json, pathlib, sys
r=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert r["contract"] == "chengyin.content-pack-locale-matrix/v1", r
assert r["status"] == "PASS_WITH_WARNINGS", r
assert r["networkRequired"] is False and r["mediaDecodePerformed"] is False, r
assert r["containsLocalizedCopy"] is False, r
assert r["declaredLocales"] == ["zh-Hans", "en-US"], r
rows={row["requestedLocale"]: row for row in r["rows"]}
assert set(rows) == {"zh-cn", "zh-tw", "en-us", "fr-fr"}, rows
assert rows["zh-cn"]["selectedPackMediaLocale"] == "zh-Hans", rows
assert rows["en-us"]["selectedPackMediaLocale"] == "en-US", rows
assert rows["zh-tw"]["packMediaEligible"] is False, rows
assert rows["fr-fr"]["packMediaEligible"] is False, rows
assert rows["zh-tw"]["accessibilityFallbackUsed"] is True, rows
assert rows["fr-fr"]["accessibilityFallbackUsed"] is True, rows
for row in rows.values():
    assert len(row["assetResolutions"]) == 5, row
    assert len(row["experienceResolutions"]) == 1, row
assert r["summary"]["requestedLocaleCount"] == 4, r
assert r["summary"]["mediaEligibleLocaleCount"] == 2, r
encoded=json.dumps(r, ensure_ascii=False)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, r
for forbidden in ("共同庆祝", "celebrate this win", "Example creator"):
    assert forbidden not in encoded, forbidden
PY

"$TOOL" "$EXAMPLE" --json >"$SMOKE_ROOT/default.json"
python3 - "$SMOKE_ROOT/default.json" <<'PY'
import json, pathlib, sys
r=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert r["status"] == "PASS", r
assert [row["requestedLocale"] for row in r["rows"]] == ["zh-hans", "en-us"], r
assert r["summary"]["warningCount"] == 0, r
PY

"$TOOL" "$EXAMPLE" --locale en-US >"$SMOKE_ROOT/human.txt"
grep -Fq "en-us: media=en-US" "$SMOKE_ROOT/human.txt" \
  || fail "human receipt lost the selected locale"
grep -Fq "localized copy is intentionally omitted" "$SMOKE_ROOT/human.txt" \
  || fail "human receipt lost its privacy boundary"

expect_failure CREATOR_LOCALE_MATRIX_DUPLICATE_LOCALE \
  "$EXAMPLE" --locale en-US --locale en-us
expect_failure CREATOR_LOCALE_MATRIX_INVALID_LOCALE \
  "$EXAMPLE" --locale en--US
expect_failure CREATOR_LOCALE_MATRIX_LOCALE_MISSING \
  "$EXAMPLE" --locale
expect_failure CREATOR_LOCALE_MATRIX_UNKNOWN_OPTION \
  "$EXAMPLE" --future-option
expect_failure CREATOR_LOCALE_MATRIX_PACK_DIRECTORY_MISSING \
  "$SMOKE_ROOT/missing-pack"

too_many=("$EXAMPLE")
for index in {0..32}; do
  too_many+=(--locale "en-x$index")
done
expect_failure CREATOR_LOCALE_MATRIX_TOO_MANY_LOCALES "${too_many[@]}"

"$PROJECT_DIR/scripts/audit-content-pack-locales.sh" --help >"$SMOKE_ROOT/help.txt"
grep -Fq "Usage: audit-content-pack-locales.sh" "$SMOKE_ROOT/help.txt" \
  || fail "help lost the public command"

python3 -m json.tool \
  "$PROJECT_DIR/Schemas/content-pack-locale-matrix-v1.schema.json" >/dev/null \
  || fail "receipt schema is not valid JSON"

print "Content-pack locale matrix smoke: PASS (11/11)"
