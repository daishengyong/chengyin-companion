#!/usr/bin/env python3
"""Pure, path-safe contract for real all-six-game GUI audit receipts."""

from __future__ import annotations

import json
import re
from typing import Optional


CONTRACT = "chengyin.all-game-rewards/v1"
PROOF_KIND = "LIVE_LOCAL_GUI"
PENDING_PROOF_KIND = "NO_GUI_PROOF"
RELEASE_STATE = "NOT_PUBLIC_RELEASE_READY"
GAME_IDS = ("catch", "hide", "combo", "heart", "rhythm", "feed")
LOCKED_SESSION_CODE = "UI_DIRECT_PLAY_GUI_SESSION_LOCKED"
TOP_LEVEL_KEYS = {
    "schemaVersion",
    "contract",
    "proofKind",
    "status",
    "code",
    "message",
    "recoveryAction",
    "networkRequired",
    "providerCredentialsRequired",
    "applicationsDirectoryModified",
    "runtimeIdentity",
    "gameRewards",
    "verifiedGameCount",
    "releaseState",
}
IDENTITY_PATTERN = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+\.[0-9a-f]{12}$")
CODE_PATTERN = re.compile(r"^UI_DIRECT_PLAY_[A-Z0-9_]+$")
PRIVATE_PATH_MARKERS = ("/Users/", "/Volumes/", "/private/tmp/")


def _valid_dimensions(value: object) -> bool:
    return (
        isinstance(value, dict)
        and set(value) == {"width", "height"}
        and isinstance(value.get("width"), int)
        and not isinstance(value.get("width"), bool)
        and isinstance(value.get("height"), int)
        and not isinstance(value.get("height"), bool)
        and 1 <= value["width"] <= 10_000
        and 1 <= value["height"] <= 10_000
    )


