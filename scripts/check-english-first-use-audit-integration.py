#!/usr/bin/env python3
"""Keep the isolated English first-use walkthrough wired as one local contract."""

from __future__ import annotations

import json
import os
import pathlib
import sys


ROOT = pathlib.Path(
    os.environ.get(
        "CHENGYIN_ENGLISH_FIRST_USE_ROOT",
        pathlib.Path(__file__).resolve().parent.parent,
    )
).resolve()


REQUIRED_SNIPPETS = {
    "Sources/CompanionApp/CompanionRuntimeEnvironment.swift": (
        'static let firstUseAuditInfoKey = "ChengyinFirstUseAuditMode"',
        '"CHENGYIN_FIRST_USE_AUDIT_ROOT"',
        '"sharedUserContentAccess": false',
        '"releaseState": "NOT_PUBLIC_RELEASE_READY"',
    ),
    "Sources/CompanionApp/CompanionViewModel.swift": (
        "CompanionRuntimeEnvironment.current()",
        "runtimeEnvironment.publishAuditReceipt()",
        "runtimeEnvironment.contentRoot",
        "legacySessionsEnabled: false",
    ),
    "scripts/english-first-use-visual-audit.swift": (
        'fileName: "01-tap-invitation.png"',
        'fileName: "02-double-click-invitation.png"',
        'fileName: "03-local-preference.png"',
        'fileName: "04-shared-work-arc.png"',
        '"05-completed.png"',
        '"PENDING_HUMAN_REVIEW"',
        '"PENDING_EXTERNAL_DEVICE"',
        '"NOT_PUBLIC_RELEASE_READY"',
    ),
    "scripts/run-english-first-use-visual-audit.sh": (
        "--source-only",
        "ChengyinFirstUseAuditMode",
        "-AppleLanguages '(en)'",
        "-AppleLocale en_US",
        "sharedUserContentAccess",
    ),
    "scripts/run-runtime-environment-smoke.sh": (
        "CompanionRuntimeEnvironment.swift",
        "runtime-environment-smoke.swift",
    ),
    "scripts/run-english-first-use-visual-audit-smoke.sh": (
        "PASS_WITH_PENDING",
        "FIRST_USE_VISUAL_AUDIT_INVALID_ARGUMENT",
    ),
    "scripts/doctor.sh": (
        "check-english-first-use-audit-integration.py",
        "run-english-first-use-visual-audit-smoke.sh",
    ),
    ".github/workflows/ci.yml": (
        "check-english-first-use-audit-integration.py",
        "run-english-first-use-visual-audit-smoke.sh",
    ),
    "scripts/build-portable-source.sh": (
        "Schemas/english-first-use-visual-audit-v1.schema.json",
        "Sources/CompanionApp/CompanionRuntimeEnvironment.swift",
        "scripts/english-first-use-visual-audit.swift",
        "scripts/run-english-first-use-visual-audit.sh",
    ),
    "scripts/audit-portable-source.py": (
        '"Schemas/english-first-use-visual-audit-v1.schema.json"',
        '"Sources/CompanionApp/CompanionRuntimeEnvironment.swift"',
        '"scripts/english-first-use-visual-audit.swift"',
        '"scripts/run-english-first-use-visual-audit.sh"',
    ),
}

FORBIDDEN_WRAPPER_TOKENS = (
    "curl ",
    "wget ",
    "ARK_API_KEY",
    "VOLCENGINE_ACCESS_KEY",
    "SEEDANCE_API_KEY",
    "/Applications/Chengyin Companion.app",
)


def fail(message: str) -> int:
    print(f"FAIL  {message}")
    return 1


def main() -> int:
    for relative, snippets in REQUIRED_SNIPPETS.items():
        path = ROOT / relative
        if not path.is_file() or path.is_symlink():
            return fail(f"required regular source is missing: {relative}")
        text = path.read_text(encoding="utf-8")
        for snippet in snippets:
            if snippet not in text:
                return fail(f"{relative} lost required contract: {snippet}")

    wrapper = (ROOT / "scripts/run-english-first-use-visual-audit.sh").read_text(
        encoding="utf-8"
    )
    for token in FORBIDDEN_WRAPPER_TOKENS:
        if token in wrapper:
            return fail(f"isolated wrapper gained forbidden external/shared access: {token}")

    schema_path = ROOT / "Schemas/english-first-use-visual-audit-v1.schema.json"
    try:
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return fail(f"visual-audit schema is unavailable or invalid: {error}")
    properties = schema.get("properties", {})
    if schema.get("additionalProperties") is not False:
        return fail("visual-audit schema must reject unknown receipt fields")
    if properties.get("humanVoiceOverAudit", {}).get("const") != "PENDING_HUMAN_REVIEW":
        return fail("human VoiceOver review must remain an explicit external gate")
    if properties.get("physicalCleanMacAudit", {}).get("const") != "PENDING_EXTERNAL_DEVICE":
        return fail("physical clean-Mac review must remain an explicit external gate")
    if properties.get("releaseState", {}).get("const") != "NOT_PUBLIC_RELEASE_READY":
        return fail("visual evidence must not imply public-release readiness")
    if properties.get("steps", {}).get("maxItems") != 5:
        return fail("visual-audit receipt must remain bounded to five walkthrough steps")

    print("PASS  isolated English first-use visual-audit integration contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
