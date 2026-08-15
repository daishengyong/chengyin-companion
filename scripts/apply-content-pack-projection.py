#!/usr/bin/env python3
"""Transactionally apply an offline projection-authoring receipt to one pack."""

from __future__ import annotations

import argparse
import json
import math
import os
import pathlib
import plistlib
import re
import subprocess
import sys
import tempfile
import time
import uuid
from dataclasses import dataclass, field
from typing import Any, NoReturn


ROOT = pathlib.Path(__file__).resolve().parent.parent
VALIDATOR = ROOT / "scripts/validate-content-pack.sh"
INFO_PLIST = ROOT / "Info.plist"
SCHEMA_VERSION = "chengyin.projection-authoring-receipt/v1"
ALLOWED_MODES = {"pet", "stage", "fullscreen"}
IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$")
RECEIPT_FIELDS = {
    "schemaVersion",
    "packID",
    "assetID",
    "generatedForAppVersion",
    "focalTracks",
    "safeAreas",
}
KEYFRAME_FIELDS = {"timeMs", "x", "y", "scale"}
SAFE_AREA_FIELDS = {"x", "y", "width", "height"}
MAX_RECEIPT_BYTES = 256 * 1024
MAX_MANIFEST_BYTES = 1024 * 1024


RECOVERY = {
    "PROJECTION_RECEIPT_INVALID_ARGUMENT":
        "Pass one regular pack directory and one regular receipt JSON file, then retry.",
    "PROJECTION_RECEIPT_UNSAFE_INPUT":
        "Replace symbolic links, hard links or oversized inputs with regular local files, then retry.",
    "PROJECTION_RECEIPT_INVALID_JSON":
        "Export the receipt again from the offline projection editor, then retry.",
    "PROJECTION_RECEIPT_UNSUPPORTED_SCHEMA":
        "Regenerate the receipt with the current projection editor instead of editing its schema version.",
    "PROJECTION_RECEIPT_UNKNOWN_FIELD":
        "Remove unknown receipt fields or regenerate it with the current editor, then retry.",
    "PROJECTION_RECEIPT_PACK_MISMATCH":
        "Open the target pack in the editor and export a receipt for the exact pack and video asset.",
    "PROJECTION_RECEIPT_INVALID_TRACK":
        "Keep 2 to 32 ordered keyframes starting at 0 ms and within the declared media duration.",
    "PROJECTION_RECEIPT_INVALID_SAFE_AREA":
        "Keep the normalized safe area inside the source frame and visible through every keyframe.",
    "PROJECTION_RECEIPT_SOURCE_PACK_INVALID":
        "Run scripts/validate-content-pack.sh on the unchanged pack, repair it, then apply the receipt again.",
    "PROJECTION_RECEIPT_VALIDATION_FAILED":
        "The original manifest was restored. Reopen the pack in the editor, correct the receipt, and retry.",
    "PROJECTION_RECEIPT_ROLLBACK_FAILED":
        "Do not continue editing. Restore manifest.json from the sibling projection-backups directory and validate the pack.",
    "PROJECTION_RECEIPT_UNEXPECTED_ERROR":
        "Run scripts/doctor.sh, keep the original pack and exported receipt, then retry with the safe error code.",
}


@dataclass
class ReceiptFailure(Exception):
    code: str
    message: str
    details: dict[str, Any] = field(default_factory=dict)


class SafeArgumentParser(argparse.ArgumentParser):
    def error(self, message: str) -> NoReturn:
        fail(
            "PROJECTION_RECEIPT_INVALID_ARGUMENT",
            "The projection apply command arguments are invalid.",
        )


def fail(code: str, message: str, **details: Any) -> NoReturn:
    raise ReceiptFailure(code, message, details)


def response_for(error: ReceiptFailure) -> dict[str, Any]:
    return {
        "status": "FAIL",
        "code": error.code,
        "message": error.message,
        "recoveryAction": RECOVERY.get(
            error.code, RECOVERY["PROJECTION_RECEIPT_UNEXPECTED_ERROR"]
        ),
        **error.details,
    }


