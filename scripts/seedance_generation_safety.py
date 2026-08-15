#!/usr/bin/env python3
"""Fail-closed billing guard for Chengyin Seedance generation.

This module deliberately contains only standard-library code.  It can be
tested without importing an SDK, reading credentials, uploading references or
contacting a provider.
"""

from __future__ import annotations

import re
import statistics
from datetime import datetime, timedelta, timezone
from typing import Any


MINI_MODEL = "doubao-seedance-2-0-mini-260615"
MAX_CALLS_PER_BATCH = 10
MAX_PACKAGE_TOKENS_PER_BATCH = 2_000_000.0
MIN_PACKAGE_TOKEN_RESERVE = 500_000.0
MAX_RECONCILIATION_AGE = timedelta(hours=72)
CONFIRMATION_PHRASE = "USE RECONCILED MINI PACKAGE"


class SeedanceSafetyError(RuntimeError):
    """The requested provider operation is not safe to submit."""


def _number(value: Any, field: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise SeedanceSafetyError(f"{field} must be numeric.")
    result = float(value)
    if result < 0:
        raise SeedanceSafetyError(f"{field} must not be negative.")
    return result


def _timestamp(value: Any, field: str) -> datetime:
    if not isinstance(value, str) or not value.strip():
        raise SeedanceSafetyError(f"{field} must be an ISO-8601 timestamp.")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise SeedanceSafetyError(
            f"{field} must be an ISO-8601 timestamp."
        ) from error
    if parsed.tzinfo is None:
        raise SeedanceSafetyError(f"{field} must include a timezone.")
    return parsed.astimezone(timezone.utc)


def validate_exact_mini_model(model: Any) -> None:
    """Reject Standard, Fast, aliases and future model IDs."""

    if model != MINI_MODEL:
        raise SeedanceSafetyError(
            "External generation is Mini-only. Expected exact model "
            f"{MINI_MODEL!r}; received {model!r}. Standard/Fast have no "
            "override in this project."
        )


def validate_billing_guard(contract: dict[str, Any]) -> dict[str, Any]:
    guard = contract.get("billing_guard")
    if not isinstance(guard, dict):
        raise SeedanceSafetyError(
            "contract.billing_guard is required before any new provider call."
        )

    batch_id = guard.get("batch_id")
    if not isinstance(batch_id, str) or not re.fullmatch(
        r"[A-Za-z0-9][A-Za-z0-9._-]{2,63}",
        batch_id,
    ):
        raise SeedanceSafetyError(
            "billing_guard.batch_id must be a stable 3-64 character ID."
        )

    max_calls = guard.get("max_calls")
    if (
        isinstance(max_calls, bool)
        or not isinstance(max_calls, int)
        or not 1 <= max_calls <= MAX_CALLS_PER_BATCH
    ):
        raise SeedanceSafetyError(
            "billing_guard.max_calls must be between 1 and "
            f"{MAX_CALLS_PER_BATCH}."
        )

    max_tokens = _number(
        guard.get("max_package_tokens"),
        "billing_guard.max_package_tokens",
    )
    if not 1 <= max_tokens <= MAX_PACKAGE_TOKENS_PER_BATCH:
        raise SeedanceSafetyError(
            "billing_guard.max_package_tokens must be between 1 and "
            f"{int(MAX_PACKAGE_TOKENS_PER_BATCH)}."
        )

    return {
        "batch_id": batch_id,
        "max_calls": max_calls,
        "max_package_tokens": max_tokens,
    }


def validate_reconciled_mini_ledger(
    ledger: dict[str, Any],
    *,
    now: datetime | None = None,
) -> dict[str, Any]:
    """Require a recent provider-console package snapshot.

    A local arithmetic ledger cannot prove whether Volcengine ultimately used
    a resource package or account balance.  New submissions therefore remain
    blocked until a human records a recent console snapshot.
    """

    validate_exact_mini_model(ledger.get("model"))
    if ledger.get("pay_as_you_go_spillover_allowed") is not False:
        raise SeedanceSafetyError(
            "Ledger must explicitly set pay_as_you_go_spillover_allowed=false."
        )
    if ledger.get("provider_console_reconciled") is not True:
        raise SeedanceSafetyError(
            "Mini ledger is not reconciled with the provider console."
        )

    topups = ledger.get("topups", [])
    if not isinstance(topups, list):
        raise SeedanceSafetyError("ledger.topups must be an array.")
    unresolved_topups = [
        item
        for item in topups
        if not isinstance(item, dict)
        or item.get("provider_console_reconciled") is not True
    ]
    if unresolved_topups:
        raise SeedanceSafetyError(
            "At least one Mini package top-up is not provider-console reconciled."
        )

    checked_at = _timestamp(
        ledger.get("provider_console_reconciled_at"),
        "provider_console_reconciled_at",
    )
    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    if checked_at > current + timedelta(minutes=5):
        raise SeedanceSafetyError(
            "Provider reconciliation timestamp is unexpectedly in the future."
        )
    if current - checked_at > MAX_RECONCILIATION_AGE:
        raise SeedanceSafetyError(
            "Provider reconciliation is older than 72 hours; refresh it first."
        )

    provider_remaining = _number(
        ledger.get("provider_console_remaining_package_tokens"),
        "provider_console_remaining_package_tokens",
    )
    local_remaining = _number(
        ledger.get("locally_tracked_remaining_package_tokens"),
        "locally_tracked_remaining_package_tokens",
    )
    if local_remaining > provider_remaining:
        raise SeedanceSafetyError(
            "Local remaining balance exceeds the latest provider-console "
            "snapshot; reconcile the ledger before generating."
        )

    pool_id = ledger.get("pool_id")
    if not isinstance(pool_id, str) or not pool_id.strip():
        raise SeedanceSafetyError("ledger.pool_id is required.")

    return {
        "pool_id": pool_id,
        "provider_console_reconciled_at": checked_at.isoformat(),
        "provider_console_remaining_package_tokens": provider_remaining,
        "locally_tracked_remaining_package_tokens": local_remaining,
        "intended_balance_source": (
            "provider_console_reconciled_seedance_2_0_mini_package_snapshot"
        ),
        "billing_source_verified_by_generation_api": False,
    }


def _completed_calls(ledger: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        item
        for item in ledger.get("calls", [])
        if isinstance(item, dict)
        and item.get("model", MINI_MODEL) == MINI_MODEL
        and item.get("task_status") == "succeeded"
        and isinstance(item.get("actual_usage_tokens"), (int, float))
        and float(item.get("duration_seconds") or 0) > 0
    ]


def _coefficient(ledger: dict[str, Any], has_video_input: bool) -> float:
    coefficients = ledger.get("deduction_coefficients")
    if not isinstance(coefficients, dict):
        raise SeedanceSafetyError("Mini ledger deduction_coefficients are missing.")
    key = (
        "with_video_input_480p_720p"
        if has_video_input
        else "without_video_input_480p_720p"
    )
    coefficient = _number(coefficients.get(key), f"deduction_coefficients.{key}")
    if coefficient <= 0:
        raise SeedanceSafetyError(f"deduction_coefficients.{key} must be positive.")
    return coefficient


def _committed_package_tokens(call: dict[str, Any]) -> float:
    actual = call.get("actual_package_deduction")
    if isinstance(actual, (int, float)) and not isinstance(actual, bool):
        return max(0.0, float(actual))
    predicted = call.get("predicted_package_deduction")
    variance = call.get("variance_guard")
    if isinstance(predicted, (int, float)) and not isinstance(predicted, bool):
        return max(0.0, float(predicted)) + (
            max(0.0, float(variance))
            if isinstance(variance, (int, float))
            and not isinstance(variance, bool)
            else 50_000.0
        )
    # A provider task without a recorded forecast is an accounting hole.
    raise SeedanceSafetyError(
        "An existing batch call has no actual or forecast package deduction."
    )


def build_preflight(
    ledger: dict[str, Any],
    contract: dict[str, Any],
    *,
    has_video_input: bool,
    is_new_provider_call: bool,
    dry_run: bool,
    now: datetime | None = None,
) -> dict[str, Any]:
    """Validate and return the receipt that must print before provider access."""

    validate_exact_mini_model(contract.get("model"))
    guard = validate_billing_guard(contract)
    balance = validate_reconciled_mini_ledger(ledger, now=now)

    for item in ledger.get("calls", []):
        if not isinstance(item, dict):
            raise SeedanceSafetyError("ledger.calls must contain objects.")
        if item.get("shot_id") != contract.get("id") and item.get(
            "task_status"
        ) in {"submitted", "processing", "running"}:
            raise SeedanceSafetyError(
                f"Another Seedance task is still active: {item.get('shot_id')}."
            )

    history = _completed_calls(ledger)
    if history:
        rates = [
            float(item["actual_usage_tokens"])
            / float(item["duration_seconds"])
            for item in history
        ]
        token_rate = statistics.median(rates)
    else:
        token_rate = _number(
            ledger.get("expected_tokens_per_second"),
            "expected_tokens_per_second",
        )
    if token_rate <= 0:
        raise SeedanceSafetyError("expected token rate must be positive.")

    duration = _number(contract.get("duration_seconds"), "duration_seconds")
    coefficient = _coefficient(ledger, has_video_input)
    predicted_usage = token_rate * duration
    predicted_deduction = predicted_usage * coefficient
    variance_guard = max(predicted_deduction * 0.15, 50_000.0)
    guarded_current = predicted_deduction + variance_guard

    batch_calls = [
        item
        for item in ledger.get("calls", [])
        if isinstance(item, dict)
        and item.get("batch_id") == guard["batch_id"]
        and item.get("task_id")
    ]
    for item in batch_calls:
        validate_exact_mini_model(item.get("model"))
    existing_call_count = len(batch_calls)
    existing_commitment = sum(
        _committed_package_tokens(item) for item in batch_calls
    )

    if is_new_provider_call:
        planned_call_count = existing_call_count + 1
        planned_commitment = existing_commitment + guarded_current
    else:
        planned_call_count = existing_call_count
        planned_commitment = existing_commitment

    if planned_call_count > guard["max_calls"]:
        raise SeedanceSafetyError(
            "Batch call limit would be exceeded "
            f"({planned_call_count} > {guard['max_calls']})."
        )
    if planned_commitment > guard["max_package_tokens"]:
        raise SeedanceSafetyError(
            "Batch package-token budget would be exceeded "
            f"({planned_commitment:.0f} > "
            f"{guard['max_package_tokens']:.0f})."
        )

    spendable_remaining = min(
        balance["locally_tracked_remaining_package_tokens"],
        balance["provider_console_remaining_package_tokens"],
    ) - MIN_PACKAGE_TOKEN_RESERVE
    if spendable_remaining < 0 or (
        is_new_provider_call and guarded_current > spendable_remaining
    ):
        raise SeedanceSafetyError(
            "The reconciled Mini package balance plus safety reserve would "
            "be exceeded."
        )

    return {
        "action": "seedance_preflight",
        "allowed": True,
        "dry_run": dry_run,
        "model": MINI_MODEL,
        "standard_and_fast_supported": False,
        "shot_id": contract.get("id"),
        "batch_id": guard["batch_id"],
        "is_new_provider_call": is_new_provider_call,
        "planned_calls": planned_call_count,
        "batch_max_calls": guard["max_calls"],
        "predicted_usage_tokens": predicted_usage,
        "deduction_coefficient": coefficient,
        "predicted_package_deduction": predicted_deduction,
        "variance_guard": variance_guard,
        "batch_committed_tokens_after": planned_commitment,
        "batch_max_package_tokens": guard["max_package_tokens"],
        "package_token_reserve": MIN_PACKAGE_TOKEN_RESERVE,
        **balance,
    }
