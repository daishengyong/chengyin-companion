#!/usr/bin/env python3
"""Atomically scaffold a path-safe local-first Content Pack v2 draft."""

from __future__ import annotations

import json
import os
import pathlib
import plistlib
import re
import shutil
import sys
import tempfile
from typing import NoReturn, Optional, Tuple


CONTRACT = "chengyin.content-pack-scaffold/v1"
RELEASE_STATE = "NOT_PUBLIC_RELEASE_READY"
PACK_ID = re.compile(r"^[a-z0-9]+(?:[.-][a-z0-9]+)+$")
CHARACTER_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$")
LOCALE = re.compile(r"^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$")
SEMVER = re.compile(r"^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)$")
MAX_LOCALES = 32


def base_receipt() -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "contract": CONTRACT,
        "status": "FAIL",
        "code": None,
        "message": "The content-pack draft was not created.",
        "recoveryAction": None,
        "packID": None,
        "characterID": None,
        "locales": [],
        "contributionMode": "compatibility-v2",
        "reviewState": "pending-creator-evidence",
        "rightsInferred": False,
        "writesPerformed": False,
        "destinationCreated": False,
        "atomicPublish": True,
        "networkRequired": False,
        "providerCredentialsRequired": False,
        "releaseState": RELEASE_STATE,
    }


def emit(receipt: dict[str, object], json_mode: bool, exit_code: int) -> NoReturn:
    if json_mode:
        print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
    elif receipt["status"] == "PASS":
        print(f"Content-pack draft created: {receipt['packID']}")
        print("Rights, license grants and review approval were not inferred.")
        print("Next: validate the draft, then run the v2 migration planner.")
        print(f"Release state: {RELEASE_STATE}")
    else:
        print(f"FAIL  [{receipt['code']}] {receipt['message']}", file=sys.stderr)
        if receipt["recoveryAction"]:
            print(f"ACTION  {receipt['recoveryAction']}", file=sys.stderr)
    raise SystemExit(exit_code)


def fail(
    code: str,
    message: str,
    action: str,
    *,
    json_mode: bool,
    exit_code: int = 2,
) -> NoReturn:
    receipt = base_receipt()
    receipt.update(code=code, message=message, recoveryAction=action)
    emit(receipt, json_mode, exit_code)


def help_text() -> str:
    return (
        "Usage: ./scripts/new-content-pack.sh <destination> <reverse-domain-id> "
        "<character-id> [locale] [--locale <tag> ...] [--json]\n"
        "Creates one atomic compatibility-v2 draft without inferring rights or review approval."
    )


def parse_arguments(
    argv: list[str],
) -> Optional[Tuple[list[str], list[str], bool]]:
    if "--help" in argv or "-h" in argv:
        print(help_text())
        return None
    json_mode = "--json" in argv
    positionals: list[str] = []
    extra_locales: list[str] = []
    index = 0
    while index < len(argv):
        value = argv[index]
        if value == "--json":
            index += 1
        elif value == "--locale":
            if index + 1 >= len(argv):
                fail(
                    "CREATOR_SCAFFOLD_INVALID_ARGUMENT",
                    "The --locale option is missing its value.",
                    "Add a valid BCP-47-style language tag after --locale, then retry.",
                    json_mode=json_mode,
                )
            extra_locales.append(argv[index + 1])
            index += 2
        elif value.startswith("-"):
            fail(
                "CREATOR_SCAFFOLD_INVALID_ARGUMENT",
                "The content-pack scaffold received an unsupported option.",
                "Run ./scripts/new-content-pack.sh --help, remove the unsupported option, then retry.",
                json_mode=json_mode,
            )
        else:
            positionals.append(value)
            index += 1
    if len(positionals) not in {3, 4}:
        fail(
            "CREATOR_SCAFFOLD_INVALID_ARGUMENT",
            "The content-pack scaffold requires destination, pack ID and character ID.",
            "Run ./scripts/new-content-pack.sh --help and provide the required values.",
            json_mode=json_mode,
        )
    return positionals, extra_locales, json_mode


def app_version(root: pathlib.Path, json_mode: bool) -> str:
    try:
        with (root / "Info.plist").open("rb") as stream:
            value = plistlib.load(stream).get("CFBundleShortVersionString")
    except (OSError, plistlib.InvalidFileException):
        value = None
    if not isinstance(value, str) or not SEMVER.fullmatch(value):
        fail(
            "CREATOR_SCAFFOLD_APP_VERSION_MISSING",
            "The current app version could not be read for the new draft.",
            "Restore Info.plist with a semantic app version, then retry.",
            json_mode=json_mode,
            exit_code=1,
        )
    return value


