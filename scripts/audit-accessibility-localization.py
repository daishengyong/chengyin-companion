#!/usr/bin/env python3
"""Audit bilingual accessibility semantics without launching the application."""

from __future__ import annotations

import json
import pathlib
import re
import sys


CONTRACT = "chengyin.accessibility-localization/v1"
DEFAULT_ROOT = pathlib.Path(__file__).resolve().parent.parent
LOCALE_PATHS = {
    "en": pathlib.Path(
        "Sources/CompanionApp/Resources/en.lproj/Localizable.strings"
    ),
    "zh-Hans": pathlib.Path(
        "Sources/CompanionApp/Resources/zh-Hans.lproj/Localizable.strings"
    ),
}
SOURCE_PATHS = (
    pathlib.Path("Sources/CompanionContracts/CompanionLocaleResolutionPolicy.swift"),
    pathlib.Path("Sources/CompanionApp/CompanionAccessibility.swift"),
    pathlib.Path("Sources/CompanionApp/ContentView.swift"),
    pathlib.Path("Sources/CompanionApp/CompanionStatusOverlays.swift"),
    pathlib.Path("Sources/CompanionApp/CompanionPlayControls.swift"),
    pathlib.Path("Sources/CompanionApp/CompanionFirstSessionCoach.swift"),
    pathlib.Path("Sources/CompanionApp/CompanionSupportDiagnosticsSection.swift"),
    pathlib.Path("Sources/CompanionApp/ContentPackRuntimeAccessibility.swift"),
    pathlib.Path("Sources/CompanionApp/ContentPackPlaybackModels.swift"),
    pathlib.Path("Sources/CompanionApp/ContentPackRuntimeCatalog.swift"),
    pathlib.Path("Sources/CompanionApp/CompanionMediaAccessibilityPresentation.swift"),
)
REQUIRED_KEYS = (
    "accessibility.codex.awaitingReply",
    "accessibility.codex.completed",
    "accessibility.codex.idle",
    "accessibility.codex.working",
    "accessibility.completionReply.label",
    "accessibility.pet.hint",
    "accessibility.pet.label",
    "accessibility.playback.help",
    "accessibility.playback.label",
    "accessibility.playPalette.help",
    "accessibility.playPalette.hint",
    "accessibility.playPalette.label",
    "accessibility.playPalette.panel",
    "accessibility.relationship.summary",
    "accessibility.runtimeRepair.progress",
    "accessibility.state.collapsed",
    "accessibility.state.expanded",
    "accessibility.surprise.help",
    "accessibility.surprise.label",
    "game.catch.start",
    "game.catch.stop",
    "game.combo.start",
    "game.combo.stop",
    "game.feed.start",
    "game.feed.stop",
    "game.heartTrace.start",
    "game.heartTrace.stop",
    "game.hide.start",
    "game.hide.stop",
    "game.rhythm.start",
    "game.rhythm.stop",
    "play.category.actions",
    "play.category.fantasy",
    "play.category.games",
    "play.category.miniScenes",
    "play.palette.category",
    "play.palette.close",
    "play.palette.restoreVideo",
    "play.palette.restoreVideo.short",
    "play.palette.returnHint",
    "play.palette.title",
    "play.preview.taskComplete",
    "play.preview.firstSession",
    "firstSession.skip",
    "firstSession.preference.work",
    "firstSession.preference.play",
    "firstSession.preference.care",
    "firstSession.singleTap.title",
    "firstSession.doubleTap.title",
    "firstSession.preference.title",
    "firstSession.workArc.title",
    "firstSession.singleTap.detail",
    "firstSession.doubleTap.detail",
    "firstSession.preference.detail",
    "firstSession.workArc.detail",
    "media.accessibility.hint.flashingAndLoud",
    "media.accessibility.hint.flashing",
    "media.accessibility.hint.loud",
)
REQUIRED_IDENTIFIERS = (
    "chengyin.codex-presence",
    "chengyin.completion-reply-cue",
    "chengyin.pet-interaction",
    "chengyin.play-palette",
    "chengyin.play-palette-category",
    "chengyin.play-palette-close",
    "chengyin.play-palette-restore-video",
    "chengyin.play-palette-toggle",
    "chengyin.playback-mode",
    "chengyin.runtime-repair-progress",
    "chengyin.first-session-coach",
    "chengyin.first-session-skip",
    "chengyin.first-session-preference-workCompanion",
    "chengyin.first-session-preference-playfulBreaks",
    "chengyin.first-session-preference-gentleCare",
    "chengyin.surprise-cue",
)
ENTRY_PATTERN = re.compile(
    r'^\s*"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;\s*$'
)
FORMAT_PATTERN = re.compile(r"%(?:\d+\$)?[@diuoxXfFeEgGcs]")
HAN_PATTERN = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff]")
DIRECT_LITERAL_PATTERN = re.compile(
    r"\.accessibility(?:Label|Hint|Value)\(\s*\"(?:\\.|[^\"\\])*\"",
    re.MULTILINE,
)
RUNTIME_BINDINGS = {
    pathlib.Path("Sources/CompanionContracts/CompanionLocaleResolutionPolicy.swift"): (
        "public enum CompanionLocaleResolutionPolicy",
        "public static func compatibilityScore(",
        "public static func bestMatch(",
    ),
    pathlib.Path("Sources/CompanionApp/ContentPackRuntimeAccessibility.swift"): (
        "struct CompanionRuntimeMediaAccessibility",
        "maximumLabelCharacters = 512",
        "maximumValueCharacters = 1_024",
        "CompanionLocaleResolutionPolicy.bestMatch(",
        "func resolvedAccessibility(",
    ),
    pathlib.Path("Sources/CompanionApp/ContentPackPlaybackModels.swift"): (
        "let accessibility: CompanionRuntimeMediaAccessibility?",
    ),
    pathlib.Path("Sources/CompanionApp/ContentPackRuntimeCatalog.swift"): (
        "pack.manifest.contribution?.accessibility",
        "CompanionRuntimeMediaAccessibility(",
    ),
    pathlib.Path("Sources/CompanionApp/CompanionMediaAccessibilityPresentation.swift"): (
        "activeContentSequence?.resolvedAccessibility(",
        "var mediaAccessibilityLabel: String",
        "var mediaAccessibilityValue: String",
        "var mediaAccessibilityHint: String",
        "func companionMediaAccessibility(",
    ),
    pathlib.Path("Sources/CompanionApp/ContentView.swift"): (
        ".companionMediaAccessibility(viewModel)",
    ),
}


