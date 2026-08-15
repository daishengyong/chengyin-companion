#!/usr/bin/env python3
"""Keep Chengyin's public Chinese/English entry documents operationally aligned."""

from __future__ import annotations

import pathlib
import re
import sys
import os


ROOT = pathlib.Path(
    os.environ.get(
        "CHENGYIN_PUBLIC_DOC_ROOT",
        pathlib.Path(__file__).resolve().parent.parent,
    )
).resolve()
CHECK_LINK_EXISTENCE = os.environ.get("CHENGYIN_PUBLIC_DOC_SKIP_LINK_EXISTENCE") != "1"
PAIRS = (
    ("README.md", "README.en.md"),
    ("CONTRIBUTING.md", "CONTRIBUTING.en.md"),
    ("SECURITY.md", "SECURITY.en.md"),
    ("SUPPORT.zh-Hans.md", "SUPPORT.md"),
    ("GOVERNANCE.zh-Hans.md", "GOVERNANCE.md"),
    ("ROADMAP.zh-Hans.md", "ROADMAP.md"),
    ("CODE_OF_CONDUCT.zh-Hans.md", "CODE_OF_CONDUCT.md"),
    (
        "docs/SOURCE-PACKAGE-CONTRACT.zh-Hans.md",
        "docs/SOURCE-PACKAGE-CONTRACT.md",
    ),
    (
        "docs/STARTER-MEDIA-CONTRACT.zh-Hans.md",
        "docs/STARTER-MEDIA-CONTRACT.md",
    ),
    (
        "docs/CORE-MODULE-BOUNDARY.zh-Hans.md",
        "docs/CORE-MODULE-BOUNDARY.md",
    ),
    (
        "docs/MODULE-STEWARDSHIP.zh-Hans.md",
        "docs/MODULE-STEWARDSHIP.md",
    ),
    (
        "docs/CODEX-APP-SERVER-ADAPTER.zh-Hans.md",
        "docs/CODEX-APP-SERVER-ADAPTER.md",
    ),
    (
        "docs/EVENT-SPOOL-SECURITY.zh-Hans.md",
        "docs/EVENT-SPOOL-SECURITY.md",
    ),
    (
        "docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.zh-Hans.md",
        "docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.md",
    ),
    ("docs/LOCAL-PREVIEW.zh-Hans.md", "docs/LOCAL-PREVIEW.md"),
    ("docs/PRODUCT-BOUNDARY.zh-Hans.md", "docs/PRODUCT-BOUNDARY.md"),
    ("docs/QUICKSTART.zh-Hans.md", "docs/QUICKSTART.md"),
)
LINK_PATTERN = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
FENCE_LINE_PATTERN = re.compile(r"^\s*(`{3,})([A-Za-z0-9_-]*)\s*$")
HEADING_PATTERN = re.compile(r"^(#{1,6})\s+", re.MULTILINE)
HAN_PATTERN = re.compile(r"[\u3400-\u9fff]")
VOLATILE_CORE_LINE_PATTERNS = (
    re.compile(r"\b\d+(?:-line|\s+lines?)\b[\s\S]{0,120}?CompanionLifestyleScheduler", re.IGNORECASE),
    re.compile(r"\d+\s*行[\s\S]{0,120}?CompanionLifestyleScheduler"),
)
LANGUAGE_COUNTERPARTS = {
    "README.en.md": "README.md",
    "CONTRIBUTING.en.md": "CONTRIBUTING.md",
    "SECURITY.en.md": "SECURITY.md",
    "SUPPORT.zh-Hans.md": "SUPPORT.md",
    "GOVERNANCE.zh-Hans.md": "GOVERNANCE.md",
    "ROADMAP.zh-Hans.md": "ROADMAP.md",
    "CODE_OF_CONDUCT.zh-Hans.md": "CODE_OF_CONDUCT.md",
    "docs/SOURCE-PACKAGE-CONTRACT.md": "docs/SOURCE-PACKAGE-CONTRACT.zh-Hans.md",
    "SOURCE-PACKAGE-CONTRACT.md": "SOURCE-PACKAGE-CONTRACT.zh-Hans.md",
    "docs/STARTER-MEDIA-CONTRACT.md": "docs/STARTER-MEDIA-CONTRACT.zh-Hans.md",
    "STARTER-MEDIA-CONTRACT.md": "STARTER-MEDIA-CONTRACT.zh-Hans.md",
    "docs/CORE-MODULE-BOUNDARY.md": "docs/CORE-MODULE-BOUNDARY.zh-Hans.md",
    "CORE-MODULE-BOUNDARY.md": "CORE-MODULE-BOUNDARY.zh-Hans.md",
    "docs/MODULE-STEWARDSHIP.md": "docs/MODULE-STEWARDSHIP.zh-Hans.md",
    "MODULE-STEWARDSHIP.md": "MODULE-STEWARDSHIP.zh-Hans.md",
    "docs/CODEX-APP-SERVER-ADAPTER.md": "docs/CODEX-APP-SERVER-ADAPTER.zh-Hans.md",
    "CODEX-APP-SERVER-ADAPTER.md": "CODEX-APP-SERVER-ADAPTER.zh-Hans.md",
    "docs/EVENT-SPOOL-SECURITY.md": "docs/EVENT-SPOOL-SECURITY.zh-Hans.md",
    "EVENT-SPOOL-SECURITY.md": "EVENT-SPOOL-SECURITY.zh-Hans.md",
    "docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.md": "docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.zh-Hans.md",
    "ENGLISH-FIRST-USE-VISUAL-AUDIT.md": "ENGLISH-FIRST-USE-VISUAL-AUDIT.zh-Hans.md",
    "docs/LOCAL-PREVIEW.md": "docs/LOCAL-PREVIEW.zh-Hans.md",
    "LOCAL-PREVIEW.md": "LOCAL-PREVIEW.zh-Hans.md",
    "docs/PRODUCT-BOUNDARY.md": "docs/PRODUCT-BOUNDARY.zh-Hans.md",
    "PRODUCT-BOUNDARY.md": "PRODUCT-BOUNDARY.zh-Hans.md",
    "docs/QUICKSTART.md": "docs/QUICKSTART.zh-Hans.md",
    "QUICKSTART.md": "QUICKSTART.zh-Hans.md",
}


