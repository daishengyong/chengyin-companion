#!/usr/bin/env python3
"""Zero-network checks for the Chengyin Seedance billing guard."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest import mock

from seedance_generation_safety import (
    MINI_MODEL,
    SeedanceSafetyError,
    build_preflight,
)


ROOT = Path(__file__).resolve().parents[1]


def reconciled_ledger() -> dict:
    checked_at = datetime.now(timezone.utc) - timedelta(minutes=5)
    return {
        "schema_version": 2,
        "pool_id": "test-mini-pool",
        "model": MINI_MODEL,
        "pay_as_you_go_spillover_allowed": False,
        "provider_console_reconciled": True,
        "provider_console_reconciled_at": checked_at.isoformat(),
        "provider_console_remaining_package_tokens": 5_000_000,
        "locally_tracked_remaining_package_tokens": 4_500_000,
        "expected_tokens_per_second": 10_000,
        "deduction_coefficients": {
            "with_video_input_480p_720p": 1.0,
            "without_video_input_480p_720p": 1.6429,
        },
        "topups": [
            {
                "package_tokens": 5_000_000,
                "provider_console_reconciled": True,
            }
        ],
        "calls": [],
    }


def mini_contract() -> dict:
    return {
        "id": "TEST-MINI-001",
        "model": MINI_MODEL,
        "resolution": "480p",
        "ratio": "16:9",
        "duration_seconds": 4,
        "generate_audio": True,
        "watermark": False,
        "return_last_frame": True,
        "prompt": "An original fictional adult waves.",
        "billing_guard": {
            "batch_id": "TEST-BATCH-001",
            "max_calls": 3,
            "max_package_tokens": 500_000,
        },
    }


class SeedanceSafetyChecks(unittest.TestCase):
    def test_standard_model_is_rejected_without_override(self) -> None:
        contract = mini_contract()
        contract["model"] = "doubao-seedance-2-0-260128"
        with self.assertRaisesRegex(SeedanceSafetyError, "Mini-only"):
            build_preflight(
                reconciled_ledger(),
                contract,
                has_video_input=True,
                is_new_provider_call=True,
                dry_run=True,
            )

    def test_fast_model_is_rejected_without_override(self) -> None:
        contract = mini_contract()
        contract["model"] = "doubao-seedance-2-0-fast-260128"
        with self.assertRaisesRegex(SeedanceSafetyError, "Mini-only"):
            build_preflight(
                reconciled_ledger(),
                contract,
                has_video_input=True,
                is_new_provider_call=True,
                dry_run=True,
            )

    def test_unreconciled_ledger_is_rejected(self) -> None:
        ledger = reconciled_ledger()
        ledger["provider_console_reconciled"] = False
        with self.assertRaisesRegex(SeedanceSafetyError, "not reconciled"):
            build_preflight(
                ledger,
                mini_contract(),
                has_video_input=True,
                is_new_provider_call=True,
                dry_run=True,
            )

    def test_unreconciled_topup_is_rejected(self) -> None:
        ledger = reconciled_ledger()
        ledger["topups"][0]["provider_console_reconciled"] = False
        with self.assertRaisesRegex(SeedanceSafetyError, "top-up"):
            build_preflight(
                ledger,
                mini_contract(),
                has_video_input=True,
                is_new_provider_call=True,
                dry_run=True,
            )

    def test_batch_call_limit_is_rejected(self) -> None:
        ledger = reconciled_ledger()
        ledger["calls"] = [
            {
                "shot_id": f"OLD-{index}",
                "batch_id": "TEST-BATCH-001",
                "task_id": f"task-{index}",
                "task_status": "succeeded",
                "model": MINI_MODEL,
                "actual_package_deduction": 30_000,
            }
            for index in range(3)
        ]
        with self.assertRaisesRegex(SeedanceSafetyError, "call limit"):
            build_preflight(
                ledger,
                mini_contract(),
                has_video_input=True,
                is_new_provider_call=True,
                dry_run=True,
            )

    def test_batch_token_limit_is_rejected(self) -> None:
        contract = mini_contract()
        contract["billing_guard"]["max_package_tokens"] = 80_000
        with self.assertRaisesRegex(SeedanceSafetyError, "token budget"):
            build_preflight(
                reconciled_ledger(),
                contract,
                has_video_input=True,
                is_new_provider_call=True,
                dry_run=True,
            )

    def test_dry_run_never_reads_credentials_or_imports_sdk(self) -> None:
        script_path = ROOT / "scripts/generate-seedance-task-complete.py"
        spec = importlib.util.spec_from_file_location(
            "generate_seedance_task_complete_test",
            script_path,
        )
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            shot_dir = directory / "shot"
            shot_dir.mkdir()
            (shot_dir / "contract.json").write_text(
                json.dumps(mini_contract()),
                encoding="utf-8",
            )
            ledger_path = directory / "ledger.json"
            ledger_path.write_text(
                json.dumps(reconciled_ledger()),
                encoding="utf-8",
            )

            output = io.StringIO()
            with mock.patch.object(
                module,
                "load_key",
                side_effect=AssertionError("dry-run read a credential"),
            ), contextlib.redirect_stdout(output):
                result = module.main(
                    ["--shot-dir", str(shot_dir), "--dry-run"],
                    ledger_path=ledger_path,
                )

        self.assertEqual(result, 0)
        receipts = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(receipts[0]["model"], MINI_MODEL)
        self.assertEqual(
            receipts[-1],
            {
                "action": "dry_run_complete",
                "provider_contacted": False,
                "credentials_read": False,
                "reference_uploaded": False,
            },
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
