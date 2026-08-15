#!/usr/bin/env python3
"""Safely create or replace one declarative Content Pack v2 experience."""

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
RECEIPT_SCHEMA = "chengyin.experience-authoring-receipt/v1"
MAX_MANIFEST_BYTES = 1024 * 1024
MAX_EXPERIENCES = 64
MAX_STEPS = 8
MAX_TRIGGERS = 16
MAX_LOCALES = 32

IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$")
LOCALE = re.compile(r"^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$")
SCOPED_TRIGGER = re.compile(
    r"^(?:gameWon:|manual:)[A-Za-z0-9][A-Za-z0-9._-]{0,79}$"
)
STATIC_TRIGGERS = {
    "idle", "singleTap", "doubleTap", "longPressRelease", "drag", "fling",
    "taskStarted", "taskLongRunning", "taskCompleted", "taskFailed",
    "taskCancelled", "responseReady", "morning", "evening", "hydration", "stretch",
}
KINDS = {"reaction", "ritual", "sceneStory", "microGameReward"}
ROLES = {"enter", "notice", "react", "settle", "exit"}
TRANSITIONS = {"cut", "crossfade"}
RETURN_POLICIES = {"previousMode", "keepCurrentMode", "remainExpanded"}


RECOVERY = {
    "EXPERIENCE_AUTHOR_INVALID_ARGUMENT":
        "Run scripts/author-content-pack-experience.sh --help, correct the bounded arguments, then retry.",
    "EXPERIENCE_AUTHOR_UNSAFE_INPUT":
        "Use a regular local pack directory with one regular single-link manifest.json, then retry.",
    "EXPERIENCE_AUTHOR_INVALID_JSON":
        "Repair manifest.json as UTF-8 JSON with an object root, then validate the unchanged pack.",
    "EXPERIENCE_AUTHOR_UNSUPPORTED_SCHEMA":
        "Migrate the pack to schemaVersion 2 before authoring an experience.",
    "EXPERIENCE_AUTHOR_SOURCE_PACK_INVALID":
        "Run scripts/validate-content-pack.sh on the unchanged pack, repair it, then retry.",
    "EXPERIENCE_AUTHOR_INVALID_IDENTIFIER":
        "Use a bounded ASCII experience or asset ID made from letters, numbers, dots, underscores and hyphens.",
    "EXPERIENCE_AUTHOR_INVALID_KIND":
        "Choose reaction, ritual, sceneStory or microGameReward.",
    "EXPERIENCE_AUTHOR_INVALID_TRIGGER":
        "Use a documented built-in trigger or a bounded gameWon:/manual: trigger.",
    "EXPERIENCE_AUTHOR_INVALID_STEP":
        "Use 1 to 8 ordered assetID:role[:minimumPlaybackMs[:transition]] steps with documented values.",
    "EXPERIENCE_AUTHOR_INVALID_LOCALE":
        "Use a valid declared locale tag and remove duplicate locale arguments.",
    "EXPERIENCE_AUTHOR_INVALID_POLICY":
        "Choose previousMode, keepCurrentMode or remainExpanded.",
    "EXPERIENCE_AUTHOR_INVALID_COOLDOWN":
        "Use an integer cooldown from 0 through 604800 seconds.",
    "EXPERIENCE_AUTHOR_INVALID_WEIGHT":
        "Use a finite experience weight from 0.01 through 100.",
    "EXPERIENCE_AUTHOR_ASSET_NOT_FOUND":
        "Declare every referenced asset in the same immutable pack version, then retry.",
    "EXPERIENCE_AUTHOR_ASSET_NOT_VIDEO":
        "Reference only declared video assets from experience steps.",
    "EXPERIENCE_AUTHOR_DUPLICATE_ID":
        "Choose a new experience ID or pass --replace to explicitly replace the existing definition.",
    "EXPERIENCE_AUTHOR_LIMIT_EXCEEDED":
        "Keep the pack at 64 experiences or fewer and each experience at 8 steps or fewer.",
    "EXPERIENCE_AUTHOR_VALIDATION_FAILED":
        "The original manifest was restored. Correct the requested experience or pack declaration, then retry.",
    "EXPERIENCE_AUTHOR_ROLLBACK_FAILED":
        "Stop editing and restore manifest.json from the sibling experience-backups directory before validating again.",
    "EXPERIENCE_AUTHOR_UNEXPECTED_ERROR":
        "Keep the original pack, run scripts/doctor.sh, then retry using the safe error code.",
}


@dataclass
class AuthorFailure(Exception):
    code: str
    message: str
    details: dict[str, Any] = field(default_factory=dict)