def normalized_target(target: str) -> str:
    path, marker, fragment = target.partition("#")
    path = LANGUAGE_COUNTERPARTS.get(path, path)
    return path + (marker + fragment if marker else "")


def relative_links(text: str, *, normalize: bool = True) -> set[str]:
    return {
        normalized_target(target) if normalize else target
        for target in LINK_PATTERN.findall(text)
        if not target.startswith(("http://", "https://", "mailto:"))
    }


def missing_targets(targets: set[str], document_name: str) -> list[str]:
    missing: list[str] = []
    document_parent = pathlib.PurePosixPath(document_name).parent
    for target in sorted(targets):
        path_text = target.partition("#")[0]
        if not path_text:
            continue
        candidate = (ROOT / document_parent / path_text).resolve()
        try:
            candidate.relative_to(ROOT)
        except ValueError:
            missing.append(target)
            continue
        if not candidate.exists():
            missing.append(target)
    return missing


def executable_lines(text: str) -> set[str]:
    result: set[str] = set()
    fence_length = 0
    capture = False
    for raw_line in text.splitlines():
        match = FENCE_LINE_PATTERN.fullmatch(raw_line)
        if fence_length == 0:
            if not match:
                continue
            fence_length = len(match.group(1))
            capture = match.group(2) in {"", "bash", "text"}
            continue
        if match and len(match.group(1)) >= fence_length:
            fence_length = 0
            capture = False
            continue
        if capture:
            line = raw_line.strip()
            if line and not line.startswith("#"):
                result.add(line)
    return result


def heading_shape(text: str) -> list[int]:
    return [len(marker) for marker in HEADING_PATTERN.findall(text)]


def report_difference(
    label: str,
    first_name: str,
    second_name: str,
    first: set[str],
    second: set[str],
) -> bool:
    if first == second:
        return False
    print(f"FAIL  {label} differ between {first_name} and {second_name}")
    for item in sorted(first - second):
        print(f"      only {first_name}: {item}")
    for item in sorted(second - first):
        print(f"      only {second_name}: {item}")
    return True


def main() -> int:
    failed = False
    checked_commands = 0
    checked_links = 0

    for chinese_name, english_name in PAIRS:
        chinese_path = ROOT / chinese_name
        english_path = ROOT / english_name
        try:
            chinese = chinese_path.read_text(encoding="utf-8")
            english = english_path.read_text(encoding="utf-8")
        except OSError as error:
            print(f"FAIL  public document is unavailable: {error}")
            return 1

        if (
            pathlib.PurePosixPath(english_name).name not in chinese
            or pathlib.PurePosixPath(chinese_name).name not in english
        ):
            failed = True
            print(f"FAIL  reciprocal language navigation is missing for {chinese_name}")

        chinese_commands = executable_lines(chinese)
        english_commands = executable_lines(english)
        checked_commands += len(chinese_commands | english_commands)
        failed |= report_difference(
            "executable documentation lines",
            chinese_name,
            english_name,
            chinese_commands,
            english_commands,
        )

        chinese_links = relative_links(chinese)
        english_links = relative_links(english)
        checked_links += len(chinese_links | english_links)
        failed |= report_difference(
            "relative documentation links",
            chinese_name,
            english_name,
            chinese_links,
            english_links,
        )
        if CHECK_LINK_EXISTENCE:
            for document_name, links in (
                (chinese_name, relative_links(chinese, normalize=False)),
                (english_name, relative_links(english, normalize=False)),
            ):
                for target in missing_targets(links, document_name):
                    failed = True
                    print(f"FAIL  {document_name} has a missing or escaping relative link: {target}")

        if heading_shape(chinese) != heading_shape(english):
            failed = True
            print(f"FAIL  heading hierarchy differs between {chinese_name} and {english_name}")

        if len(HAN_PATTERN.findall(chinese)) < 100:
            failed = True
            print(f"FAIL  {chinese_name} no longer contains a substantive Chinese entry surface")
        if len(HAN_PATTERN.findall(english)) > 20:
            failed = True
            print(f"FAIL  {english_name} contains too much untranslated Chinese prose")

        if "CORE-MODULE-BOUNDARY" in chinese_name:
            for document_name, text in ((chinese_name, chinese), (english_name, english)):
                if any(pattern.search(text) for pattern in VOLATILE_CORE_LINE_PATTERNS):
                    failed = True
                    print(
                        "FAIL  volatile Core source metric is hard-coded in "
                        f"{document_name}; use the machine audit receipt"
                    )

    if failed:
        return 1
    print(
        "PASS  public document parity: "
        f"{len(PAIRS)} pairs, {checked_commands} command lines, {checked_links} relative links"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
