#!/usr/bin/env python3
"""Keep the pet visible across macOS Space and display changes."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def fail(message: str) -> None:
    print(f"FAIL  window-visibility integration: {message}", file=sys.stderr)
    raise SystemExit(1)


def source(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file() or path.is_symlink():
        fail(f"required regular file is missing: {relative}")
    return path.read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def main() -> int:
    keeper = source("Sources/CompanionApp/CompanionWindowVisibilityKeeper.swift")
    app = source("Sources/CompanionApp/CompanionApp.swift")
    lifecycle = source("scripts/run-window-lifecycle-contract.sh")
    doctor = source("scripts/doctor.sh")
    ci = source(".github/workflows/ci.yml")

    for claim in (
        "NSWorkspace.activeSpaceDidChangeNotification",
        "NSApplication.didUnhideNotification",
        "NSApplication.didChangeScreenParametersNotification",
        "DispatchSource.makeTimerSource(queue: .main)",
        "repeating: 5",
        "leeway: .milliseconds(750)",
        "steadyCollectionBehavior",
        ".canJoinAllSpaces",
        ".canJoinAllApplications",
        ".fullScreenAuxiliary",
        ".stationary",
        ".ignoresCycle",
        "window.level = .floating",
        "window.canHide = false",
        "window.hidesOnDeactivate = false",
        "guard !window.isMiniaturized",
        "window.orderFrontRegardless()",
    ):
        require(claim in keeper, f"visibility keeper lost {claim}")
    for forbidden in (
        "activate(ignoringOtherApps:",
        "makeKeyAndOrderFront",
        "CGEvent",
        "AXUIElement",
        "Timer.scheduledTimer",
    ):
        require(forbidden not in keeper, f"visibility keeper gained intrusive behavior {forbidden}")
    require(
        "CompanionWindowVisibilityKeeper(application: NSApp)" in app
        and "visibilityKeeper?.reveal()" in app
        and "visibilityKeeper?.stop()" in app,
        "App lifecycle is not delegated to the focused keeper",
    )
    require(
        "CompanionWindowVisibilityPolicy\n            .steadyCollectionBehavior" in app,
        "initial window configuration lost the cross-Space contract",
    )
    require(
        "private final class CompanionPanel: NSPanel" in app
        and "styleMask: [.borderless, .nonactivatingPanel]" in app
        and "panel.isFloatingPanel = true" in app,
        "pet surface is not hosted by the nonactivating floating panel",
    )
    require(
        "override var canBecomeKey: Bool { true }" in app
        and "panel.becomesKeyOnlyIfNeeded = false" in app,
        "nonactivating panel cannot deliver SwiftUI pet interactions",
    )
    require(
        "transient popover must not terminate" in app,
        "custom panel can be mistaken for a closed SwiftUI scene",
    )
    for claim in (
        "CompanionWindowVisibilityKeeper.swift",
        "activeSpaceDidChangeNotification",
        "!window.isMiniaturized",
    ):
        require(claim in lifecycle, f"window lifecycle contract lost {claim}")
    require(
        "check-window-visibility-integration.py" in doctor
        and "check-window-visibility-integration.py" in ci,
        "Doctor or CI does not execute the visibility guard",
    )

    print(
        "PASS  window-visibility integration: cross-Space and full-screen overlay "
        "policy, focus and minimization preserved"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
