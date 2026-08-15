#!/usr/bin/env python3
"""Keep all six live reward proofs wired into cloneable project surfaces."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME_SCRIPTS = {
    "catch": "catch-game-smoke.swift",
    "hide": "hide-game-smoke.swift",
    "combo": "combo-game-smoke.swift",
    "heart": "heart-trace-smoke.swift",
    "rhythm": "rhythm-game-smoke.swift",
    "feed": "feed-game-smoke.swift",
}


def fail(message: str) -> None:
    print(f"FAIL  game-reward audit integration: {message}", file=sys.stderr)
    raise SystemExit(1)


def text(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file() or path.is_symlink():
        fail(f"required regular file is missing: {relative}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    audit = text("scripts/audit-all-game-rewards.py")
    window_preflight = text("scripts/direct-play-window-audit.swift")
    contract = text("scripts/game_reward_receipt_contract.py")
    receipt_smoke = text("scripts/run-game-reward-receipt-smoke.py")
    schema = text("Schemas/all-game-rewards-v1.schema.json")
    combined_games = ""
    for game_id, script_name in GAME_SCRIPTS.items():
        script = text(f"scripts/{script_name}")
        combined_games += script
        for claim in (
            f'"{game_id}-game reward expanded: ',
            f'"{game_id}-game reward restored: ',
            "visible.width * 0.80",
            "visible.height * 0.80",
        ):
            if claim not in script:
                fail(f"{game_id} lost a real reward-window proof")
        if game_id == "heart":
            if (
                "let initialWindow = anyCompanionWindowBounds()" not in script
                or "abs($0.width - initialWindow.width) <= 2" not in script
                or "abs($0.height - initialWindow.height) <= 2" not in script
            ):
                fail("heart lost exact pre-game restoration proof")
        elif "width <= 160" not in script or "height <= 200" not in script:
            fail(f"{game_id} lost pet-scale restoration proof")
        if script_name not in audit:
            fail(f"the unified receipt no longer runs {game_id}")

    for claim in (
        '"chengyin.all-game-rewards/v1"',
        'PROOF_KIND = "LIVE_LOCAL_GUI"',
        '"networkRequired": False',
        '"providerCredentialsRequired": False',
        '"applicationsDirectoryModified": False',
        '"releaseState": RELEASE_STATE',
        "validate_receipt(receipt)",
        "make_pass_receipt",
        "make_pending_receipt",
        "make_failure_receipt",
    ):
        if claim not in contract + audit:
            fail("the unified path-safe receipt lost a required contract")
    for claim in (
        "audit-local-runtime-identity.py",
        "direct-play-window-audit.swift",
        "identity.get(\"current\") is True",
        "identity.get(\"processCount\") == 1",
        "expanded[\"width\"] * expanded[\"height\"]",
        "restored[\"width\"] * restored[\"height\"] * 20",
    ):
        if claim not in audit:
            fail("the live audit lost a required runtime proof")
    if (
        "CGSSessionScreenIsLocked" not in window_preflight
        or "UI_DIRECT_PLAY_GUI_SESSION_LOCKED" not in window_preflight
        or 'str(preflight.get("code"))' not in audit
        or 'preflight.get("status") == "PENDING"' not in audit
        or "preflight_exit == 2" not in audit
    ):
        fail("the live audit cannot distinguish a locked GUI session from a product failure")
    for claim in (
        '"proofKind": { "enum": ["LIVE_LOCAL_GUI", "NO_GUI_PROOF"] }',
        '"networkRequired": { "const": false }',
        '"providerCredentialsRequired": { "const": false }',
        '"applicationsDirectoryModified": { "const": false }',
        '"releaseState": { "const": "NOT_PUBLIC_RELEASE_READY" }',
        '"status": { "enum": ["PASS", "PENDING", "FAIL"] }',
    ):
        if claim not in schema:
            fail("the JSON Schema lost a truth or privacy boundary")
    for claim in (
        "SIMULATED_CONTRACT_FIXTURE",
        "no GUI claim",
        "private_path_exposed",
        "proof_kind_not_live_gui",
    ):
        if claim not in receipt_smoke:
            fail("the simulated rejection matrix can overclaim live GUI proof")
    if "/Users/" in audit + combined_games or "/Volumes/" in audit + combined_games:
        fail("a runtime receipt source embeds a private local path")
    if "/Users/zidong" in contract or "/Volumes/d" in contract:
        fail("the privacy validator embeds a real local identity instead of generic markers")
    if 'PRIVATE_PATH_MARKERS = ("/Users/", "/Volumes/", "/private/tmp/")' not in contract:
        fail("the receipt contract no longer rejects common private path families")

    contributor = text("scripts/check-contribution.py")
    doctor = text("scripts/doctor.sh")
    ci = text(".github/workflows/ci.yml")
    portable = text("scripts/run-portable-source-smoke.sh")
    for label, surface in (
        ("contributor check", contributor),
        ("doctor", doctor),
        ("CI", ci),
        ("portable source", portable),
    ):
        if "check-game-reward-audit-integration.py" not in surface:
            fail(f"the static contract is not wired into {label}")
        if "run-game-reward-receipt-smoke.py" not in surface:
            fail(f"the receipt rejection matrix is not wired into {label}")

    print(
        "PASS  game-reward audit integration: six live fullscreen/restoration "
        "proofs, one path-safe aggregate receipt, cloneable static gate"
    )


if __name__ == "__main__":
    main()
