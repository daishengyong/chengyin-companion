#!/usr/bin/env python3
"""Audit source, preview, installed and running identities without path leaks."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import plistlib
import re
import sys
from dataclasses import dataclass
from typing import Iterable

from macos_process_inspection import ProcessInspectionError, discover_executables


CONTRACT = "chengyin.local-runtime-identity/v1"
BUNDLE_ID = "local.zidong.chengyin-companion"
EXECUTABLE_NAME = "ChengyinCompanion"
APP_RELATIVE = pathlib.Path("Chengyin Companion.app")
SOURCE_ROOT_FILES = (
    "Package.swift",
    "Info.plist",
    "scripts/build-app.sh",
    "scripts/swift-build-cache.sh",
    "scripts/swift-toolchain-env.sh",
    "scripts/macos_process_inspection.py",
    "scripts/install-local-app.sh",
    "scripts/app-bundle-common.sh",
)
SOURCE_DIRECTORIES = (
    "Sources/CompanionApp",
    "Sources/CompanionContracts",
    "Tools/CompanionEventEmitter",
)
FINGERPRINT_PATTERN = re.compile(r"[0-9a-f]{64}")
SEMVER_PATTERN = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+")


@dataclass(frozen=True)
class AppIdentity:
    state: str
    identity: str | None
    source_fingerprint: str | None
    current: bool

    def receipt(self) -> dict[str, object]:
        return {
            "state": self.state,
            "identity": self.identity,
            "sourceFingerprintShort": short_fingerprint(self.source_fingerprint),
            "current": self.current,
        }


def short_fingerprint(value: str | None) -> str | None:
    return value[:12] if value else None


def source_inventory(root: pathlib.Path) -> list[pathlib.Path]:
    inventory: set[pathlib.Path] = set()
    for relative in SOURCE_ROOT_FILES:
        candidate = root / relative
        if candidate.is_file() and not candidate.is_symlink():
            inventory.add(pathlib.Path(relative))
    for relative in SOURCE_DIRECTORIES:
        directory = root / relative
        if not directory.is_dir() or directory.is_symlink():
            continue
        for candidate in directory.rglob("*"):
            if (
                candidate.is_file()
                and not candidate.is_symlink()
                and candidate.name != ".DS_Store"
            ):
                inventory.add(candidate.relative_to(root))
    return sorted(inventory, key=lambda path: path.as_posix())


def source_fingerprint(root: pathlib.Path) -> str:
    digest = hashlib.sha256()
    for relative in source_inventory(root):
        file_digest = hashlib.sha256()
        with (root / relative).open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                file_digest.update(chunk)
        digest.update(relative.as_posix().encode("utf-8"))
        digest.update(b"\0")
        digest.update(file_digest.hexdigest().encode("ascii"))
        digest.update(b"\0")
    return digest.hexdigest()


def app_bundle_for_executable(executable: pathlib.Path) -> pathlib.Path | None:
    suffix = pathlib.Path("Contents/MacOS") / EXECUTABLE_NAME
    parts = executable.parts
    suffix_parts = suffix.parts
    if len(parts) <= len(suffix_parts) or tuple(parts[-len(suffix_parts) :]) != suffix_parts:
        return None
    return pathlib.Path(*parts[: -len(suffix_parts)])


def read_app_identity(app: pathlib.Path, expected_source: str) -> AppIdentity:
    if not app.is_dir() or app.is_symlink():
        return AppIdentity("missing", None, None, False)
    plist_path = app / "Contents/Info.plist"
    executable = app / "Contents/MacOS" / EXECUTABLE_NAME
    if not plist_path.is_file() or plist_path.is_symlink() or not executable.is_file():
        return AppIdentity("invalid", None, None, False)
    try:
        with plist_path.open("rb") as stream:
            info = plistlib.load(stream)
    except (OSError, plistlib.InvalidFileException):
        return AppIdentity("invalid", None, None, False)

    version = info.get("CFBundleShortVersionString")
    build = str(info.get("CFBundleVersion", ""))
    bundle_id = info.get("CFBundleIdentifier")
    fingerprint = info.get("ChengyinSourceFingerprint")
    identity = info.get("ChengyinBuildIdentity")
    valid = (
        bundle_id == BUNDLE_ID
        and isinstance(version, str)
        and SEMVER_PATTERN.fullmatch(version) is not None
        and build.isdigit()
        and isinstance(fingerprint, str)
        and FINGERPRINT_PATTERN.fullmatch(fingerprint) is not None
        and isinstance(identity, str)
        and identity == f"{version}+{build}.{fingerprint[:12]}"
    )
    if not valid:
        return AppIdentity("invalid", None, None, False)
    current = fingerprint == expected_source
    return AppIdentity(
        "current" if current else "stale",
        identity,
        fingerprint,
        current,
    )


def same_file(left: pathlib.Path, right: pathlib.Path) -> bool:
    try:
        return os.path.samefile(left, right)
    except OSError:
        return left.resolve(strict=False) == right.resolve(strict=False)


def discover_running_executables() -> list[pathlib.Path]:
    return discover_executables(EXECUTABLE_NAME)


def running_receipt(
    executables: Iterable[pathlib.Path],
    dist: pathlib.Path,
    installed: pathlib.Path,
    expected_source: str,
) -> tuple[dict[str, object], list[AppIdentity]]:
    executable_list = list(executables)
    if not executable_list:
        return {
            "state": "notRunning",
            "origin": "none",
            "identity": None,
            "sourceFingerprintShort": None,
            "current": False,
            "processCount": 0,
        }, []

    identities: list[AppIdentity] = []
    origins: list[str] = []
    dist_executable = dist / "Contents/MacOS" / EXECUTABLE_NAME
    installed_executable = installed / "Contents/MacOS" / EXECUTABLE_NAME
    for executable in executable_list:
        if same_file(executable, dist_executable):
            origins.append("distPreview")
        elif same_file(executable, installed_executable):
            origins.append("installed")
        else:
            origins.append("other")
        app = app_bundle_for_executable(executable)
        identities.append(
            read_app_identity(app, expected_source)
            if app is not None
            else AppIdentity("invalid", None, None, False)
        )

    first = identities[0]
    return {
        "state": "multiple" if len(executable_list) > 1 else first.state,
        "origin": "multiple" if len(set(origins)) > 1 else origins[0],
        "identity": first.identity if len(executable_list) == 1 else None,
        "sourceFingerprintShort": (
            short_fingerprint(first.source_fingerprint)
            if len(executable_list) == 1
            else None
        ),
        "current": len(executable_list) == 1 and first.current,
        "processCount": len(executable_list),
    }, identities


def outcome(
    dist: AppIdentity,
    installed: AppIdentity,
    running: dict[str, object],
    running_identities: list[AppIdentity],
) -> tuple[str, str | None, str, str | None]:
    if int(running["processCount"]) > 1:
        return (
            "FAIL",
            "UI_RUNTIME_IDENTITY_MULTIPLE_PROCESSES",
            "More than one Chengyin Companion process is running.",
            "Quit every Chengyin Companion process, launch one verified app, then rerun the identity audit.",
        )
    if running_identities and running_identities[0].state == "invalid":
        return (
            "FAIL",
            "UI_RUNTIME_IDENTITY_INVALID",
            "The running application has no valid reproducible build identity.",
            "Quit it, rebuild with ./scripts/build-app.sh, then launch the verified preview and retry.",
        )
    if running["origin"] == "other":
        return (
            "FAIL",
            "UI_RUNTIME_IDENTITY_ORIGIN_UNKNOWN",
            "The running application came from an unverified local copy.",
            "Quit it and launch either the verified dist preview or the installed application, then retry.",
        )
    if running_identities and not running_identities[0].current:
        return (
            "FAIL",
            "UI_RUNTIME_IDENTITY_RUNNING_STALE",
            "The running application is older than the current source.",
            "Quit the stale process, rebuild, perform an owner-approved local install, and relaunch.",
        )
    if dist.state == "invalid" or installed.state == "invalid":
        return (
            "FAIL",
            "UI_RUNTIME_IDENTITY_INVALID",
            "A local application bundle has malformed build identity metadata.",
            "Rebuild with ./scripts/build-app.sh and replace the invalid copy through the local installer.",
        )
    if running["state"] == "notRunning":
        return (
            "PENDING",
            "UI_RUNTIME_IDENTITY_RESTART_REQUIRED",
            "No Chengyin Companion process is running.",
            "Launch the verified dist preview for testing or the installed application, then retry.",
        )
    if dist.state != "current" or installed.state != "current":
        return (
            "PENDING",
            "UI_RUNTIME_IDENTITY_INSTALL_REQUIRED",
            "The current preview is usable, but the local installation does not match the current source.",
            "When owner-approved, run ./scripts/install-local-app.sh and relaunch the installed application.",
        )
    if running["origin"] != "installed":
        return (
            "PENDING",
            "UI_RUNTIME_IDENTITY_INSTALL_REQUIRED",
            "The current preview is running, but the installed application has not been verified as the active copy.",
            "When owner-approved, launch the installed application and rerun the identity audit.",
        )
    return (
        "PASS",
        None,
        "Source, dist, installed and running identities agree.",
        None,
    )


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Return a privacy-safe local Chengyin runtime identity receipt."
    )
    parser.add_argument("--root", type=pathlib.Path)
    parser.add_argument("--dist-app", type=pathlib.Path)
    parser.add_argument("--installed-app", type=pathlib.Path)
    parser.add_argument(
        "--running-executable",
        type=pathlib.Path,
        action="append",
        default=None,
        help="Inject a running executable for deterministic tests; repeat for multiple processes.",
    )
    parser.add_argument(
        "--no-running-process",
        action="store_true",
        help="Skip live process discovery and report the not-running state.",
    )
    parser.add_argument("--json", action="store_true")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    root = (arguments.root or pathlib.Path(__file__).resolve().parent.parent).resolve()
    dist_path = arguments.dist_app or root / "dist" / APP_RELATIVE
    installed_path = arguments.installed_app or pathlib.Path("/Applications") / APP_RELATIVE
    expected_source = source_fingerprint(root)
    dist_identity = read_app_identity(dist_path, expected_source)
    installed_identity = read_app_identity(installed_path, expected_source)
    if arguments.no_running_process:
        executables: list[pathlib.Path] = []
    elif arguments.running_executable is not None:
        executables = arguments.running_executable
    else:
        try:
            executables = discover_running_executables()
        except ProcessInspectionError:
            executables = []
            inspection_unavailable = True
        else:
            inspection_unavailable = False
    running, running_identities = running_receipt(
        executables,
        dist_path,
        installed_path,
        expected_source,
    )
    status, code, message, recovery_action = outcome(
        dist_identity,
        installed_identity,
        running,
        running_identities,
    )
    if not arguments.no_running_process \
        and arguments.running_executable is None \
        and inspection_unavailable:
        status = "FAIL"
        code = "UI_RUNTIME_IDENTITY_PROCESS_INSPECTION_UNAVAILABLE"
        message = "The running Chengyin process identity could not be inspected safely."
        recovery_action = "Retry from a normal macOS user session; no process identity was inferred."
    receipt = {
        "schemaVersion": 1,
        "contract": CONTRACT,
        "status": status,
        "code": code,
        "message": message,
        "recoveryAction": recovery_action,
        "source": {"fingerprintShort": short_fingerprint(expected_source)},
        "dist": dist_identity.receipt(),
        "installed": installed_identity.receipt(),
        "running": running,
        "releaseState": "NOT_PUBLIC_RELEASE_READY",
    }
    if arguments.json:
        print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
    else:
        prefix = status if code is None else f"{status} [{code}]"
        print(f"{prefix} {message}")
        if recovery_action:
            print(f"ACTION {recovery_action}")
        for label in ("source", "dist", "installed", "running"):
            print(f"{label.upper()} {json.dumps(receipt[label], sort_keys=True)}")
    return 0 if status == "PASS" else (2 if status == "PENDING" else 1)


if __name__ == "__main__":
    raise SystemExit(main())