def validate_locales(values: list[str], json_mode: bool) -> list[str]:
    if not values:
        values = ["zh-Hans"]
    if len(values) > MAX_LOCALES or any(not LOCALE.fullmatch(value) for value in values):
        fail(
            "CREATOR_SCAFFOLD_INVALID_LOCALE",
            "A locale tag is invalid or the 32-locale limit was exceeded.",
            "Use unique BCP-47-style tags such as zh-Hans, en-US or ja, then retry.",
            json_mode=json_mode,
        )
    normalized = [value.lower() for value in values]
    if len(normalized) != len(set(normalized)):
        fail(
            "CREATOR_SCAFFOLD_DUPLICATE_LOCALE",
            "The content-pack draft contains a duplicate locale tag.",
            "Remove the duplicate --locale value, then retry.",
            json_mode=json_mode,
        )
    return values


def draft_manifest(
    pack_id: str,
    character_id: str,
    locales: list[str],
    minimum_app_version: str,
) -> dict[str, object]:
    return {
        "schemaVersion": 2,
        "id": pack_id,
        "version": "0.1.0",
        "minAppVersion": minimum_app_version,
        "tier": "local",
        "character": character_id,
        "locales": locales,
        "assets": [],
        "license": "LicenseRef-Pending-Creator-Review",
        "experiences": [],
        "contribution": {
            "rights": [],
            "accessibility": [],
            "fallback": {"strategy": "starter"},
        },
    }


def write_draft(
    destination: pathlib.Path,
    manifest: dict[str, object],
    json_mode: bool,
) -> None:
    if destination.name in {"", ".", ".."}:
        fail(
            "CREATOR_SCAFFOLD_INVALID_ARGUMENT",
            "The destination name is invalid.",
            "Choose a new child directory name and retry.",
            json_mode=json_mode,
        )
    try:
        parent = destination.parent.resolve(strict=True)
    except OSError:
        fail(
            "CREATOR_SCAFFOLD_DESTINATION_PARENT_UNSAFE",
            "The destination parent is missing or cannot be resolved safely.",
            "Create and inspect the parent directory, then retry with a new destination.",
            json_mode=json_mode,
        )
    if not parent.is_dir():
        fail(
            "CREATOR_SCAFFOLD_DESTINATION_PARENT_UNSAFE",
            "The destination parent is not a regular directory.",
            "Choose an existing local directory, then retry.",
            json_mode=json_mode,
        )
    final = parent / destination.name
    if os.path.lexists(final):
        fail(
            "CREATOR_SCAFFOLD_DESTINATION_EXISTS",
            "The destination already exists and was left unchanged.",
            "Choose a new destination or move the existing draft aside, then retry.",
            json_mode=json_mode,
        )

    staging: Optional[pathlib.Path] = None
    try:
        staging = pathlib.Path(
            tempfile.mkdtemp(
                prefix=f".{destination.name}.chengyin-staging-",
                dir=parent,
            )
        )
        os.chmod(staging, 0o755)
        for child in ("media", "localization", "games"):
            path = staging / child
            path.mkdir(mode=0o755)
        manifest_path = staging / "manifest.json"
        with manifest_path.open("x", encoding="utf-8") as stream:
            json.dump(manifest, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(manifest_path, 0o644)
        if os.environ.get("CHENGYIN_SCAFFOLD_FAIL_AFTER_MANIFEST") == "1":
            raise OSError("injected scaffold failure")
        os.replace(staging, final)
        staging = None
    except OSError:
        if staging is not None:
            shutil.rmtree(staging, ignore_errors=True)
        fail(
            "CREATOR_SCAFFOLD_WRITE_FAILED",
            "The draft could not be published atomically and no partial destination was kept.",
            "Check local disk access and free space, then retry with a new destination.",
            json_mode=json_mode,
            exit_code=1,
        )


def main() -> int:
    parsed = parse_arguments(sys.argv[1:])
    if parsed is None:
        return 0
    positionals, extra_locales, json_mode = parsed
    destination = pathlib.Path(positionals[0])
    pack_id = positionals[1]
    character_id = positionals[2]
    if not PACK_ID.fullmatch(pack_id):
        fail(
            "CREATOR_SCAFFOLD_INVALID_PACK_ID",
            "The pack ID is not a lowercase reverse-domain identifier.",
            "Use a value such as cc.example.my-pack, then retry.",
            json_mode=json_mode,
        )
    if not CHARACTER_ID.fullmatch(character_id):
        fail(
            "CREATOR_SCAFFOLD_INVALID_CHARACTER",
            "The character ID contains unsupported characters or exceeds 96 characters.",
            "Use a stable ASCII identifier such as starter or companion.luna, then retry.",
            json_mode=json_mode,
        )
    locale_values = ([positionals[3]] if len(positionals) == 4 else []) + extra_locales
    locales = validate_locales(locale_values, json_mode)
    root = pathlib.Path(__file__).resolve().parent.parent
    minimum_app_version = app_version(root, json_mode)
    manifest = draft_manifest(pack_id, character_id, locales, minimum_app_version)
    write_draft(destination, manifest, json_mode)

    receipt = base_receipt()
    receipt.update(
        status="PASS",
        message="An atomic compatibility-v2 content-pack draft was created locally.",
        packID=pack_id,
        characterID=character_id,
        locales=locales,
        writesPerformed=True,
        destinationCreated=True,
    )
    emit(receipt, json_mode, 0)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
