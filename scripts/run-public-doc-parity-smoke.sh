#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_dir="${script_dir:h}"
checker="$repo_dir/scripts/check-public-doc-parity.py"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-doc-parity.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT INT TERM

copy_clean_fixture() {
  mkdir -p "$fixture_root/docs"
  cp "$repo_dir/README.md" "$fixture_root/README.md"
  cp "$repo_dir/README.en.md" "$fixture_root/README.en.md"
  cp "$repo_dir/CONTRIBUTING.md" "$fixture_root/CONTRIBUTING.md"
  cp "$repo_dir/CONTRIBUTING.en.md" "$fixture_root/CONTRIBUTING.en.md"
  cp "$repo_dir/SECURITY.md" "$fixture_root/SECURITY.md"
  cp "$repo_dir/SECURITY.en.md" "$fixture_root/SECURITY.en.md"
  cp "$repo_dir/SUPPORT.md" "$fixture_root/SUPPORT.md"
  cp "$repo_dir/SUPPORT.zh-Hans.md" "$fixture_root/SUPPORT.zh-Hans.md"
  cp "$repo_dir/GOVERNANCE.md" "$fixture_root/GOVERNANCE.md"
  cp "$repo_dir/GOVERNANCE.zh-Hans.md" "$fixture_root/GOVERNANCE.zh-Hans.md"
  cp "$repo_dir/ROADMAP.md" "$fixture_root/ROADMAP.md"
  cp "$repo_dir/ROADMAP.zh-Hans.md" "$fixture_root/ROADMAP.zh-Hans.md"
  cp "$repo_dir/CODE_OF_CONDUCT.md" "$fixture_root/CODE_OF_CONDUCT.md"
  cp "$repo_dir/CODE_OF_CONDUCT.zh-Hans.md" "$fixture_root/CODE_OF_CONDUCT.zh-Hans.md"
  cp "$repo_dir/docs/SOURCE-PACKAGE-CONTRACT.md" \
    "$fixture_root/docs/SOURCE-PACKAGE-CONTRACT.md"
  cp "$repo_dir/docs/SOURCE-PACKAGE-CONTRACT.zh-Hans.md" \
    "$fixture_root/docs/SOURCE-PACKAGE-CONTRACT.zh-Hans.md"
  cp "$repo_dir/docs/STARTER-MEDIA-CONTRACT.md" \
    "$fixture_root/docs/STARTER-MEDIA-CONTRACT.md"
  cp "$repo_dir/docs/STARTER-MEDIA-CONTRACT.zh-Hans.md" \
    "$fixture_root/docs/STARTER-MEDIA-CONTRACT.zh-Hans.md"
  cp "$repo_dir/docs/CORE-MODULE-BOUNDARY.md" \
    "$fixture_root/docs/CORE-MODULE-BOUNDARY.md"
  cp "$repo_dir/docs/CORE-MODULE-BOUNDARY.zh-Hans.md" \
    "$fixture_root/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
  cp "$repo_dir/docs/MODULE-STEWARDSHIP.md" \
    "$fixture_root/docs/MODULE-STEWARDSHIP.md"
  cp "$repo_dir/docs/MODULE-STEWARDSHIP.zh-Hans.md" \
    "$fixture_root/docs/MODULE-STEWARDSHIP.zh-Hans.md"
  cp "$repo_dir/docs/CODEX-APP-SERVER-ADAPTER.md" \
    "$fixture_root/docs/CODEX-APP-SERVER-ADAPTER.md"
  cp "$repo_dir/docs/CODEX-APP-SERVER-ADAPTER.zh-Hans.md" \
    "$fixture_root/docs/CODEX-APP-SERVER-ADAPTER.zh-Hans.md"
  cp "$repo_dir/docs/EVENT-SPOOL-SECURITY.md" \
    "$fixture_root/docs/EVENT-SPOOL-SECURITY.md"
  cp "$repo_dir/docs/EVENT-SPOOL-SECURITY.zh-Hans.md" \
    "$fixture_root/docs/EVENT-SPOOL-SECURITY.zh-Hans.md"
  cp "$repo_dir/docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.md" \
    "$fixture_root/docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.md"
  cp "$repo_dir/docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.zh-Hans.md" \
    "$fixture_root/docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.zh-Hans.md"
  cp "$repo_dir/docs/LOCAL-PREVIEW.md" \
    "$fixture_root/docs/LOCAL-PREVIEW.md"
  cp "$repo_dir/docs/LOCAL-PREVIEW.zh-Hans.md" \
    "$fixture_root/docs/LOCAL-PREVIEW.zh-Hans.md"
  cp "$repo_dir/docs/PRODUCT-BOUNDARY.md" \
    "$fixture_root/docs/PRODUCT-BOUNDARY.md"
  cp "$repo_dir/docs/PRODUCT-BOUNDARY.zh-Hans.md" \
    "$fixture_root/docs/PRODUCT-BOUNDARY.zh-Hans.md"
}

run_fixture() {
  CHENGYIN_PUBLIC_DOC_ROOT="$fixture_root" \
    CHENGYIN_PUBLIC_DOC_SKIP_LINK_EXISTENCE=1 \
    python3 "$checker" 2>&1
}

copy_clean_fixture
run_fixture >/dev/null

python3 -c '
from pathlib import Path
p = Path("'$fixture_root'/README.en.md")
p.write_text(p.read_text().replace(
    "./scripts/bootstrap-local.sh --check-only",
    "./scripts/bootstrap-local.sh --incorrect-option",
    1,
), encoding="utf-8")
'
set +e
command_failure="$(run_fixture)"
command_exit=$?
set -e
if [[ "$command_exit" -eq 0 ]] || ! grep -Fq "executable documentation lines" <<<"$command_failure"; then
  echo "FAIL  command drift was not rejected" >&2
  exit 1
fi

copy_clean_fixture
python3 -c '
from pathlib import Path
p = Path("'$fixture_root'/README.en.md")
p.write_text(p.read_text().replace("ROADMAP.md", "MISSING.md", 1), encoding="utf-8")
'
set +e
link_failure="$(run_fixture)"
link_exit=$?
set -e
if [[ "$link_exit" -eq 0 ]] || ! grep -Fq "relative documentation links" <<<"$link_failure"; then
  echo "FAIL  relative-link drift was not rejected" >&2
  exit 1
fi

copy_clean_fixture
python3 -c '
from pathlib import Path
p = Path("'$fixture_root'/CONTRIBUTING.en.md")
p.write_text(p.read_text().replace("## Pull requests", "### Pull requests", 1), encoding="utf-8")
'
set +e
heading_failure="$(run_fixture)"
heading_exit=$?
set -e
if [[ "$heading_exit" -eq 0 ]] || ! grep -Fq "heading hierarchy" <<<"$heading_failure"; then
  echo "FAIL  heading drift was not rejected" >&2
  exit 1
fi

copy_clean_fixture
python3 -c '
from pathlib import Path
source = Path("'$fixture_root'/docs/CORE-MODULE-BOUNDARY.md")
source.write_text(source.read_text().replace(
    "`CompanionLifestyleScheduler` has moved out of App.",
    "The 602-line `CompanionLifestyleScheduler` has moved out of App.",
    1,
), encoding="utf-8")
'
set +e
metric_failure="$(run_fixture)"
metric_exit=$?
set -e
if [[ "$metric_exit" -eq 0 ]] || ! grep -Fq "volatile Core source metric" <<<"$metric_failure"; then
  echo "FAIL  volatile source-metric drift was not rejected" >&2
  exit 1
fi

echo "Public document parity smoke: PASS (4 rejection cases + clean baseline)"