class SafeArgumentParser(argparse.ArgumentParser):
    def error(self, message: str) -> NoReturn:
        fail(
            "EXPERIENCE_AUTHOR_INVALID_ARGUMENT",
            "The experience authoring command arguments are invalid.",
        )


def fail(code: str, message: str, **details: Any) -> NoReturn:
    raise AuthorFailure(code, message, details)


def failure_response(error: AuthorFailure) -> dict[str, Any]:
    return {
        "schemaVersion": RECEIPT_SCHEMA,
        "status": "FAIL",
        "code": error.code,
        "message": error.message,
        "recoveryAction": RECOVERY.get(
            error.code, RECOVERY["EXPERIENCE_AUTHOR_UNEXPECTED_ERROR"]
        ),
        **error.details,
    }


def emit(payload: dict[str, Any], as_json: bool) -> None:
    if as_json:
        print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
        return
    if payload["status"] == "PASS":
        print(
            f"PASS  {payload['packID']} · {payload['experienceID']} · "
            f"{payload['operation']}"
        )
        print(f"WRITE  {'yes' if payload['writesPerformed'] else 'no'}")
        if payload["backupReference"]:
            print(f"BACKUP  {payload['backupReference']}")
    else:
        print(f"FAIL  [{payload['code']}] {payload['message']}", file=sys.stderr)
        print(f"ACTION  {payload['recoveryAction']}", file=sys.stderr)


def regular_manifest(pack: pathlib.Path) -> tuple[dict[str, Any], bytes]:
    try:
        pack_status = pack.lstat()
    except OSError:
        fail("EXPERIENCE_AUTHOR_INVALID_ARGUMENT", "The pack directory is unavailable.")
    if pack.is_symlink() or not pack.is_dir() or not pack_status:
        fail("EXPERIENCE_AUTHOR_UNSAFE_INPUT", "The pack directory is unsafe.")
    try:
        pack = pack.resolve(strict=True)
    except OSError:
        fail("EXPERIENCE_AUTHOR_UNSAFE_INPUT", "The pack directory could not be resolved safely.")
    manifest_path = pack / "manifest.json"
    try:
        status = manifest_path.lstat()
    except OSError:
        fail("EXPERIENCE_AUTHOR_INVALID_ARGUMENT", "The pack manifest is unavailable.")
    if manifest_path.is_symlink() or not manifest_path.is_file() or status.st_nlink != 1:
        fail(
            "EXPERIENCE_AUTHOR_UNSAFE_INPUT",
            "The pack manifest is not a regular single-link file.",
        )
    if status.st_size <= 0 or status.st_size > MAX_MANIFEST_BYTES:
        fail("EXPERIENCE_AUTHOR_UNSAFE_INPUT", "The pack manifest size is outside the documented limit.")
    try:
        raw = manifest_path.read_bytes()
        value = json.loads(raw)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        fail("EXPERIENCE_AUTHOR_INVALID_JSON", "The pack manifest is not valid UTF-8 JSON.")
    if not isinstance(value, dict):
        fail("EXPERIENCE_AUTHOR_INVALID_JSON", "The pack manifest root must be an object.")
    return value, raw


def current_app_version() -> str:
    try:
        with INFO_PLIST.open("rb") as stream:
            return str(plistlib.load(stream)["CFBundleShortVersionString"])
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


def unique(values: list[str], code: str, label: str) -> list[str]:
    if len(values) != len(set(values)):
        fail(code, f"The experience contains duplicate {label} values.")
    return values


def parse_step(raw: str) -> dict[str, Any]:
    if len(raw) > 180 or any(ord(character) < 32 for character in raw):
        fail("EXPERIENCE_AUTHOR_INVALID_STEP", "An experience step is malformed.")
    parts = raw.split(":")
    if not 2 <= len(parts) <= 4:
        fail("EXPERIENCE_AUTHOR_INVALID_STEP", "An experience step has the wrong field count.")
    asset_id, role = parts[0], parts[1]
    if not IDENTIFIER.fullmatch(asset_id):
        fail("EXPERIENCE_AUTHOR_INVALID_IDENTIFIER", "An experience step asset ID is invalid.")
    if role not in ROLES:
        fail("EXPERIENCE_AUTHOR_INVALID_STEP", "An experience step role is unsupported.")
    step: dict[str, Any] = {"assetID": asset_id, "role": role}
    if len(parts) >= 3 and parts[2] != "":
        if not re.fullmatch(r"0|[1-9][0-9]{0,4}", parts[2]):
            fail("EXPERIENCE_AUTHOR_INVALID_STEP", "An experience step playback duration is invalid.")
        duration = int(parts[2])
        if duration > 60_000:
            fail("EXPERIENCE_AUTHOR_INVALID_STEP", "An experience step playback duration is outside its limit.")
        step["minimumPlaybackMs"] = duration
    if len(parts) == 4 and parts[3] != "":
        if parts[3] not in TRANSITIONS:
            fail("EXPERIENCE_AUTHOR_INVALID_STEP", "An experience step transition is unsupported.")
        step["transition"] = parts[3]
    return step


