#!/usr/bin/env python3
"""Keep bounded microgame window placement behind the Core/App boundary."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
POLICY = ROOT / "Sources/CompanionContracts/CompanionMicrogameWindowPolicy.swift"
VIEW_MODEL = ROOT / "Sources/CompanionApp/CompanionViewModel.swift"
SMOKE = ROOT / "scripts/microgame-window-policy-smoke.swift"
WRAPPER = ROOT / "scripts/run-microgame-window-policy-smoke.sh"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL  microgame window policy integration: {message}")


def require(path: Path, snippets: tuple[str, ...]) -> str:
    if not path.is_file() or path.is_symlink():
        fail(f"required regular file is missing: {path.name}")
    text = path.read_text(encoding="utf-8")
    for snippet in snippets:
        if snippet not in text:
            fail(f"{path.name} is missing {snippet!r}")
    return text


def main() -> None:
    policy = require(
        POLICY,
        (
            "public struct CompanionMicrogameWindowPlacement",
            "public enum CompanionMicrogameWindowPolicy",
            "public static func catchPlacement(",
            "public static func hidePlacement(",
            "pointerLocation: CGPoint",
            "previousEdge: CompanionWindowDockEdge?",
            "entropy: UInt64",
            "catchPointerClearance",
            "horizontalPeekExtent",
            "verticalPeekExtent",
            "CompanionWindowPolicy.fallbackVisibleFrame",
        ),
    )
    policy_code = "\n".join(line.split("//", 1)[0] for line in policy.splitlines())
    for forbidden in (
        "AppKit",
        "SwiftUI",
        "NSScreen",
        "NSWindow",
        "NSEvent",
        "UserDefaults",
        "FileManager",
        "URLSession",
        "Process(",
        ".randomElement()",
        "UInt64.random",
    ):
        if forbidden in policy_code:
            fail(f"Core policy acquired a capability or hidden randomness: {forbidden}")

    view_model = require(
        VIEW_MODEL,
        (
            "CompanionMicrogameWindowPolicy.catchPlacement(",
            "CompanionMicrogameWindowPolicy.hidePlacement(",
            "pointerLocation: NSEvent.mouseLocation",
            "previousEdge: hideGameLastEdge",
            "hideGameLastEdge = placement.edge",
            "NSRect(origin: placement.origin, size: window.frame.size)",
        ),
    )
    for stale_recipe in (
        "let safeX = [",
        "let safeY = [",
        "hypot(centerX - cursor.x, centerY - cursor.y)",
        "visible.minX - size.width + 48",
        "visible.maxY - 112",
    ):
        if stale_recipe in view_model:
            fail("App composition still owns a microgame geometry recipe")

    smoke = require(
        SMOKE,
        (
            "catch target escaped the selected display",
            "catch target remained under the pointer",
            "catch placement leaked to the main display",
            "hide placement repeated the immediately previous edge",
            "hidden pet became completely unreachable",
            "horizontal edge lost its clickable peek width",
            "vertical edge lost its clickable peek height",
            "invalid hide geometry did not recover to finite coordinates",
        ),
    )
    if smoke.count("CompanionMicrogameWindowPolicy.hidePlacement(") < 4:
        fail("hide placement matrix lost asymmetric or invalid fixtures")

    wrapper = require(
        WRAPPER,
        (
            "set -euo pipefail",
            "swift-toolchain-env.sh",
            "CompanionMicrogameWindowPolicy.swift",
            "microgame-window-policy-smoke.swift",
        ),
    )
    if "curl " in wrapper or "git clone" in wrapper:
        fail("window policy smoke unexpectedly requires network access")

    print("Microgame window policy integration: PASS")


if __name__ == "__main__":
    main()
