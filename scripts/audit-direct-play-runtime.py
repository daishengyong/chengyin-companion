#!/usr/bin/env python3
"""Exercise real direct-play windows and emit one path-safe runtime receipt."""

from __future__ import annotations

import json
import os
import pathlib
import re
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
IDENTITY_AUDITOR = ROOT / "scripts/audit-local-runtime-identity.py"
WINDOW_AUDITOR = ROOT / "scripts/direct-play-window-audit.swift"
GAME_AUDITOR = ROOT / "scripts/catch-game-smoke.swift"
SIZE_PATTERN = re.compile(r"reward (expanded|restored): ([0-9]+)x([0-9]+)")


def publish(receipt: dict[str, object], exit_code: int) -> int:
    print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
    return exit_code


def failure(
    code: str,
    message: str,
    recovery_action: str,
    *,
    identity: dict[str, object] | None = None,
    window_behavior: dict[str, object] | None = None,
) -> int:
    return publish(
        {
            "schemaVersion": 1,
            "contract": "chengyin.direct-play-runtime/v1",
            "status": "FAIL",
            "code": code,
            "message": message,
            "recoveryAction": recovery_action,
            "runtimeIdentity": identity,
            "windowBehavior": window_behavior,
            "gameReward": None,
            "releaseState": "NOT_PUBLIC_RELEASE_READY",
        },
        1,
    )


def pending(
    code: str,
    message: str,
    recovery_action: str,
    *,
    identity: dict[str, object] | None = None,
    window_behavior: dict[str, object] | None = None,
) -> int:
    return publish(
        {
            "schemaVersion": 1,
            "contract": "chengyin.direct-play-runtime/v1",
            "status": "PENDING",
            "code": code,
            "message": message,
            "recoveryAction": recovery_action,
            "runtimeIdentity": identity,
            "windowBehavior": window_behavior,
            "gameReward": None,
            "releaseState": "NOT_PUBLIC_RELEASE_READY",
        },
        2,
    )


def run_json(command: list[str], timeout: float) -> tuple[int, dict[str, object] | None]:
    try:
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
        )
    except (OSError, subprocess.TimeoutExpired):
        return 1, None
    try:
        receipt = json.loads(result.stdout)
    except json.JSONDecodeError:
        return result.returncode or 1, None
    return result.returncode, receipt if isinstance(receipt, dict) else None


def main() -> int:
    _, identity_receipt = run_json(
        [sys.executable, str(IDENTITY_AUDITOR), "--json"],
        timeout=10,
    )
    if identity_receipt is None:
        return failure(
            "UI_DIRECT_PLAY_RUNTIME_UNAVAILABLE",
            "The local runtime identity could not be verified.",
            "Run python3 scripts/audit-local-runtime-identity.py --json, follow its recovery action, then retry.",
        )
    running = identity_receipt.get("running")
    safe_identity = (
        {
            "origin": running.get("origin"),
            "identity": running.get("identity"),
            "current": running.get("current"),
            "processCount": running.get("processCount"),
        }
        if isinstance(running, dict)
        else None
    )
    if not isinstance(running, dict) or not (
        running.get("current") is True
        and running.get("processCount") == 1
        and running.get("origin") in {"distPreview", "installed"}
    ):
        return failure(
            "UI_DIRECT_PLAY_RUNTIME_UNAVAILABLE",
            "Direct-play audit requires exactly one current verified application process.",
            "Resolve the local runtime identity receipt, launch one verified copy, and retry.",
            identity=safe_identity,
        )

    window_exit, window_receipt = run_json(
        ["/usr/bin/xcrun", "swift", str(WINDOW_AUDITOR)],
        timeout=35,
    )
    if window_receipt is None:
        return failure(
            "UI_DIRECT_PLAY_RUNTIME_UNAVAILABLE",
            "The direct-play window audit did not return a readable receipt.",
            "Return the companion to pet mode, close transient panels, and retry.",
            identity=safe_identity,
        )
    if window_exit == 2 and window_receipt.get("status") == "PENDING":
        return pending(
            str(window_receipt.get("code") or "UI_DIRECT_PLAY_GUI_SESSION_LOCKED"),
            str(window_receipt.get("message") or "The GUI interaction gate is pending."),
            str(
                window_receipt.get("recoveryAction")
                or "Unlock the local GUI session and retry the direct-play audit."
            ),
            identity=safe_identity,
            window_behavior=window_receipt,
        )
    if window_exit != 0 or window_receipt.get("status") != "PASS":
        return failure(
            str(window_receipt.get("code") or "UI_DIRECT_PLAY_RUNTIME_UNAVAILABLE"),
            str(window_receipt.get("message") or "The direct-play window audit failed."),
            str(
                window_receipt.get("recoveryAction")
                or "Return to pet mode and retry the direct-play audit."
            ),
            identity=safe_identity,
            window_behavior=window_receipt,
        )

    try:
        game = subprocess.run(
            ["/usr/bin/xcrun", "swift", str(GAME_AUDITOR), "5"],
            check=False,
            capture_output=True,
            text=True,
            timeout=45,
        )
    except (OSError, subprocess.TimeoutExpired):
        return failure(
            "UI_DIRECT_PLAY_REWARD_FAILED",
            "The five-catch reward audit did not finish within its bounded window.",
            "Return to pet mode, ensure pointer automation is already available, and retry.",
            identity=safe_identity,
            window_behavior=window_receipt,
        )

    sizes = {
        match.group(1): {
            "width": int(match.group(2)),
            "height": int(match.group(3)),
        }
        for match in SIZE_PATTERN.finditer(game.stdout)
    }
    if game.returncode != 0 or set(sizes) != {"expanded", "restored"}:
        return failure(
            "UI_DIRECT_PLAY_REWARD_FAILED",
            "The five-catch game did not prove both a large reward and pet restoration.",
            "Return to pet mode, finish any active game, and retry the runtime audit.",
            identity=safe_identity,
            window_behavior=window_receipt,
        )
    expanded = sizes["expanded"]
    restored = sizes["restored"]
    if (
        expanded["width"] * expanded["height"]
        < restored["width"] * restored["height"] * 20
    ):
        return failure(
            "UI_DIRECT_PLAY_REWARD_FAILED",
            "The game reward expanded, but not to a fullscreen-scale presentation.",
            "Return to pet mode, verify fullscreen presentation on the selected display, and retry.",
            identity=safe_identity,
            window_behavior=window_receipt,
        )

    return publish(
        {
            "schemaVersion": 1,
            "contract": "chengyin.direct-play-runtime/v1",
            "status": "PASS",
            "code": None,
            "message": "Real pet click, magic-wand action, large game reward and restoration passed.",
            "recoveryAction": None,
            "runtimeIdentity": safe_identity,
            "windowBehavior": window_receipt,
            "gameReward": sizes,
            "releaseState": "NOT_PUBLIC_RELEASE_READY",
        },
        0,
    )


if __name__ == "__main__":
    raise SystemExit(main())
