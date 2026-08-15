#!/usr/bin/env python3
"""Generate or resume one governed 480p/720p Seedance Mini companion action.

The script never prints or persists the Ark API key or signed download URLs.
It uses the existing shared package ledger so another video workflow does not
overestimate the remaining package balance.
"""

from __future__ import annotations

import argparse
import base64
import fcntl
import hashlib
import json
import mimetypes
import os
import re
import time
from datetime import datetime
from pathlib import Path
from typing import Any

from seedance_generation_safety import (
    CONFIRMATION_PHRASE,
    MINI_MODEL,
    SeedanceSafetyError,
    build_preflight,
)


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SHOT_DIR = ROOT / "video-production/seedance/task-complete"
KEY_FILES = [
    Path.home() / ".config/chengyin-companion/seedance.env",
    Path.home() / ".config/codex-video-production/seedance.env",
]
MINI_LEDGER_PATH = (
    ROOT / "video-production/seedance/mini-external-call-ledger.json"
)
DEFAULT_TOS_BUCKET = ""
DEFAULT_TOS_ENDPOINT = "tos-cn-beijing.volces.com"
DEFAULT_TOS_REGION = "cn-beijing"


def now_iso() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def load_key() -> tuple[str, str]:
    process_value = os.environ.get("ARK_API_KEY", "").strip()
    if process_value:
        return process_value, "process_env"
    for key_file in KEY_FILES:
        if not key_file.is_file():
            continue
        for raw in key_file.read_text(encoding="utf-8").splitlines():
            match = re.fullmatch(
                r"\s*(?:export\s+)?ARK_API_KEY\s*=\s*(.+?)\s*",
                raw,
            )
            if not match:
                continue
            value = match.group(1).strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
                value = value[1:-1]
            if value:
                return value, "approved_env_file"
    raise RuntimeError("The approved local key file has no ARK_API_KEY.")


def to_data_url(path: Path) -> str:
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{mime};base64,{encoded}"


def prepare_reference_media_url(
    path: Path,
    *,
    media_kind: str,
) -> tuple[str, dict[str, str]]:
    import tos

    access_key = os.environ.get("VOLCENGINE_ACCOUNT_ACCESS_KEY_ID", "").strip()
    secret_key = os.environ.get(
        "VOLCENGINE_ACCOUNT_SECRET_ACCESS_KEY",
        "",
    ).strip()
    if not access_key or not secret_key:
        raise RuntimeError(
            "Video/audio references require the approved Volcengine account credentials."
        )
    bucket = os.environ.get("CHENGYIN_TOS_BUCKET", DEFAULT_TOS_BUCKET).strip()
    if not bucket:
        raise RuntimeError(
            "Reference video/audio input requires CHENGYIN_TOS_BUCKET for "
            "the producer's own private bucket."
        )
    endpoint = os.environ.get(
        "CHENGYIN_TOS_ENDPOINT",
        DEFAULT_TOS_ENDPOINT,
    ).strip()
    region = os.environ.get("CHENGYIN_TOS_REGION", DEFAULT_TOS_REGION).strip()
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    object_key = f"seedance-inputs/{media_kind}/{digest[:20]}-{path.name}"
    tos_client = tos.TosClientV2(
        access_key,
        secret_key,
        endpoint,
        region,
    )
    try:
        tos_client.head_object(bucket, object_key)
        upload_status = "reused"
    except tos.exceptions.TosServerError as error:
        if error.status_code != 404:
            raise
        tos_client.put_object_from_file(
            bucket,
            object_key,
            str(path),
            content_type=mimetypes.guess_type(path.name)[0]
            or ("audio/wav" if media_kind == "audio" else "video/mp4"),
            acl=tos.ACLType.ACL_Private,
            forbid_overwrite=True,
        )
        upload_status = "uploaded"
    signed = tos_client.pre_signed_url(
        tos.HttpMethodType.Http_Method_Get,
        bucket,
        object_key,
        expires=3600,
    )
    return signed.signed_url, {
        "bucket": bucket,
        "object_key": object_key,
        "upload_status": upload_status,
        "signed_url_persisted": False,
    }


def safe_task(task: Any) -> dict[str, Any]:
    content = getattr(task, "content", None)
    usage = getattr(task, "usage", None)
    error = getattr(task, "error", None)
    return {
        "id": getattr(task, "id", None),
        "model": getattr(task, "model", None),
        "status": getattr(task, "status", None),
        "error": (
            {
                "code": getattr(error, "code", None),
                "message": getattr(error, "message", None),
            }
            if error
            else None
        ),
        "has_video_url": bool(getattr(content, "video_url", None))
        if content
        else False,
        "has_last_frame_url": bool(getattr(content, "last_frame_url", None))
        if content
        else False,
        "usage": (
            {
                "completion_tokens": getattr(usage, "completion_tokens", None),
                "total_tokens": getattr(usage, "total_tokens", None),
            }
            if usage
            else None
        ),
        "duration": getattr(task, "duration", None),
        "ratio": getattr(task, "ratio", None),
        "resolution": getattr(task, "resolution", None),
        "seed": getattr(task, "seed", None),
        "created_at": getattr(task, "created_at", None),
        "updated_at": getattr(task, "updated_at", None),
        "signed_urls_persisted": False,
        "secrets_persisted": False,
    }


