#!/usr/bin/env zsh

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
release_dir="$repo_dir/release"
show_dir="$repo_dir/docs/show"
resource_dir="$repo_dir/Sources/CompanionApp/Resources"
seedance_dir="$repo_dir/video-production/seedance"
static_dir="$repo_dir/packaging/producer-handoff"

preview_zip="$(find "$release_dir" -maxdepth 1 -type f -name 'Chengyin-Companion-*-macos-arm64-preview.zip' | head -1)"
if [[ -z "$preview_zip" ]]; then
  print -u2 "No portable preview ZIP found in $release_dir"
  exit 1
fi

preview_name="${preview_zip:t}"
identity="${preview_name#Chengyin-Companion-}"
identity="${identity%-macos-arm64-preview.zip}"
handoff_name="Chengyin-Companion-Episode-01-Producer-Handoff-${identity}"
output_zip="$release_dir/$handoff_name.zip"

if [[ -e "$output_zip" ]]; then
  print -u2 "Refusing to overwrite existing handoff: $output_zip"
  exit 1
fi

stage_parent="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-producer-handoff.XXXXXX")"
stage_root="$stage_parent/$handoff_name"
cleanup() {
  if [[ -n "${stage_parent:-}" && -d "$stage_parent" ]]; then
    rm -rf -- "$stage_parent"
  fi
}
trap cleanup EXIT INT TERM

ditto --norsrc "$static_dir" "$stage_root"
chmod +x "$stage_root/producer-tools/Check Production Environment.command"

ditto --norsrc "$show_dir/11-PRODUCER-CODEX-START-PROMPT.md" "$stage_root/01-CODEX-START-PROMPT.md"
ditto --norsrc "$show_dir/09-ENVIRONMENT-SETUP.md" "$stage_root/02-ENVIRONMENT-SETUP.md"
ditto --norsrc "$show_dir/10-PRODUCER-HANDOFF-GUIDE.md" "$stage_root/03-PRODUCER-HANDOFF-GUIDE.md"
ditto --norsrc "$show_dir" "$stage_root/program-materials"

mkdir -p "$stage_root/editorial-assets/app-resources"
find "$resource_dir" -type f ! -name '.DS_Store' -print0 | while IFS= read -r -d '' source_path; do
  relative_path="${source_path#$resource_dir/}"
  destination="$stage_root/editorial-assets/app-resources/$relative_path"
  mkdir -p "${destination:h}"
  ditto --norsrc "$source_path" "$destination"
done

mkdir -p "$stage_root/editorial-assets/seedance-bts"
find "$seedance_dir" -type f ! -name '.DS_Store' -print0 | while IFS= read -r -d '' source_path; do
  relative_path="${source_path#$seedance_dir/}"
  lower_path="${relative_path:l}"
  case "$lower_path" in
    commercial-pilot-b0/*|pilot-*/*) continue ;;
    *mini-external-call-ledger*|*task-id.txt|*task-result-redacted.json|*submission-receipt.json|*call-receipt.json) continue ;;
    *reference*|*identity-anchor*|*key-source*|*input-provenance*) continue ;;
    *.lock) continue ;;
  esac
  case "$lower_path" in
    *.mp4|*.mov|*.wav|*.jpg|*.jpeg|*.png|*.json|*.txt|*.tsv) ;;
    *) continue ;;
  esac
  destination="$stage_root/editorial-assets/seedance-bts/$relative_path"
  mkdir -p "${destination:h}"
  ditto --norsrc "$source_path" "$destination"
done

python3 - "$stage_root/editorial-assets/seedance-bts" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
text_suffixes = {".json", ".txt", ".tsv"}
absolute_seedance_path = re.compile(
    r'/(?:Users|Volumes)/[^"\n]*?/video-production/seedance/'
)
for path in root.rglob("*"):
    if not path.is_file() or path.suffix.lower() not in text_suffixes:
        continue
    original = path.read_text(encoding="utf-8")
    sanitized = absolute_seedance_path.sub("seedance-bts/", original)
    if sanitized != original:
        path.write_text(sanitized, encoding="utf-8")
PY

mkdir -p "$stage_root/product-packages"
for product_path in \
  "$preview_zip" \
  "${preview_zip%.zip}.dmg" \
  "${preview_zip%.zip}-source.zip" \
  "$release_dir/${preview_zip:t:r}-SHA256SUMS.txt" \
  "$release_dir/Chengyin-Companion-Episode-01-Production-Kit.zip"
do
  if [[ ! -f "$product_path" ]]; then
    print -u2 "Missing required product package: $product_path"
    exit 1
  fi
  ditto --norsrc "$product_path" "$stage_root/product-packages/${product_path:t}"
