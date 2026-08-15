#!/usr/bin/env python3
"""Check that Chengyin's shipped UI keys exist in both base locales."""

from __future__ import annotations

import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
LOCALES = {
    "zh-Hans": ROOT / "Sources/CompanionApp/Resources/zh-Hans.lproj/Localizable.strings",
    "en": ROOT / "Sources/CompanionApp/Resources/en.lproj/Localizable.strings",
}
KEY_PATTERN = re.compile(r'^\s*"((?:\\.|[^"\\])*)"\s*=')
ENTRY_PATTERN = re.compile(
    r'^\s*"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;\s*$'
)
FORMAT_PATTERN = re.compile(r'%(?:\d+\$)?[@diuoxXfFeEgGcs]')
SOURCE_KEY_PATTERNS = [
    re.compile(r'key:\s*"([A-Za-z0-9_.-]+)"'),
    re.compile(r'localizedUI\("([A-Za-z0-9_.-]+)"'),
    re.compile(r'companion(?:Text|Format)\(\s*"([A-Za-z0-9_.-]+)"'),
    re.compile(r'companionAccessibility(?:Text|Format)\(\s*"([A-Za-z0-9_.-]+)"'),
]
STATIC_UI_KEY_PATTERNS = [
    re.compile(
        r'\b(?:Text|Button|Label|Toggle|Picker|Menu|Section|GroupBox|CommandMenu|Window|Link|ShareLink|DisclosureGroup)'
        r'\(\s*"((?:\\.|[^"\\])*)"'
    ),
    re.compile(
        r'\.(?:accessibilityLabel|accessibilityHint|accessibilityValue|help|navigationTitle|alert|confirmationDialog)'
        r'\(\s*"((?:\\.|[^"\\])*)"'
    ),
]


def strings_keys(path: pathlib.Path) -> set[str]:
    keys: set[str] = set()
    duplicates: set[str] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        match = KEY_PATTERN.match(line)
        if not match:
            continue
        key = match.group(1)
        if key in keys:
            duplicates.add(key)
        keys.add(key)
    if duplicates:
        rendered = ", ".join(sorted(duplicates))
        raise ValueError(f"{path}: duplicate localization keys: {rendered}")
    return keys


def strings_values(path: pathlib.Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = ENTRY_PATTERN.match(line)
        if match:
            values[match.group(1)] = match.group(2)
    return values


def referenced_semantic_keys() -> set[str]:
    keys: set[str] = set()
    source_root = ROOT / "Sources/CompanionApp"
    for path in source_root.glob("*.swift"):
        text = path.read_text(encoding="utf-8")
        for pattern in SOURCE_KEY_PATTERNS:
            keys.update(pattern.findall(text))
    return keys


def referenced_static_ui_keys() -> set[str]:
    keys: set[str] = set()
    source_root = ROOT / "Sources/CompanionApp"
    for path in source_root.glob("*.swift"):
        text = path.read_text(encoding="utf-8")
        for pattern in STATIC_UI_KEY_PATTERNS:
            keys.update(key for key in pattern.findall(text) if r"\(" not in key)
    return keys


def main() -> int:
    try:
        locale_keys = {name: strings_keys(path) for name, path in LOCALES.items()}
    except (OSError, ValueError) as error:
        print(f"FAIL  {error}", file=sys.stderr)
        return 1

    all_keys = set().union(*locale_keys.values())
    failed = False
    for locale, keys in locale_keys.items():
        missing = sorted(all_keys - keys)
        if missing:
            failed = True
            print(f"FAIL  {locale} is missing {len(missing)} shipped keys:")
            for key in missing:
                print(f"      {key}")

    referenced = referenced_semantic_keys()
    static_ui_keys = referenced_static_ui_keys()
    referenced_all = referenced | static_ui_keys
    for locale, keys in locale_keys.items():
        missing = sorted(referenced_all - keys)
        if missing:
            failed = True
            print(f"FAIL  {locale} is missing {len(missing)} referenced semantic keys:")
            for key in missing:
                print(f"      {key}")

    locale_values = {name: strings_values(path) for name, path in LOCALES.items()}
    baseline_name = next(iter(LOCALES))
    baseline_values = locale_values[baseline_name]
    for locale, values in locale_values.items():
        if locale == baseline_name:
            continue
        for key in sorted(all_keys):
            baseline_formats = FORMAT_PATTERN.findall(baseline_values.get(key, ""))
            localized_formats = FORMAT_PATTERN.findall(values.get(key, ""))
            if baseline_formats != localized_formats:
                failed = True
                print(
                    f"FAIL  {locale} format placeholders differ for {key}: "
                    f"{baseline_formats} != {localized_formats}"
                )

    if failed:
        return 1
    print(
        f"PASS  localization parity: {len(all_keys)} shared keys, "
        f"{len(referenced)} semantic keys and {len(static_ui_keys)} static UI literals referenced"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