def upsert_call(
    ledger: dict[str, Any],
    shot_id: str,
    values: dict[str, Any],
) -> None:
    for item in ledger.setdefault("calls", []):
        if item.get("shot_id") == shot_id:
            item.update(values)
            return
    ledger["calls"].append({"shot_id": shot_id, **values})


def main(
    argv: list[str] | None = None,
    *,
    ledger_path: Path = MINI_LEDGER_PATH,
) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--shot-dir",
        type=Path,
        default=DEFAULT_SHOT_DIR,
        help="Directory containing contract.json and its reference image.",
    )
    parser.add_argument("--poll-seconds", type=int, default=12)
    parser.add_argument("--deadline-seconds", type=int, default=1200)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help=(
            "Validate the exact Mini model, reconciliation and budgets; "
            "never read credentials or contact Volcengine."
        ),
    )
    parser.add_argument(
        "--confirm-submit",
        default="",
        metavar="PHRASE",
        help=(
            "Second confirmation for a new provider task. Exact required "
            f"phrase: {CONFIRMATION_PHRASE!r}"
        ),
    )
    args = parser.parse_args(argv)

    shot_dir = args.shot_dir.expanduser().resolve()
    contract_path = shot_dir / "contract.json"
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    prompt_text = contract.get("prompt")
    if contract.get("prompt_file"):
        prompt_path = (shot_dir / contract["prompt_file"]).resolve()
        if not prompt_path.is_file():
            raise RuntimeError(f"Prompt file is missing: {prompt_path}")
        prompt_text = prompt_path.read_text(encoding="utf-8")
        expected_prompt_hash = contract.get("prompt_sha256")
        actual_prompt_hash = hashlib.sha256(prompt_text.encode("utf-8")).hexdigest()
        if expected_prompt_hash and actual_prompt_hash != expected_prompt_hash:
            raise RuntimeError(
                "Prompt file hash does not match the governed submission contract."
            )
    if not isinstance(prompt_text, str) or not prompt_text.strip():
        raise RuntimeError("A non-empty prompt or prompt_file is required.")
    if contract.get("model") != MINI_MODEL:
        raise SeedanceSafetyError(
            "This project only supports the exact Mini model "
            f"{MINI_MODEL!r}. Standard/Fast calls are always rejected."
        )
    if contract.get("resolution") not in {"480p", "720p"}:
        raise RuntimeError("Only the governed 480p and 720p profiles are allowed.")
    if contract.get("ratio") not in {"9:16", "16:9", "1:1"}:
        raise RuntimeError("Unsupported governed aspect ratio.")
    if not 4 <= int(contract.get("duration_seconds", 0)) <= 15:
        raise RuntimeError("Duration must remain between 4 and 15 seconds.")
    if not isinstance(contract.get("generate_audio"), bool):
        raise RuntimeError("generate_audio must be a boolean.")
    for key, value in {
        "watermark": False,
        "return_last_frame": True,
    }.items():
        if contract.get(key) != value:
            raise RuntimeError(f"Locked contract field changed: {key}.")

    reference_images: list[tuple[Path, str]] = []
    if contract.get("reference_image"):
        reference_images.append(
            (shot_dir / contract["reference_image"], "reference_image")
        )
    for item in contract.get("reference_images", []):
        reference_images.append(
            (shot_dir / item["path"], item.get("role", "reference_image"))
        )
    reference_videos = [
        (shot_dir / item["path"], item.get("role", "reference_video"))
        for item in contract.get("reference_videos", [])
    ]
    reference_audios = [
        (shot_dir / item["path"], item.get("role", "reference_audio"))
        for item in contract.get("reference_audios", [])
    ]
    for path, _ in [*reference_images, *reference_videos, *reference_audios]:
        if not path.is_file():
            raise RuntimeError(f"Reference asset is missing: {path}")

    has_video_input = bool(reference_videos)
    ledger_lock_path = ledger_path.with_suffix(ledger_path.suffix + ".lock")
    ledger_lock_path.parent.mkdir(parents=True, exist_ok=True)
    # Hold one cross-process lock for the entire provider task. A short
    # read/check/write lock is not enough: another queued process could submit
    # after the guard but before this task records its own active state, and two
    # stale in-memory ledgers could then overwrite each other.
    ledger_lock_handle = ledger_lock_path.open("a+", encoding="utf-8")
    fcntl.flock(ledger_lock_handle.fileno(), fcntl.LOCK_EX)
    ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
    shot_id = contract["id"]
    existing = next(
        (
            item
            for item in ledger.get("calls", [])
            if item.get("shot_id") == shot_id
        ),
        None,
    )
    output_stem = contract.get("output_stem") or shot_id.lower()
    task_id_path = shot_dir / "task-id.txt"
    raw_path = shot_dir / f"{output_stem}-raw-{contract['resolution']}.mp4"
    last_frame_path = shot_dir / f"{output_stem}-last-frame.png"

    is_new_provider_call = not task_id_path.is_file()
    preflight = build_preflight(
        ledger,
        contract,
        has_video_input=has_video_input,
        is_new_provider_call=is_new_provider_call,
        dry_run=args.dry_run,
    )
    print(json.dumps(preflight, ensure_ascii=False), flush=True)
    if args.dry_run:
        print(
            json.dumps(
                {
                    "action": "dry_run_complete",
                    "provider_contacted": False,
                    "credentials_read": False,
                    "reference_uploaded": False,
                }
            ),
            flush=True,
        )
        fcntl.flock(ledger_lock_handle.fileno(), fcntl.LOCK_UN)
        ledger_lock_handle.close()
        return 0

    if (
        is_new_provider_call
        and args.confirm_submit != CONFIRMATION_PHRASE
    ):
        raise SeedanceSafetyError(
            "New provider submission blocked. Run --dry-run first, then pass "
            f"--confirm-submit {CONFIRMATION_PHRASE!r} exactly."
        )

    # SDKs, credentials and provider clients are intentionally initialized only
    # after the complete preflight receipt is printed and the second
    # confirmation passes.
    from volcenginesdkarkruntime import Ark

    api_key, key_source = load_key()
    client = Ark(
        api_key=api_key,
        base_url=os.environ.get(
            "ARK_BASE_URL",
            "https://ark.cn-beijing.volces.com/api/v3",
        ),
        timeout=180,
    )

    if task_id_path.is_file():
        task_id = task_id_path.read_text(encoding="utf-8").strip()
        if not task_id:
            raise RuntimeError("Existing task-id file is empty.")
        print(json.dumps({"action": "resume", "task_id": task_id}), flush=True)
    else:
        if existing and existing.get("task_id"):
            raise RuntimeError("Shared ledger has a task ID but the local ID is missing.")
        forecast = {
            "predicted_usage_tokens": preflight["predicted_usage_tokens"],
            "predicted_package_deduction": preflight[
                "predicted_package_deduction"
            ],
            "variance_guard": preflight["variance_guard"],
        }
        content: list[dict[str, Any]] = [
            {"type": "text", "text": prompt_text}
        ]
        for path, role in reference_images:
            content.append(
                {
                    "type": "image_url",
                    "image_url": {"url": to_data_url(path)},
                    "role": role,
                }
            )
        reference_video_objects: list[dict[str, str]] = []
        for path, role in reference_videos:
            video_url, storage_receipt = prepare_reference_media_url(
                path,
                media_kind="video",
            )
            reference_video_objects.append(storage_receipt)
            content.append(
                {
                    "type": "video_url",
                    "video_url": {"url": video_url},
                    "role": role,
                }
            )
        reference_audio_objects: list[dict[str, str]] = []
        for path, role in reference_audios:
            audio_url, storage_receipt = prepare_reference_media_url(
                path,
                media_kind="audio",
            )
            reference_audio_objects.append(storage_receipt)
            content.append(
                {
                    "type": "audio_url",
                    "audio_url": {"url": audio_url},
                    "role": role,
                }
            )
        task = client.content_generation.tasks.create(
            model=contract["model"],
            content=content,
            safety_identifier=contract.get(
                "safety_identifier",
                re.sub(r"[^a-z0-9_]", "_", shot_id.lower()),
            ),
            return_last_frame=contract["return_last_frame"],
            generate_audio=contract["generate_audio"],
            watermark=contract["watermark"],
            resolution=contract["resolution"],
            ratio=contract["ratio"],
            duration=contract["duration_seconds"],
            timeout=180,
        )
        task_id = task.id
        task_id_path.write_text(task_id + "\n", encoding="utf-8")
        upsert_call(
            ledger,
            shot_id,
            {
                "consumer_project": contract.get(
                    "consumer_project",
                    "chengyin-companion",
                ),
                "task_id": task_id,
                "submitted_at": now_iso(),
                "task_status": "submitted",
                "model": contract["model"],
                "batch_id": preflight["batch_id"],
                "batch_max_calls": preflight["batch_max_calls"],
                "batch_max_package_tokens": preflight[
                    "batch_max_package_tokens"
                ],
                "resolution": contract["resolution"],
                "ratio": contract["ratio"],
                "duration_seconds": contract["duration_seconds"],
                "generate_audio": contract["generate_audio"],
                "watermark": contract["watermark"],
                "credential_source": key_source,
                "prompt_sha256": hashlib.sha256(
                    prompt_text.encode("utf-8")
                ).hexdigest(),
                "input_mode": (
                    "with_video_input"
                    if has_video_input
                    else "without_video_input"
                ),
                "deduction_coefficient": preflight[
                    "deduction_coefficient"
                ],
                "intended_balance_source": preflight[
                    "intended_balance_source"
                ],
                "billing_source_verified_by_generation_api": False,
                "provider_console_reconciled_at": preflight[
                    "provider_console_reconciled_at"
                ],
                "reference_video_objects": reference_video_objects,
                "reference_audio_objects": reference_audio_objects,
                **forecast,
                "quality_reviewed": False,
                "acceptance_status": "pending",
                "secrets_persisted": False,
            },
        )
        write_json(ledger_path, ledger)
        print(json.dumps({"action": "submitted", "task_id": task_id}), flush=True)

    deadline = time.time() + args.deadline_seconds
    task = None
    while time.time() < deadline:
        task = client.content_generation.tasks.get(task_id=task_id, timeout=120)
        status = getattr(task, "status", None)
        upsert_call(
            ledger,
            shot_id,
            {"task_status": status, "last_polled_at": now_iso()},
        )
        write_json(ledger_path, ledger)
        print(json.dumps({"task_id": task_id, "status": status}), flush=True)
        if status in {"succeeded", "failed", "cancelled", "canceled"}:
            break
        time.sleep(max(5, args.poll_seconds))
    if task is None:
        raise RuntimeError("The Seedance task was not retrieved.")

    safe = safe_task(task)
    write_json(shot_dir / "task-result-redacted.json", safe)
    if safe["status"] != "succeeded":
        upsert_call(
            ledger,
            shot_id,
            {
                "task_status": safe["status"],
                "completed_at": now_iso(),
                "error": safe["error"],
                "acceptance_status": "rejected_generation_failure",
            },
        )
        write_json(ledger_path, ledger)
        raise RuntimeError(
            f"Seedance task ended with {safe['status']}: {safe['error']}"
        )

    if not raw_path.is_file():
        import httpx

        video_url = getattr(task.content, "video_url", None)
        if not video_url:
            raise RuntimeError("Succeeded task returned no video URL.")
        with httpx.stream(
            "GET",
            video_url,
            follow_redirects=True,
            timeout=180,
        ) as response:
            response.raise_for_status()
            with raw_path.open("wb") as handle:
                for chunk in response.iter_bytes():
                    handle.write(chunk)
    last_frame_url = getattr(task.content, "last_frame_url", None)
    if last_frame_url and not last_frame_path.is_file():
        import httpx

        response = httpx.get(
            last_frame_url,
            follow_redirects=True,
            timeout=120,
        )
        response.raise_for_status()
        last_frame_path.write_bytes(response.content)

    usage = safe.get("usage") or {}
    actual_usage = usage.get("total_tokens") or usage.get("completion_tokens")
    if not isinstance(actual_usage, (int, float)):
        raise RuntimeError("Succeeded task returned no numeric usage.")

    already_deducted = bool(
        existing
        and existing.get("task_status") == "succeeded"
        and isinstance(existing.get("actual_package_deduction"), (int, float))
    )
    actual_deduction = (
        float(actual_usage) * preflight["deduction_coefficient"]
    )
    if not already_deducted:
        remaining = float(ledger["locally_tracked_remaining_package_tokens"])
        ledger["locally_tracked_remaining_package_tokens"] = (
            remaining - actual_deduction
        )
    upsert_call(
        ledger,
        shot_id,
        {
            "task_status": "succeeded",
            "completed_at": now_iso(),
            "actual_usage_tokens": actual_usage,
            "actual_package_deduction": actual_deduction,
            "remaining_package_tokens_after": ledger[
                "locally_tracked_remaining_package_tokens"
            ],
            "video_path": str(raw_path),
            "last_frame_path": str(last_frame_path)
            if last_frame_path.is_file()
            else None,
            "quality_reviewed": False,
            "acceptance_status": "pending_visual_review",
        },
    )
    write_json(ledger_path, ledger)
    print(
        json.dumps(
            {
                "status": "succeeded_pending_visual_review",
                "actual_usage_tokens": actual_usage,
                "actual_package_deduction": actual_deduction,
                "remaining_package_tokens_after": ledger[
                    "locally_tracked_remaining_package_tokens"
                ],
                "video_path": str(raw_path),
            }
        ),
        flush=True,
    )
    fcntl.flock(ledger_lock_handle.fileno(), fcntl.LOCK_UN)
    ledger_lock_handle.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