class AuditFailure(Exception):
    def __init__(self, code: str, message: str, recovery: str):
        super().__init__(message)
        self.code = code
        self.message = message
        self.recovery = recovery


def fail(code: str, message: str, recovery: str) -> None:
    raise AuditFailure(code, message, recovery)


def read_regular_text(path: pathlib.Path, label: str) -> str:
    if not path.is_file() or path.is_symlink():
        fail(
            "ACCESSIBILITY_CONTRACT_MISSING_KEY",
            f"A required {label} is missing or unsafe.",
            "Restore the tracked localization and presentation sources, then rerun the audit.",
        )
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        fail(
            "ACCESSIBILITY_CONTRACT_MISSING_KEY",
            f"A required {label} is not readable UTF-8 text.",
            "Restore the tracked regular text file, then rerun the audit.",
        )


def parse_strings(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in text.splitlines():
        match = ENTRY_PATTERN.match(line)
        if not match:
            continue
        key, value = match.groups()
        if key in values:
            fail(
                "ACCESSIBILITY_CONTRACT_MISSING_KEY",
                "A required localization table contains a duplicate key.",
                "Remove the duplicate entry and keep exactly one reviewed value per locale.",
            )
        values[key] = value
    return values


def audit(root: pathlib.Path) -> dict[str, object]:
    locale_values: dict[str, dict[str, str]] = {}
    for locale, relative in LOCALE_PATHS.items():
        locale_values[locale] = parse_strings(
            read_regular_text(root / relative, f"{locale} localization table")
        )

    for key in REQUIRED_KEYS:
        for locale in LOCALE_PATHS:
            value = locale_values[locale].get(key)
            if value is None or not value.strip():
                fail(
                    "ACCESSIBILITY_CONTRACT_MISSING_KEY",
                    "A required bilingual accessibility key is missing or empty.",
                    "Add a reviewed non-empty value to both shipped locale tables and retry.",
                )
        english = locale_values["en"][key]
        chinese = locale_values["zh-Hans"][key]
        if HAN_PATTERN.search(english):
            fail(
                "ACCESSIBILITY_CONTRACT_ENGLISH_COPY_INVALID",
                "A required English accessibility value still contains Han characters.",
                "Replace it with reviewed English copy while preserving its format placeholders.",
            )
        if FORMAT_PATTERN.findall(english) != FORMAT_PATTERN.findall(chinese):
            fail(
                "ACCESSIBILITY_CONTRACT_ENGLISH_COPY_INVALID",
                "Bilingual format placeholders differ for a required accessibility value.",
                "Make the English and Simplified Chinese placeholders identical and retry.",
            )

    source_texts = [
        read_regular_text(root / relative, "critical presentation source")
        for relative in SOURCE_PATHS
    ]
    combined = "\n".join(source_texts)
    source_without_line_comments = re.sub(r"//.*$", "", combined, flags=re.MULTILINE)
    if DIRECT_LITERAL_PATTERN.search(source_without_line_comments):
        fail(
            "ACCESSIBILITY_CONTRACT_HARDCODED_SEMANTIC",
            "A critical accessibility label, hint, or value bypasses semantic localization.",
            "Use CompanionLocalization with a registered semantic key, then rerun the audit.",
        )
    for key in REQUIRED_KEYS:
        if f'"{key}"' not in combined:
            fail(
                "ACCESSIBILITY_CONTRACT_MISSING_KEY",
                "A required accessibility key is no longer referenced by the critical UI sources.",
                "Restore the semantic localization binding or add a reviewed compatibility migration.",
            )
    for identifier in REQUIRED_IDENTIFIERS:
        if f'"{identifier}"' not in combined:
            fail(
                "ACCESSIBILITY_CONTRACT_IDENTIFIER_MISSING",
                "A stable critical-control accessibility identifier is missing.",
                "Restore the documented identifier on the matching control and retry.",
            )

    runtime_binding_count = 0
    for relative, tokens in RUNTIME_BINDINGS.items():
        text = read_regular_text(root / relative, "runtime accessibility source")
        for token in tokens:
            if token not in text:
                fail(
                    "ACCESSIBILITY_CONTRACT_RUNTIME_METADATA_DISCONNECTED",
                    "Validated content-pack accessibility metadata is disconnected from runtime media semantics.",
                    "Restore the bounded locale resolver, runtime catalog binding and SwiftUI accessibility projection, then retry.",
                )
            runtime_binding_count += 1

    return {
        "schemaVersion": 1,
        "contract": CONTRACT,
        "status": "PASS",
        "code": None,
        "message": "Bilingual critical-control accessibility semantics are source-verifiable.",
        "recoveryAction": None,
        "localeCount": len(LOCALE_PATHS),
        "semanticKeyCount": len(REQUIRED_KEYS),
        "stableIdentifierCount": len(REQUIRED_IDENTIFIERS),
        "sourceFileCount": len(SOURCE_PATHS),
        "runtimeBindingCount": runtime_binding_count,
        "proofStrength": "source-and-bundled-copy-contract-not-runtime-voiceover-certification",
        "releaseState": "NOT_PUBLIC_RELEASE_READY",
    }


def receipt_for_failure(error: AuditFailure) -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "contract": CONTRACT,
        "status": "FAIL",
        "code": error.code,
        "message": error.message,
        "recoveryAction": error.recovery,
        "proofStrength": "source-and-bundled-copy-contract-not-runtime-voiceover-certification",
        "releaseState": "NOT_PUBLIC_RELEASE_READY",
    }