def build_experience(args: argparse.Namespace, manifest: dict[str, Any]) -> dict[str, Any]:
    if not IDENTIFIER.fullmatch(args.experience_id):
        fail("EXPERIENCE_AUTHOR_INVALID_IDENTIFIER", "The experience ID is invalid.")
    if args.kind not in KINDS:
        fail("EXPERIENCE_AUTHOR_INVALID_KIND", "The experience kind is unsupported.")
    if args.return_policy not in RETURN_POLICIES:
        fail("EXPERIENCE_AUTHOR_INVALID_POLICY", "The experience return policy is unsupported.")

    triggers = unique(args.trigger, "EXPERIENCE_AUTHOR_INVALID_TRIGGER", "trigger")
    if not 1 <= len(triggers) <= MAX_TRIGGERS:
        fail("EXPERIENCE_AUTHOR_INVALID_TRIGGER", "The experience trigger count is outside its limit.")
    for trigger in triggers:
        if trigger not in STATIC_TRIGGERS and not SCOPED_TRIGGER.fullmatch(trigger):
            fail("EXPERIENCE_AUTHOR_INVALID_TRIGGER", "An experience trigger is unsupported.")

    if not 1 <= len(args.step) <= MAX_STEPS:
        fail("EXPERIENCE_AUTHOR_LIMIT_EXCEEDED", "The experience step count is outside its limit.")
    steps = [parse_step(value) for value in args.step]

    locales: list[str] | None = None
    if args.locale:
        locales = unique(args.locale, "EXPERIENCE_AUTHOR_INVALID_LOCALE", "locale")
        if len(locales) > MAX_LOCALES or any(not LOCALE.fullmatch(value) for value in locales):
            fail("EXPERIENCE_AUTHOR_INVALID_LOCALE", "An experience locale is invalid.")

    cooldown: int | None = None
    if args.cooldown is not None:
        if not re.fullmatch(r"0|[1-9][0-9]{0,6}", args.cooldown):
            fail("EXPERIENCE_AUTHOR_INVALID_COOLDOWN", "The experience cooldown is invalid.")
        cooldown = int(args.cooldown)
        if cooldown > 604_800:
            fail("EXPERIENCE_AUTHOR_INVALID_COOLDOWN", "The experience cooldown is outside its limit.")

    weight: float | None = None
    if args.weight is not None:
        try:
            weight = float(args.weight)
        except ValueError:
            fail("EXPERIENCE_AUTHOR_INVALID_WEIGHT", "The experience weight is invalid.")
        if not math.isfinite(weight) or not 0.01 <= weight <= 100:
            fail("EXPERIENCE_AUTHOR_INVALID_WEIGHT", "The experience weight is outside its limit.")

    assets = manifest.get("assets")
    if not isinstance(assets, list):
        fail("EXPERIENCE_AUTHOR_SOURCE_PACK_INVALID", "The source pack has no valid asset list.")
    assets_by_id = {
        asset.get("id"): asset for asset in assets
        if isinstance(asset, dict) and isinstance(asset.get("id"), str)
    }
    for step in steps:
        asset = assets_by_id.get(step["assetID"])
        if asset is None:
            fail("EXPERIENCE_AUTHOR_ASSET_NOT_FOUND", "An experience step references an undeclared asset.")
        if asset.get("kind") != "video":
            fail("EXPERIENCE_AUTHOR_ASSET_NOT_VIDEO", "An experience step references a non-video asset.")

    experience: dict[str, Any] = {
        "id": args.experience_id,
        "kind": args.kind,
        "triggers": triggers,
        "steps": steps,
        "returnPolicy": args.return_policy,
    }
    if locales is not None:
        experience["locales"] = locales
    if cooldown is not None:
        experience["cooldownSeconds"] = cooldown
    if weight is not None:
        experience["weight"] = weight
    return experience


def atomic_write(path: pathlib.Path, payload: bytes) -> None:
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=".manifest.json.chengyin-experience-", dir=path.parent
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
    backup_root = pack.parent / f".{pack.name}.chengyin-experience-backups"
    if backup_root.exists() and (backup_root.is_symlink() or not backup_root.is_dir()):
        fail("EXPERIENCE_AUTHOR_UNSAFE_INPUT", "The sibling experience-backups location is unsafe.")
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


