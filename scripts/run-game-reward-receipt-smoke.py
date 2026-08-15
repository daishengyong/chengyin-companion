#!/usr/bin/env python3
"""Exercise receipt rejection with simulated fixtures; never claims GUI proof."""

from __future__ import annotations

import copy
import json
import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from game_reward_receipt_contract import (  # noqa: E402
    GAME_IDS,
    make_failure_receipt,
    make_pending_receipt,
    make_pass_receipt,
    validate_receipt,
)


def reward(game: str) -> dict[str, object]:
    return {
        "game": game,
        "status": "PASS",
        "expanded": {"width": 1280, "height": 641},
        "restored": {"width": 132, "height": 146},
    }


identity = {
    "origin": "distPreview",
    "identity": "0.19.47+72.64522aebbbd7",
    "current": True,
    "processCount": 1,
}
valid_pass = make_pass_receipt(identity, [reward(game) for game in GAME_IDS])
valid_failure = make_failure_receipt(
    "UI_DIRECT_PLAY_REWARD_FAILED",
    "The catch reward did not restore.",
    "Return to pet mode and retry.",
    identity=identity,
)
valid_pending = make_pending_receipt(
    "The local GUI session is locked, so pointer input cannot prove direct interaction.",
    "Unlock the current Mac session, leave one verified companion preview running, and retry.",
    identity=identity,
)

cases: list[tuple[str, dict[str, object], bool, str | None]] = [
    ("valid-pass", valid_pass, True, None),
    ("valid-failure", valid_failure, True, None),
    ("valid-pending", valid_pending, True, None),
]

pending_claim = copy.deepcopy(valid_pending)
pending_claim["gameRewards"] = [reward("catch")]
pending_claim["verifiedGameCount"] = 1
cases.append(("pending-claims-game", pending_claim, False, "pending_cannot_claim_game_proof"))

pending_wrong_code = copy.deepcopy(valid_pending)
pending_wrong_code["code"] = "UI_DIRECT_PLAY_REWARD_FAILED"
cases.append(("pending-wrong-code", pending_wrong_code, False, "pending_code_invalid"))

pending_false_proof = copy.deepcopy(valid_pending)
pending_false_proof["proofKind"] = "LIVE_LOCAL_GUI"
cases.append(("pending-false-proof", pending_false_proof, False, "pending_proof_kind_invalid"))

missing_game = copy.deepcopy(valid_pass)
missing_game["gameRewards"].pop()
missing_game["verifiedGameCount"] = 5
cases.append(("pass-missing-game", missing_game, False, "pass_all_games_not_verified"))

duplicate_game = copy.deepcopy(valid_pass)
duplicate_game["gameRewards"][1]["game"] = "catch"
cases.append(("duplicate-game", duplicate_game, False, "game_id_duplicate"))

small_reward = copy.deepcopy(valid_pass)
small_reward["gameRewards"][0]["expanded"] = {"width": 320, "height": 200}
cases.append(("small-reward", small_reward, False, "expanded_not_fullscreen_scale"))

large_restore = copy.deepcopy(valid_pass)
large_restore["gameRewards"][0]["restored"] = {"width": 560, "height": 520}
cases.append(("large-restore", large_restore, False, "restored_not_pet_scale"))

count_mismatch = copy.deepcopy(valid_pass)
count_mismatch["verifiedGameCount"] = 5
cases.append(("count-mismatch", count_mismatch, False, "verified_game_count_mismatch"))

missing_recovery = copy.deepcopy(valid_failure)
missing_recovery["recoveryAction"] = None
cases.append(("failure-missing-recovery", missing_recovery, False, "failure_recovery_invalid"))

unknown_field = copy.deepcopy(valid_pass)
unknown_field["debugPath"] = "redacted"
cases.append(("unknown-field", unknown_field, False, "top_level_fields_invalid"))

private_path = copy.deepcopy(valid_failure)
private_path["message"] = "Failed in /Users/example/project."
cases.append(("private-path", private_path, False, "private_path_exposed"))

simulated_proof = copy.deepcopy(valid_pass)
simulated_proof["proofKind"] = "SIMULATED_CONTRACT_FIXTURE"
cases.append(("simulated-proof", simulated_proof, False, "proof_kind_not_live_gui"))

checks = 0
for label, receipt, should_pass, expected_error in cases:
    errors = validate_receipt(receipt)
    checks += 1
    if should_pass:
        assert not errors, (label, errors)
    else:
        assert expected_error in errors, (label, errors)

schema = json.loads(
    (ROOT / "Schemas/all-game-rewards-v1.schema.json").read_text(encoding="utf-8")
)
assert schema["properties"]["proofKind"]["enum"] == ["LIVE_LOCAL_GUI", "NO_GUI_PROOF"], schema
assert schema["properties"]["networkRequired"]["const"] is False, schema
assert schema["properties"]["providerCredentialsRequired"]["const"] is False, schema
assert schema["properties"]["applicationsDirectoryModified"]["const"] is False, schema
assert schema["properties"]["releaseState"]["const"] == "NOT_PUBLIC_RELEASE_READY", schema
assert schema["properties"]["status"]["enum"] == ["PASS", "PENDING", "FAIL"], schema
checks += 1

print(
    f"Game-reward receipt smoke: PASS ({checks}/{checks} simulated contract fixtures; no GUI claim)"
)
print("Proof kind exercised by fixtures: SIMULATED_CONTRACT_FIXTURE")
print("Production receipt proof kind required: LIVE_LOCAL_GUI")
print("Release state: NOT_PUBLIC_RELEASE_READY")