def emit(payload: dict[str, Any], as_json: bool) -> None:
    if as_json:
        print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
        return
    if payload["status"] == "PASS":
        print(f"PASS  {payload['packID']} · {payload['assetID']} · {payload['operation']}")
        print(f"BACKUP  {payload['backupReference']}")
    else:
        print(f"FAIL  [{payload['code']}] {payload['message']}", file=sys.stderr)
        print(f"ACTION  {payload['recoveryAction']}", file=sys.stderr)


def regular_bytes(path: pathlib.Path, maximum: int, label: str) -> bytes:
    try:
        status = path.lstat()
    except OSError:
        fail("PROJECTION_RECEIPT_INVALID_ARGUMENT", f"The {label} is unavailable.")
    if path.is_symlink() or not path.is_file() or status.st_nlink != 1:
        fail("PROJECTION_RECEIPT_UNSAFE_INPUT", f"The {label} is not a regular single-link file.")
    if status.st_size <= 0 or status.st_size > maximum:
        fail("PROJECTION_RECEIPT_UNSAFE_INPUT", f"The {label} size is outside the documented limit.")
    try:
        return path.read_bytes()
    except OSError:
        fail("PROJECTION_RECEIPT_UNSAFE_INPUT", f"The {label} could not be read safely.")


def load_json(path: pathlib.Path, maximum: int, label: str) -> tuple[dict[str, Any], bytes]:
    raw = regular_bytes(path, maximum, label)
    try:
        value = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError):
        fail("PROJECTION_RECEIPT_INVALID_JSON", f"The {label} is not valid UTF-8 JSON.")
    if not isinstance(value, dict):
        fail("PROJECTION_RECEIPT_INVALID_JSON", f"The {label} root must be an object.")
    return value, raw


def exact_fields(value: dict[str, Any], allowed: set[str], location: str) -> None:
    unknown = sorted(set(value) - allowed)
    missing = sorted(allowed - set(value))
    if unknown or missing:
        fail(
            "PROJECTION_RECEIPT_UNKNOWN_FIELD",
            f"The {location} fields do not match the versioned contract.",
        )


def number(value: Any) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    numeric = float(value)
    return numeric if math.isfinite(numeric) else None


def visible(area: dict[str, float], frame: dict[str, Any]) -> bool:
    extent = 1 / float(frame["scale"])
    maximum_origin = 1 - extent
    visible_x = min(max(float(frame["x"]) - extent / 2, 0), maximum_origin)
    visible_y = min(max(float(frame["y"]) - extent / 2, 0), maximum_origin)
    epsilon = 0.000001
    return (
        area["x"] + epsilon >= visible_x
        and area["y"] + epsilon >= visible_y
        and area["x"] + area["width"] <= visible_x + extent + epsilon
        and area["y"] + area["height"] <= visible_y + extent + epsilon
    )