def success_receipt(
    manifest: dict[str, Any], experience: dict[str, Any], operation: str,
    writes: bool, backup_reference: str | None,
) -> dict[str, Any]:
    return {
        "schemaVersion": RECEIPT_SCHEMA,
        "status": "PASS",
        "code": None,
        "message": "The declarative experience passed the authoring contract.",
        "recoveryAction": (
            "Run the same command without --check to write transactionally."
            if operation == "check"
            else "Keep the backup until strict audit and playback review pass."
        ),
        "packID": manifest["id"],
        "packVersion": manifest["version"],
        "experienceID": experience["id"],
        "operation": operation,
        "writesPerformed": writes,
        "stepCount": len(experience["steps"]),
        "triggerCount": len(experience["triggers"]),
        "localeCount": len(experience.get("locales", [])),
        "backupReference": backup_reference,
    }


def parser_for_cli() -> SafeArgumentParser:
    parser = SafeArgumentParser(
        description="Create or replace one bounded Content Pack v2 experience."
    )
    parser.add_argument("pack_directory")
    parser.add_argument("--id", dest="experience_id", required=True)
    parser.add_argument("--kind", required=True)
    parser.add_argument("--trigger", action="append", required=True)
    parser.add_argument("--step", action="append", required=True)
    parser.add_argument("--locale", action="append", default=[])
    parser.add_argument("--cooldown")
    parser.add_argument("--weight")
    parser.add_argument("--return-policy", default="previousMode")
    parser.add_argument("--replace", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser


def main() -> int:
    as_json = "--json" in sys.argv[1:]
    try:
        args = parser_for_cli().parse_args()
        requested_pack = pathlib.Path(args.pack_directory)
        manifest, original = regular_manifest(requested_pack)
        pack = requested_pack.resolve(strict=True)
        if manifest.get("schemaVersion") != 2:
            fail("EXPERIENCE_AUTHOR_UNSUPPORTED_SCHEMA", "Experience authoring requires a schema-v2 pack.")
        if not validator_passes(pack):
            fail("EXPERIENCE_AUTHOR_SOURCE_PACK_INVALID", "The unchanged source pack did not pass validation.")
        experience = build_experience(args, manifest)
        existing = manifest.get("experiences")
        if not isinstance(existing, list):
            fail("EXPERIENCE_AUTHOR_SOURCE_PACK_INVALID", "The source pack has no valid experience list.")
        matches = [index for index, value in enumerate(existing)
                   if isinstance(value, dict) and value.get("id") == experience["id"]]
        if len(matches) > 1:
            fail("EXPERIENCE_AUTHOR_SOURCE_PACK_INVALID", "The source pack has duplicate experience identities.")
        if matches and not args.replace:
            fail("EXPERIENCE_AUTHOR_DUPLICATE_ID", "The experience ID already exists.")
        if not matches and args.replace:
            fail("EXPERIENCE_AUTHOR_DUPLICATE_ID", "No existing experience matches the requested replacement.")
        if not matches and len(existing) >= MAX_EXPERIENCES:
            fail("EXPERIENCE_AUTHOR_LIMIT_EXCEEDED", "The pack already contains the maximum experience count.")

        if args.check:
            emit(success_receipt(manifest, experience, "check", False, None), as_json)
            return 0

        updated = json.loads(json.dumps(manifest))
        if matches:
            updated["experiences"][matches[0]] = experience
            operation = "replace"
        else:
            updated["experiences"].append(experience)
            operation = "create"
        payload = (
            json.dumps(updated, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
        ).encode("utf-8")
        if len(payload) > MAX_MANIFEST_BYTES:
            fail("EXPERIENCE_AUTHOR_LIMIT_EXCEEDED", "The updated manifest would exceed its size limit.")
        backup, backup_reference = create_backup(pack, original)
        manifest_path = pack / "manifest.json"
        atomic_write(manifest_path, payload)
        if not validator_passes(pack):
            try:
                atomic_write(manifest_path, backup.read_bytes())
            except OSError:
                fail(
                    "EXPERIENCE_AUTHOR_ROLLBACK_FAILED",
                    "Post-write validation failed and the original manifest could not be restored automatically.",
                    rolledBack=False,
                    backupReference=backup_reference,
                )
            fail(
                "EXPERIENCE_AUTHOR_VALIDATION_FAILED",
                "Post-write validation failed and the original manifest was restored.",
                rolledBack=True,
                backupReference=backup_reference,
            )
        emit(success_receipt(manifest, experience, operation, True, backup_reference), as_json)
        return 0
    except AuthorFailure as error:
        emit(failure_response(error), as_json)
        return 1
    except Exception:
        emit(
            failure_response(
                AuthorFailure(
                    "EXPERIENCE_AUTHOR_UNEXPECTED_ERROR",
                    "The experience could not be authored safely.",
                )
            ),
            as_json,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
