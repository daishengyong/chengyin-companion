#!/usr/bin/env python3
"""Guard the transparent/cinematic/dim and multi-display integration."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"FAIL  presentation environment integration: {message}", file=sys.stderr)
        raise SystemExit(1)


def source(relative: str) -> str:
    path = ROOT / relative
    require(path.is_file() and not path.is_symlink(), f"missing or unsafe {relative}")
    return path.read_text(encoding="utf-8")


def main() -> int:
    core = source("Sources/CompanionContracts/CompanionPresentationEnvironment.swift")
    settings = source("Sources/CompanionContracts/CompanionSettings.swift")
    backup = source("Sources/CompanionContracts/CompanionBackup.swift")
    catalog = source("Sources/CompanionApp/CompanionDisplayCatalog.swift")
    preferences = source("Sources/CompanionApp/CompanionPresentationPreferences.swift")
    surface = source("Sources/CompanionApp/CompanionPresentationSurface.swift")
    app = source("Sources/CompanionApp/CompanionApp.swift")
    settings_view = source("Sources/CompanionApp/CompanionWindowSettingsSection.swift")
    view_model = source("Sources/CompanionApp/CompanionViewModel.swift")
    settings_backup_projection = source(
        "Sources/CompanionApp/CompanionSettingsBackupProjection.swift"
    )
    diagnostics = source("Sources/CompanionApp/CompanionDiagnostics.swift")
    tests = source("Tests/CompanionContractsTests/main.swift")
    ci = source(".github/workflows/ci.yml")

    for appearance in ("case transparent", "case cinematic", "case dim"):
        require(appearance in settings, f"appearance contract lost {appearance}")
    require(
        "requestedAppearance == .cinematic && systemReduceTransparencyEnabled" in core
        and "systemIncreaseContrastEnabled" in core,
        "accessibility appearance fallback is incomplete",
    )
    require(
        "CompanionDisplaySelectionPolicy" in core
        and ".recoveredToCurrent" in core
        and ".recoveredToMain" in core
        and "CompanionWindowPolicy.fallbackVisibleFrame" in core,
        "disconnected-display recovery is incomplete",
    )
    require(
        "presentationAppearance" in settings
        and "displayTarget" in settings
        and "displayTarget.isValid" in backup
        and "BACKUP_VALIDATION_INVALID_DISPLAY_TARGET" in backup,
        "portable settings or invalid-target rejection is incomplete",
    )
    require(
        "NSApplication.didChangeScreenParametersNotification" in catalog
        and "CompanionDisplaySelectionPolicy.resolve" in catalog
        and "CGDisplayCreateUUIDFromDisplayID" in catalog,
        "AppKit display catalog is not bound to the Core policy",
    )
    require(
        "CompanionPresentationPreferences" in preferences
        and "safeTarget = target.isValid ? target : .followWindow" in preferences,
        "persisted display target lacks safe normalization",
    )
    require(
        "CompanionPresentationSurfacePolicy.plan" in surface
        and ".fill(.ultraThinMaterial)" in surface
        and ".accessibilityHidden(true)" in surface,
        "surface renderer stopped consuming the shared accessible plan",
    )
    require(
        "displayCatalogRevision" in app
        and "displayCatalog.companionWindowSelection" in app
        and "displayCatalog.screen(" in app
        and "targetScreen?.visibleFrame" in app,
        "window migration does not react to display topology",
    )
    require(
        "CompanionPresentationAppearance.allCases" in settings_view
        and "CompanionDisplayTarget.specific(option.id)" in settings_view
        and "已断开的显示器 · 自动回退" in settings_view,
        "user-facing appearance or display recovery controls are missing",
    )
    require(
        "presentationAppearance: preferences.presentationAppearance"
        in settings_backup_projection
        and "displayTarget: preferences.displayTarget" in settings_backup_projection
        and "CompanionSettingsBackupProjection.export(" in view_model
        and "displayTargetMode: displayTarget.mode.rawValue" in view_model,
        "backup or privacy-minimal diagnostics lost presentation state",
    )
    require(
        "displayTargetMode" in diagnostics and "displayTargetIdentifier" not in diagnostics,
        "diagnostic surface exposes or omits the wrong display data",
    )
    require(
        "Presentation surfaces resolve accessibility fallbacks" in tests
        and "Display policy recovers disconnected and invalid screens" in tests,
        "Core positive and recovery matrices are missing",
    )
    require(
        "check-presentation-environment-integration.py" in ci,
        "CI does not execute this integration guard",
    )
    for forbidden in ("URLSession", "WebSocket", "NSMicrophoneUsageDescription"):
        require(forbidden not in core + catalog + preferences, f"unexpected dependency {forbidden}")

    print(
        "PASS  presentation environment integration: three appearances, "
        "accessibility fallback, display recovery, backup and diagnostics"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