def validate_receipt(
    receipt: dict[str, Any], manifest: dict[str, Any]
) -> tuple[str, str, dict[str, list[dict[str, Any]]], dict[str, dict[str, float]]]:
    exact_fields(receipt, RECEIPT_FIELDS, "receipt")
    if receipt["schemaVersion"] != SCHEMA_VERSION:
        fail("PROJECTION_RECEIPT_UNSUPPORTED_SCHEMA", "The receipt schema is unsupported.")
    pack_id, asset_id = receipt["packID"], receipt["assetID"]
    if not isinstance(pack_id, str) or not IDENTIFIER.fullmatch(pack_id):
        fail("PROJECTION_RECEIPT_INVALID_JSON", "The receipt pack identity is invalid.")
    if not isinstance(asset_id, str) or not IDENTIFIER.fullmatch(asset_id):
        fail("PROJECTION_RECEIPT_INVALID_JSON", "The receipt asset identity is invalid.")
    if manifest.get("schemaVersion") != 2:
        fail("PROJECTION_RECEIPT_PACK_MISMATCH", "Projection receipts require a schema-v2 pack.")
    if manifest.get("id") != pack_id:
        fail("PROJECTION_RECEIPT_PACK_MISMATCH", "The receipt belongs to a different pack.")
    assets = [asset for asset in manifest.get("assets", []) if isinstance(asset, dict)]
    matches = [asset for asset in assets if asset.get("id") == asset_id]
    if len(matches) != 1 or matches[0].get("kind") != "video":
        fail("PROJECTION_RECEIPT_PACK_MISMATCH", "The receipt video asset does not match the pack.")
    asset = matches[0]
    duration_ms = asset.get("durationMs")
    if isinstance(duration_ms, bool) or not isinstance(duration_ms, int) or duration_ms < 1:
        fail("PROJECTION_RECEIPT_PACK_MISMATCH", "The target video has no bounded duration metadata.")

    tracks = receipt["focalTracks"]
    safe_areas = receipt["safeAreas"]
    if not isinstance(tracks, dict) or not 1 <= len(tracks) <= 3:
        fail("PROJECTION_RECEIPT_INVALID_TRACK", "The receipt needs one to three focal tracks.")
    if not isinstance(safe_areas, dict) or len(safe_areas) > 3:
        fail("PROJECTION_RECEIPT_INVALID_SAFE_AREA", "The receipt safe-area map is invalid.")
    if not set(tracks).issubset(ALLOWED_MODES) or not set(safe_areas).issubset(ALLOWED_MODES):
        fail("PROJECTION_RECEIPT_UNKNOWN_FIELD", "The receipt contains an unsupported projection mode.")

    normalized_tracks: dict[str, list[dict[str, Any]]] = {}
    for mode, frames in tracks.items():
        if not isinstance(frames, list) or not 2 <= len(frames) <= 32:
            fail("PROJECTION_RECEIPT_INVALID_TRACK", f"The {mode} focal track length is invalid.")
        previous = -1
        normalized: list[dict[str, Any]] = []
        for index, frame in enumerate(frames):
            if not isinstance(frame, dict):
                fail("PROJECTION_RECEIPT_INVALID_TRACK", f"The {mode} focal track is malformed.")
            exact_fields(frame, KEYFRAME_FIELDS, f"{mode} keyframe")
            time_ms = frame["timeMs"]
            x, y, scale = number(frame["x"]), number(frame["y"]), number(frame["scale"])
            if (
                isinstance(time_ms, bool)
                or not isinstance(time_ms, int)
                or time_ms <= previous
                or time_ms > duration_ms
                or (index == 0 and time_ms != 0)
                or x is None or not 0 <= x <= 1
                or y is None or not 0 <= y <= 1
                or scale is None or not 1 <= scale <= 8
            ):
                fail("PROJECTION_RECEIPT_INVALID_TRACK", f"The {mode} focal track is outside its bounds.")
            previous = time_ms
            normalized.append({"timeMs": time_ms, "x": x, "y": y, "scale": scale})
        normalized_tracks[mode] = normalized

    normalized_areas: dict[str, dict[str, float]] = {}
    for mode, area in safe_areas.items():
        if mode not in normalized_tracks or not isinstance(area, dict):
            fail("PROJECTION_RECEIPT_INVALID_SAFE_AREA", f"The {mode} safe area has no matching track.")
        exact_fields(area, SAFE_AREA_FIELDS, f"{mode} safe area")
        values = {key: number(area[key]) for key in SAFE_AREA_FIELDS}
        if any(value is None for value in values.values()):
            fail("PROJECTION_RECEIPT_INVALID_SAFE_AREA", f"The {mode} safe area is not finite.")
        normalized_area = {key: float(values[key]) for key in SAFE_AREA_FIELDS}  # type: ignore[arg-type]
        if (
            normalized_area["x"] < 0
            or normalized_area["y"] < 0
            or normalized_area["width"] <= 0
            or normalized_area["height"] <= 0
            or normalized_area["x"] + normalized_area["width"] > 1
            or normalized_area["y"] + normalized_area["height"] > 1
            or not all(visible(normalized_area, frame) for frame in normalized_tracks[mode])
        ):
            fail("PROJECTION_RECEIPT_INVALID_SAFE_AREA", f"The {mode} safe area leaves the visible crop.")
        normalized_areas[mode] = normalized_area
    return pack_id, asset_id, normalized_tracks, normalized_areas


def current_app_version() -> str:
    try:
        with INFO_PLIST.open("rb") as stream:
            value = plistlib.load(stream)["CFBundleShortVersionString"]
        return str(value)
    except (OSError, KeyError, plistlib.InvalidFileException):
        return "0.0.0"