done

mkdir -p "$stage_root/generation-workbench/scripts"
for generator_script in \
  "$repo_dir/scripts/generate-seedance-task-complete.py" \
  "$repo_dir/scripts/seedance_generation_safety.py" \
  "$repo_dir/scripts/seedance-safety-checks.py"
do
  ditto --norsrc "$generator_script" "$stage_root/generation-workbench/scripts/${generator_script:t}"
done
chmod +x "$stage_root/generation-workbench/scripts/"*.py

if [[ -f "$seedance_dir/generation-contract.schema.json" ]]; then
  ditto --norsrc \
    "$seedance_dir/generation-contract.schema.json" \
    "$stage_root/generation-workbench/generation-contract.schema.json"
fi
mkdir -p "$stage_root/generation-workbench/video-production/seedance"
ditto --norsrc \
  "$stage_root/generation-workbench/mini-external-call-ledger.template.json" \
  "$stage_root/generation-workbench/video-production/seedance/mini-external-call-ledger.json"

python3 - "$stage_root" <<'PY'
from __future__ import annotations

import hashlib
import os
import sys
from pathlib import Path

root = Path(sys.argv[1])
manifest = root / "FILE-MANIFEST.tsv"

def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def classify(relative: str) -> tuple[str, str]:
    if relative.startswith("editorial-assets/app-resources/"):
        return "final_app_asset", "prototype_rights_review_required"
    if relative.startswith("editorial-assets/seedance-bts/"):
        return "seedance_bts", "internal_production_only"
    if relative.startswith("product-packages/"):
        return "product_package", "personal_preview"
    if relative.startswith("generation-workbench/"):
        return "generation_tool", "human_confirmation_required"
    if relative.startswith("program-materials/"):
        return "program_document", "internal_production"
    if relative.startswith("producer-tools/"):
        return "producer_tool", "internal_production"
    return "handoff_document", "internal_production"

rows = ["path\tbytes\tsha256\trole\trights_status"]
for path in sorted(root.rglob("*")):
    if not path.is_file() or path.name in {"FILE-MANIFEST.tsv", "SHA256SUMS.txt"}:
        continue
    relative = path.relative_to(root).as_posix()
    role, rights = classify(relative)
    rows.append(f"{relative}\t{path.stat().st_size}\t{sha256(path)}\t{role}\t{rights}")
manifest.write_text("\n".join(rows) + "\n", encoding="utf-8")
PY

(
  cd "$stage_root"
  find . -type f ! -name 'SHA256SUMS.txt' -print0 \
    | sort -z \
    | xargs -0 shasum -a 256 \
    > SHA256SUMS.txt
)

if find "$stage_root" -name '.DS_Store' -o -name 'task-id.txt' -o -name '*external-call-ledger.json.lock' | grep -q .; then
  print -u2 "Blocked private or noisy file entered the handoff"
  exit 1
fi

if find "$stage_root/editorial-assets/seedance-bts" -type f \
  \( -iname '*reference*' -o -iname '*identity-anchor*' -o -iname '*key-source*' -o -iname '*receipt*' \) \
  | grep -q .; then
  print -u2 "Blocked Seedance reference or receipt entered the handoff"
  exit 1
fi

python3 - "$stage_root" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
patterns = [
    re.compile(rb"Bearer\s+[A-Za-z0-9._-]{20,}"),
    re.compile(rb"\bAK[A-Za-z0-9]{16,}\b"),
    re.compile(
        rb'(?i)"(?:api[_-]?key|access[_-]?key|secret[_-]?access[_-]?key)"'
        rb'\s*:\s*"(?!REPLACE)[^"]{12,}"'
    ),
]
allowed_suffixes = {".md", ".txt", ".tsv", ".json", ".py", ".command", ".example"}
violations = []
for path in root.rglob("*"):
    if not path.is_file() or path.suffix.lower() not in allowed_suffixes:
        continue
    data = path.read_bytes()
    for pattern in patterns:
        for match in pattern.finditer(data):
            token = match.group(0)
            if b"REPLACE" in token or b"sha256" in data[max(0, match.start()-24):match.start()].lower():
                continue
            violations.append(path.relative_to(root).as_posix())
            break
        if violations and violations[-1] == path.relative_to(root).as_posix():
            break
if violations:
    print("Possible credential-like values in handoff:", file=sys.stderr)
    for item in sorted(set(violations)):
        print(item, file=sys.stderr)
    raise SystemExit(1)
PY

ditto -c -k --norsrc --keepParent "$stage_root" "$output_zip"
print "$output_zip"
