#!/usr/bin/env python3
"""Prove all six live game rewards expand and restore with one safe receipt."""

from __future__ import annotations

import json
import os
import pathlib
import re
import subprocess
import sys

from game_reward_receipt_contract import (
    make_failure_receipt,
    make_pending_receipt,
    make_pass_receipt,
    validate_receipt,
)


ROOT = pathlib.Path(__file__).resolve().parent.parent
IDENTITY_AUDITOR = ROOT / "scripts/audit-local-runtime-identity.py"
WINDOW_PREFLIGHT = ROOT / "scripts/direct-play-window-audit.swift"
GAMES = (
    ("catch", "catch-game-smoke.swift", ("5",), 50),
    ("hide", "hide-game-smoke.swift", ("5",), 50),
    ("combo", "combo-game-smoke.swift", (), 45),
    ("heart", "heart-trace-smoke.swift", (), 50),
    ("rhythm", "rhythm-game-smoke.swift", ("8",), 65),
    ("feed", "feed-game-smoke.swift", (), 50),
)
SIZE_PATTERN = re.compile(
    r"(?P<game>[a-z]+)-game reward (?P<phase>expanded|restored): "
    r"(?P<width>[0-9]+)x(?P<height>[0-9]+)"
)


def publish(receipt: dict[str, object], exit_code: int) -> int:
    validation_errors = validate_receipt(receipt)
    if validation_errors:
        receipt = make_failure_receipt(
            "UI_DIRECT_PLAY_REWARD_FAILED",
            "The live reward audit produced an internally invalid receipt.",
            "Run the static game-reward contract matrix, repair the receipt builder, and retry.",
        )
        exit_code = 1
    print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
    return exit_code


def failure(
    code: str,
    message: str,
    recovery_action: str,
    *,
    identity: dict[str, object] | None = None,
    results: list[dict[str, object]] | None = None,
) -> int:
    return publish(
        make_failure_receipt(
            code,
            message,
            recovery_action,
            identity=identity,
            results=results,
        ),
        1,
    )


def pending(
    message: str,
    recovery_action: str,
    *,
    identity: dict[str, object],
) -> int:
    return publish(
        make_pending_receipt(
            message,
            recovery_action,
            identity=identity,
        ),
        2,
    )


def run_json(command: list[str], timeout: float) -> tuple[int, dict[str, object] | None]:
    try:
        completed = subprocess.run(
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
        decoded = json.loads(completed.stdout)
    except json.JSONDecodeError:
        return completed.returncode or 1, None
    return completed.returncode, decoded if isinstance(decoded, dict) else None


def safe_identity_from(receipt: dict[str, object]) -> dict[str, object] | None:
    running = receipt.get("running")
    if not isinstance(running, dict):
        return None
    return {
        "origin": running.get("origin"),
        "identity": running.get("identity"),
        "current": running.get("current"),
        "processCount": running.get("processCount"),
    }


def main() -> int:
    _, identity_receipt = run_json(
        [sys.executable, str(IDENTITY_AUDITOR), "--json"],
        timeout=10,
    )
    if identity_receipt is None:
        return failure(
            "UI_DIRECT_PLAY_RUNTIME_UNAVAILABLE",
            "The local runtime identity could not be verified.",
            "Run the local runtime identity audit, follow its recovery action, and retry.",
        )
    identity = safe_identity_from(identity_receipt)
    if not isinstance(identity, dict) or not (
        identity.get("current") is True
        and identity.get("processCount") == 1
        and identity.get("origin") in {"distPreview", "installed"}
    ):
        return failure(
            "UI_DIRECT_PLAY_RUNTIME_UNAVAILABLE",
            "The reward audit requires exactly one current verified application process.",
            "Launch one current verified preview, close other copies, and retry.",
            identity=identity,
        )

    preflight_exit, preflight = run_json(
        ["/usr/bin/xcrun", "swift", str(WINDOW_PREFLIGHT)],
        timeout=40,
    )
    if (
        preflight_exit == 2
        and isinstance(preflight, dict)
        and preflight.get("status") == "PENDING"
        and preflight.get("code") == "UI_DIRECT_PLAY_GUI_SESSION_LOCKED"
    ):
        return pending(
            str(preflight.get("message")),
            str(preflight.get("recoveryAction")),
            identity=identity,
        )
    if preflight_exit != 0 or preflight is None or preflight.get("status") != "PASS":
        code = (
            str(preflight.get("code"))
            if isinstance(preflight, dict) and preflight.get("code")
            else "UI_DIRECT_PLAY_RUNTIME_UNAVAILABLE"
        )
        message = (
            str(preflight.get("message"))
            if isinstance(preflight, dict) and preflight.get("message")
            else "The companion could not be normalized to a verified pet window."
        )
        recovery_action = (
            str(preflight.get("recoveryAction"))
            if isinstance(preflight, dict) and preflight.get("recoveryAction")
            else "Close transient panels, restore audiovisual mode, then retry."
        )
        return failure(
            code,
            message,
            recovery_action,
            identity=identity,
        )

    results: list[dict[str, object]] = []
    for game_id, script_name, arguments, timeout in GAMES:
        try:
            completed = subprocess.run(
                [
                    "/usr/bin/xcrun",
                    "swift",
                    str(ROOT / "scripts" / script_name),
                    *arguments,
                ],
                check=False,
                capture_output=True,
                text=True,
                timeout=timeout,
            )
        except (OSError, subprocess.TimeoutExpired):
            return failure(
                "UI_DIRECT_PLAY_REWARD_FAILED",
                f"The {game_id} reward audit exceeded its bounded runtime.",
                "Return to pet mode, finish any active game, and retry.",
                identity=identity,
                results=results,
            )

        observed: dict[str, dict[str, int]] = {}
        for match in SIZE_PATTERN.finditer(completed.stdout):
            if match.group("game") == game_id:
                observed[match.group("phase")] = {
                    "width": int(match.group("width")),
                    "height": int(match.group("height")),
                }
        expanded = observed.get("expanded")
        restored = observed.get("restored")
        if completed.returncode != 0 or expanded is None or restored is None:
            return failure(
                "UI_DIRECT_PLAY_REWARD_FAILED",
                f"The {game_id} game did not prove both reward expansion and restoration.",
                "Return to pet mode, restore audiovisual playback, and retry.",
                identity=identity,
                results=results,
            )
        if (
            expanded["width"] * expanded["height"]
            < restored["width"] * restored["height"] * 20
            or restored["width"] > 160
            or restored["height"] > 200
        ):
            return failure(
                "UI_DIRECT_PLAY_REWARD_FAILED",
                f"The {game_id} reward did not reach fullscreen scale or restore to pet scale.",
                "Verify audiovisual playback and display geometry, then retry.",
                identity=identity,
                results=results,
            )
        results.append(
            {
                "game": game_id,
                "status": "PASS",
                "expanded": expanded,
                "restored": restored,
            }
        )

    return publish(
        make_pass_receipt(identity, results),
        0,
    )


if __name__ == "__main__":
    raise SystemExit(main())