def validator_passes(pack: pathlib.Path) -> bool:
    environment = os.environ.copy()
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    result = subprocess.run(
        [str(VALIDATOR), str(pack), "--json", "--app-version", current_app_version()],
        cwd=ROOT,
        env=environment,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def atomic_write(path: pathlib.Path, payload: bytes) -> None:
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=".manifest.json.chengyin-", dir=path.parent
    )
    temporary = pathlib.Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


def create_backup(pack: pathlib.Path, original: bytes) -> tuple[pathlib.Path, str]:
    backup_root = pack.parent / f".{pack.name}.chengyin-projection-backups"
    if backup_root.exists() and (backup_root.is_symlink() or not backup_root.is_dir()):
        fail("PROJECTION_RECEIPT_UNSAFE_INPUT", "The sibling projection-backups location is unsafe.")
    backup_root.mkdir(mode=0o700, exist_ok=True)
    os.chmod(backup_root, 0o700)
    reference = f"manifest-{time.strftime('%Y%m%d-%H%M%S')}-{uuid.uuid4().hex[:8]}.json"
    backup = backup_root / reference
    descriptor = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "wb") as stream:
        stream.write(original)
        stream.flush()
        os.fsync(stream.fileno())
    return backup, f"{backup_root.name}/{reference}"


def main() -> int:
    as_json = "--json" in sys.argv[1:]
    try:
        parser = SafeArgumentParser(add_help=True)
        parser.add_argument("pack_directory")
        parser.add_argument("receipt_json")
        parser.add_argument("--check", action="store_true")
        parser.add_argument("--json", action="store_true")
        args = parser.parse_args()
        pack = pathlib.Path(args.pack_directory)
        if pack.is_symlink() or not pack.is_dir():
            fail("PROJECTION_RECEIPT_INVALID_ARGUMENT", "The pack directory is unavailable or unsafe.")
        manifest_path = pack / "manifest.json"
        manifest, original = load_json(manifest_path, MAX_MANIFEST_BYTES, "pack manifest")
        receipt, _ = load_json(
            pathlib.Path(args.receipt_json), MAX_RECEIPT_BYTES, "projection receipt"
        )
        pack_id, asset_id, tracks, areas = validate_receipt(receipt, manifest)
        if not validator_passes(pack):
            fail("PROJECTION_RECEIPT_SOURCE_PACK_INVALID", "The source pack did not pass validation; it was not changed.")
        if args.check:
            emit(
                {
                    "status": "PASS",
                    "operation": "CHECKED",
                    "packID": pack_id,
                    "assetID": asset_id,
                    "backupReference": "not-created",
                    "recoveryAction": "Run the same command without --check to apply transactionally.",
                },
                as_json,
            )
            return 0

        updated = json.loads(json.dumps(manifest))
        target = next(asset for asset in updated["assets"] if asset.get("id") == asset_id)
        target["focalTracks"] = tracks
        if areas:
            target["safeAreas"] = areas
        else:
            target.pop("safeAreas", None)
        payload = (json.dumps(updated, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")
        backup, backup_reference = create_backup(pack, original)
        atomic_write(manifest_path, payload)
        if not validator_passes(pack):
            try:
                atomic_write(manifest_path, backup.read_bytes())
            except OSError:
                fail(
                    "PROJECTION_RECEIPT_ROLLBACK_FAILED",
                    "Post-apply validation failed and the original manifest could not be restored automatically.",
                    rolledBack=False,
                    backupReference=backup_reference,
                )
            fail(
                "PROJECTION_RECEIPT_VALIDATION_FAILED",
                "Post-apply validation failed and the original manifest was restored.",
                rolledBack=True,
                backupReference=backup_reference,
            )
        emit(
            {
                "status": "PASS",
                "operation": "APPLIED",
                "packID": pack_id,
                "assetID": asset_id,
                "backupReference": backup_reference,
                "recoveryAction": "Keep the backup until strict audit and playback review pass.",
            },
            as_json,
        )
        return 0
    except ReceiptFailure as error:
        emit(response_for(error), as_json)
        return 1
    except Exception:
        emit(
            response_for(
                ReceiptFailure(
                    "PROJECTION_RECEIPT_UNEXPECTED_ERROR",
                    "The projection receipt could not be applied safely.",
                )
            ),
            as_json,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