def parse_arguments(arguments: list[str]) -> tuple[pathlib.Path, bool]:
    root = DEFAULT_ROOT
    json_output = False
    index = 0
    while index < len(arguments):
        argument = arguments[index]
        if argument == "--json":
            json_output = True
        elif argument == "--root" and index + 1 < len(arguments):
            index += 1
            root = pathlib.Path(arguments[index])
        elif argument in {"--help", "-h"}:
            print("Usage: audit-accessibility-localization.py [--root DIR] [--json]")
            raise SystemExit(0)
        else:
            fail(
                "ACCESSIBILITY_CONTRACT_INVALID_ARGUMENT",
                "The accessibility audit received an unsupported argument.",
                "Use only --root DIR and --json, then retry.",
            )
        index += 1
    if not root.is_dir() or root.is_symlink():
        fail(
            "ACCESSIBILITY_CONTRACT_INVALID_ARGUMENT",
            "The accessibility audit root is missing or unsafe.",
            "Provide a regular extracted project directory and retry.",
        )
    return root, json_output


def render(receipt: dict[str, object], json_output: bool) -> None:
    if json_output:
        print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
        return
    if receipt["status"] == "PASS":
        print(
            "PASS  accessibility localization: "
            f"{receipt['semanticKeyCount']} semantic keys, "
            f"{receipt['stableIdentifierCount']} stable identifiers"
        )
        print("NOTE  Runtime VoiceOver and physical clean-Mac certification remain pending.")
    else:
        print(f"FAIL  {receipt['code']}: {receipt['message']}", file=sys.stderr)
        print(f"RECOVERY  {receipt['recoveryAction']}", file=sys.stderr)


def main() -> int:
    json_output = "--json" in sys.argv[1:]
    try:
        root, json_output = parse_arguments(sys.argv[1:])
        receipt = audit(root)
    except AuditFailure as error:
        receipt = receipt_for_failure(error)
        render(receipt, json_output)
        return 1
    except Exception:
        error = AuditFailure(
            "ACCESSIBILITY_CONTRACT_UNEXPECTED_ERROR",
            "The accessibility audit encountered an unexpected local error.",
            "Restore the tracked files and rerun the audit; inspect local diagnostics if it persists.",
        )
        receipt = receipt_for_failure(error)
        render(receipt, json_output)
        return 1
    render(receipt, json_output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