def validate_receipt(receipt: object) -> list[str]:
    errors: list[str] = []
    if not isinstance(receipt, dict):
        return ["receipt_not_object"]
    if set(receipt) != TOP_LEVEL_KEYS:
        errors.append("top_level_fields_invalid")
    if receipt.get("schemaVersion") != 1:
        errors.append("schema_version_invalid")
    if receipt.get("contract") != CONTRACT:
        errors.append("contract_invalid")
    status = receipt.get("status")
    expected_proof = PENDING_PROOF_KIND if status == "PENDING" else PROOF_KIND
    if receipt.get("proofKind") != expected_proof:
        errors.append(
            "pending_proof_kind_invalid"
            if status == "PENDING"
            else "proof_kind_not_live_gui"
        )
    if receipt.get("networkRequired") is not False:
        errors.append("network_boundary_invalid")
    if receipt.get("providerCredentialsRequired") is not False:
        errors.append("credentials_boundary_invalid")
    if receipt.get("applicationsDirectoryModified") is not False:
        errors.append("applications_boundary_invalid")
    if receipt.get("releaseState") != RELEASE_STATE:
        errors.append("release_state_invalid")
    if not isinstance(receipt.get("message"), str) or not 1 <= len(receipt["message"]) <= 320:
        errors.append("message_invalid")

    identity = receipt.get("runtimeIdentity")
    if identity is not None:
        if not isinstance(identity, dict) or set(identity) != {
            "origin", "identity", "current", "processCount"
        }:
            errors.append("runtime_identity_invalid")
        else:
            identity_value = identity.get("identity")
            if identity_value is not None and (
                not isinstance(identity_value, str)
                or IDENTITY_PATTERN.fullmatch(identity_value) is None
            ):
                errors.append("runtime_build_identity_invalid")
            if not isinstance(identity.get("current"), bool):
                errors.append("runtime_current_invalid")
            process_count = identity.get("processCount")
            if (
                not isinstance(process_count, int)
                or isinstance(process_count, bool)
                or not 0 <= process_count <= 16
            ):
                errors.append("runtime_process_count_invalid")

    rewards = receipt.get("gameRewards")
    if not isinstance(rewards, list) or len(rewards) > len(GAME_IDS):
        errors.append("game_rewards_invalid")
        rewards = []
    observed_games: list[str] = []
    for reward in rewards:
        if not isinstance(reward, dict) or set(reward) != {
            "game", "status", "expanded", "restored"
        }:
            errors.append("game_reward_fields_invalid")
            continue
        game = reward.get("game")
        if game not in GAME_IDS:
            errors.append("game_id_invalid")
        elif game in observed_games:
            errors.append("game_id_duplicate")
        else:
            observed_games.append(game)
        if reward.get("status") != "PASS":
            errors.append("game_status_invalid")
        expanded = reward.get("expanded")
        restored = reward.get("restored")
        if not _valid_dimensions(expanded):
            errors.append("expanded_dimensions_invalid")
        if not _valid_dimensions(restored):
            errors.append("restored_dimensions_invalid")
        if _valid_dimensions(restored) and (
            restored["width"] > 160 or restored["height"] > 200
        ):
            errors.append("restored_not_pet_scale")
        if _valid_dimensions(expanded) and _valid_dimensions(restored) and (
            expanded["width"] * expanded["height"]
            < restored["width"] * restored["height"] * 20
        ):
            errors.append("expanded_not_fullscreen_scale")

    verified_count = receipt.get("verifiedGameCount")
    if (
        not isinstance(verified_count, int)
        or isinstance(verified_count, bool)
        or verified_count != len(rewards)
    ):
        errors.append("verified_game_count_mismatch")
    if observed_games != list(GAME_IDS[: len(observed_games)]):
        errors.append("game_order_invalid")

    if status == "PASS":
        if receipt.get("code") is not None or receipt.get("recoveryAction") is not None:
            errors.append("pass_failure_fields_present")
        if identity is None or not (
            identity.get("origin") in {"distPreview", "installed"}
            and identity.get("identity") is not None
            and identity.get("current") is True
            and identity.get("processCount") == 1
        ):
            errors.append("pass_runtime_not_current")
        if observed_games != list(GAME_IDS) or verified_count != len(GAME_IDS):
            errors.append("pass_all_games_not_verified")
    elif status == "PENDING":
        if receipt.get("code") != LOCKED_SESSION_CODE:
            errors.append("pending_code_invalid")
        recovery = receipt.get("recoveryAction")
        if not isinstance(recovery, str) or not 1 <= len(recovery) <= 400:
            errors.append("pending_recovery_invalid")
        if identity is None or not (
            identity.get("origin") in {"distPreview", "installed"}
            and identity.get("identity") is not None
            and identity.get("current") is True
            and identity.get("processCount") == 1
        ):
            errors.append("pending_runtime_not_current")
        if rewards or verified_count != 0:
            errors.append("pending_cannot_claim_game_proof")
    elif status == "FAIL":
        code = receipt.get("code")
        recovery = receipt.get("recoveryAction")
        if not isinstance(code, str) or CODE_PATTERN.fullmatch(code) is None:
            errors.append("failure_code_invalid")
        if not isinstance(recovery, str) or not 1 <= len(recovery) <= 400:
            errors.append("failure_recovery_invalid")
        if len(rewards) >= len(GAME_IDS):
            errors.append("failure_cannot_claim_all_games")
    else:
        errors.append("status_invalid")

    encoded = json.dumps(receipt, ensure_ascii=False)
    if any(marker in encoded for marker in PRIVATE_PATH_MARKERS):
        errors.append("private_path_exposed")
    return sorted(set(errors))


def _base_receipt(
    *,
    status: str,
    code: Optional[str],
    message: str,
    recovery_action: Optional[str],
    identity: Optional[dict[str, object]],
    results: list[dict[str, object]],
) -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "contract": CONTRACT,
        "proofKind": PENDING_PROOF_KIND if status == "PENDING" else PROOF_KIND,
        "status": status,
        "code": code,
        "message": message,
        "recoveryAction": recovery_action,
        "networkRequired": False,
        "providerCredentialsRequired": False,
        "applicationsDirectoryModified": False,
        "runtimeIdentity": identity,
        "gameRewards": results,
        "verifiedGameCount": len(results),
        "releaseState": RELEASE_STATE,
    }


def make_failure_receipt(
    code: str,
    message: str,
    recovery_action: str,
    *,
    identity: Optional[dict[str, object]] = None,
    results: Optional[list[dict[str, object]]] = None,
) -> dict[str, object]:
    return _base_receipt(
        status="FAIL",
        code=code,
        message=message,
        recovery_action=recovery_action,
        identity=identity,
        results=list(results or []),
    )


def make_pending_receipt(
    message: str,
    recovery_action: str,
    *,
    identity: dict[str, object],
) -> dict[str, object]:
    return _base_receipt(
        status="PENDING",
        code=LOCKED_SESSION_CODE,
        message=message,
        recovery_action=recovery_action,
        identity=identity,
        results=[],
    )


def make_pass_receipt(
    identity: dict[str, object],
    results: list[dict[str, object]],
) -> dict[str, object]:
    return _base_receipt(
        status="PASS",
        code=None,
        message="All six games proved a fullscreen-scale reward and pet restoration.",
        recovery_action=None,
        identity=identity,
        results=results,
    )
