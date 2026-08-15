#!/usr/bin/env python3
"""Build and relaunch the project-local Chengyin preview without installation."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import plistlib
import re
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from typing import Iterable

from macos_process_inspection import (
    ProcessInspectionError,
    discover_processes,
    executable_for_pid,
)


CONTRACT = "chengyin.local-preview/v1"
RELEASE_STATE = "NOT_PUBLIC_RELEASE_READY"
APP_RELATIVE = pathlib.Path("Chengyin Companion.app")
EXECUTABLE_NAME = "ChengyinCompanion"
INSTALLED_APP = pathlib.Path("/Applications") / APP_RELATIVE
BUILD_IDENTITY_PATTERN = re.compile(
    r"[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+\.[0-9a-f]{12}"
)


@dataclass(frozen=True)
class RunningProcess:
    pid: int
    executable: pathlib.Path


def same_file(left: pathlib.Path, right: pathlib.Path) -> bool:
    try:
        return os.path.samefile(left, right)
    except OSError:
        return left.resolve(strict=False) == right.resolve(strict=False)


def process_command(pid: int) -> pathlib.Path | None:
    return executable_for_pid(pid)


def discover_running_processes() -> list[RunningProcess]:
    return [
        RunningProcess(pid, executable)
        for pid, executable in discover_processes(EXECUTABLE_NAME)
    ]


def classify_processes(
    processes: Iterable[RunningProcess],
    dist_app: pathlib.Path,
    installed_app: pathlib.Path = INSTALLED_APP,
) -> tuple[dict[str, object], RunningProcess | None]:
    candidates = list(processes)
    dist_executable = dist_app / "Contents/MacOS" / EXECUTABLE_NAME
    installed_executable = installed_app / "Contents/MacOS" / EXECUTABLE_NAME
    origins: list[str] = []
    for candidate in candidates:
        if same_file(candidate.executable, dist_executable):
            origins.append("projectPreview")
        elif same_file(candidate.executable, installed_executable):
            origins.append("installed")
        else:
            origins.append("unverified")

    summary = {
        "state": "notRunning",
        "processCount": len(candidates),
        "projectPreviewCount": origins.count("projectPreview"),
        "installedCount": origins.count("installed"),
        "unverifiedCount": origins.count("unverified"),
    }
    if not candidates:
        return summary, None
    if len(candidates) > 1:
        summary["state"] = "conflict"
        return summary, None
    summary["state"] = origins[0]
    return summary, candidates[0] if origins[0] == "projectPreview" else None


def process_conflict(
    summary: dict[str, object],
) -> tuple[str | None, str | None, str | None]:
    if int(summary["processCount"]) > 1:
        return (
            "LOCAL_PREVIEW_MULTIPLE_PROCESSES",
            "More than one Chengyin Companion process is running.",
            "Quit the extra Chengyin Companion copies, then rerun ./scripts/preview-local.sh.",
        )
    if int(summary["installedCount"]) == 1:
        return (
            "LOCAL_PREVIEW_INSTALLED_PROCESS_ACTIVE",
            "The installed Chengyin Companion is running, so the project preview was left untouched.",
            "Quit the installed app normally, then rerun ./scripts/preview-local.sh.",
        )
    if int(summary["unverifiedCount"]) == 1:
        return (
            "LOCAL_PREVIEW_UNVERIFIED_PROCESS_ACTIVE",
            "A Chengyin Companion process from an unverified copy is running.",
            "Quit that copy normally, then rerun ./scripts/preview-local.sh from this checkout.",
        )
    return None, None, None


def stop_verified_preview(
    process: RunningProcess,
    dist_app: pathlib.Path,
    timeout_seconds: float = 8.0,
) -> bool:
    expected = dist_app / "Contents/MacOS" / EXECUTABLE_NAME
    current = process_command(process.pid)
    if current is None:
        return True
    if not same_file(current, expected) or not same_file(process.executable, expected):
        return False
    try:
        os.kill(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return True
    except OSError:
        return False
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        if process_command(process.pid) is None:
            return True
        time.sleep(0.1)
    return False


def run_hidden(command: list[str], root: pathlib.Path, timeout: int) -> int:
    try:
        result = subprocess.run(
            command,
            cwd=root,
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired):
        return 125
    return result.returncode


def read_build_identity(app: pathlib.Path) -> str | None:
    plist_path = app / "Contents/Info.plist"
    try:
        with plist_path.open("rb") as stream:
            info = plistlib.load(stream)
    except (OSError, plistlib.InvalidFileException):
        return None
    value = info.get("ChengyinBuildIdentity")
    return (
        value
        if isinstance(value, str) and BUILD_IDENTITY_PATTERN.fullmatch(value)
        else None
    )


def verify_runtime_identity(root: pathlib.Path) -> bool:
    try:
        result = subprocess.run(
            [
                "python3",
                "scripts/audit-local-runtime-identity.py",
                "--json",
            ],
            cwd=root,
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
        value = json.loads(result.stdout)
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
        return False
    dist = value.get("dist")
    running = value.get("running")
    return bool(
        isinstance(dist, dict)
        and dist.get("current") is True
        and isinstance(running, dict)
        and running.get("origin") == "distPreview"
        and running.get("current") is True
        and running.get("processCount") == 1
    )


def wait_for_project_preview(
    dist_app: pathlib.Path, timeout_seconds: float = 12.0
) -> tuple[dict[str, object], bool]:
    deadline = time.monotonic() + timeout_seconds
    latest: dict[str, object] = {
        "state": "notRunning",
        "processCount": 0,
        "projectPreviewCount": 0,
        "installedCount": 0,
        "unverifiedCount": 0,
    }
    while time.monotonic() < deadline:
        latest, _ = classify_processes(discover_running_processes(), dist_app)
        if (
            latest["state"] == "projectPreview"
            and latest["processCount"] == 1
        ):
            return latest, True
        if latest["installedCount"] or latest["unverifiedCount"]:
            return latest, False
        time.sleep(0.2)
    return latest, False


def base_receipt(mode: str) -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "contract": CONTRACT,
        "status": "FAIL",
        "code": None,
        "mode": mode,
        "message": "The local preview did not finish.",
        "recoveryAction": None,
        "networkRequired": False,
        "providerCredentialsRequired": False,
        "applicationsDirectoryModified": False,
        "preflight": "NOT_RUN",
        "processBefore": {
            "state": "notInspected",
            "processCount": 0,
            "projectPreviewCount": 0,
            "installedCount": 0,
            "unverifiedCount": 0,
        },
        "processStop": "NOT_NEEDED",
        "build": {"status": "NOT_RUN", "identity": None},
        "launch": {
            "status": "NOT_RUN",
            "processCount": 0,
            "projectPreviewCount": 0,
            "identityCurrent": False,
        },
        "rollback": "NOT_NEEDED",
        "releaseState": RELEASE_STATE,
    }


def fail_receipt(
    receipt: dict[str, object], code: str, message: str, action: str
) -> dict[str, object]:
    receipt.update(
        status="FAIL",
        code=code,
        message=message,
        recoveryAction=action,
    )
    return receipt


def validate_root(root: pathlib.Path) -> bool:
    required = (
        root / "Package.swift",
        root / "Info.plist",
        root / "scripts/bootstrap-local.sh",
        root / "scripts/build-app.sh",
    )
    return root.is_dir() and not root.is_symlink() and all(path.is_file() for path in required)


def run_preview(root: pathlib.Path, check_only: bool) -> dict[str, object]:
    mode = "check-only" if check_only else "update-and-launch"
    receipt = base_receipt(mode)
    if not validate_root(root):
        return fail_receipt(
            receipt,
            "LOCAL_PREVIEW_SOURCE_MISSING",
            "The checkout is missing files required by the local preview flow.",
            "Restore a complete source checkout, then rerun ./scripts/preview-local.sh.",
        )

    preflight_status = run_hidden(
        ["./scripts/bootstrap-local.sh", "--check-only", "--source-only"],
        root,
        300,
    )
    if preflight_status != 0:
        receipt["preflight"] = "FAIL"
        return fail_receipt(
            receipt,
            "LOCAL_PREVIEW_PREFLIGHT_FAILED",
            "The source-only Mac preflight failed before any preview process was changed.",
            "Run ./scripts/bootstrap-local.sh --check-only --source-only, follow its recovery action, then retry.",
        )
    receipt["preflight"] = "PASS"

    dist_app = root / "dist" / APP_RELATIVE
    try:
        before, preview_process = classify_processes(discover_running_processes(), dist_app)
    except ProcessInspectionError:
        return fail_receipt(
            receipt,
            "LOCAL_PREVIEW_PROCESS_INSPECTION_UNAVAILABLE",
            "The local preview could not safely inspect existing Chengyin processes.",
            "Retry from a normal macOS user session; no running application was changed.",
        )
    receipt["processBefore"] = before
    conflict_code, conflict_message, conflict_action = process_conflict(before)
    if conflict_code is not None:
        return fail_receipt(receipt, conflict_code, conflict_message or "", conflict_action or "")

    if check_only:
        receipt.update(
            status="PASS",
            code=None,
            message="The checkout can build a project-local preview without modifying /Applications.",
            recoveryAction=None,
        )
        return receipt

    had_preview = preview_process is not None
    if preview_process is not None:
        if not stop_verified_preview(preview_process, dist_app):
            receipt["processStop"] = "FAIL"
            return fail_receipt(
                receipt,
                "LOCAL_PREVIEW_STOP_FAILED",
                "The verified project preview did not exit normally, so the build was not started.",
                "Quit the project preview normally, then rerun ./scripts/preview-local.sh.",
            )
        receipt["processStop"] = "PASS"

    build_status = run_hidden(["./scripts/build-app.sh"], root, 1800)
    if build_status != 0:
        receipt["build"] = {"status": "FAIL", "identity": None}
        if had_preview and dist_app.is_dir():
            rollback_status = run_hidden(["/usr/bin/open", "-n", str(dist_app)], root, 20)
            receipt["rollback"] = (
                "PREVIOUS_PREVIEW_RELAUNCH_REQUESTED"
                if rollback_status == 0
                else "PREVIOUS_PREVIEW_RELAUNCH_FAILED"
            )
        return fail_receipt(
            receipt,
            "LOCAL_PREVIEW_BUILD_FAILED",
            "The project preview build failed; /Applications was not modified.",
            "Run ./scripts/build-app.sh to inspect the build failure, repair it, then retry.",
        )

    identity = read_build_identity(dist_app)
    if identity is None:
        receipt["build"] = {"status": "FAIL", "identity": None}
        return fail_receipt(
            receipt,
            "LOCAL_PREVIEW_IDENTITY_MISMATCH",
            "The built preview has no valid reproducible build identity.",
            "Run ./scripts/build-app.sh, repair the bundle identity failure, then retry.",
        )
    receipt["build"] = {"status": "PASS", "identity": identity}

    launch_status = run_hidden(["/usr/bin/open", "-n", str(dist_app)], root, 20)
    if launch_status != 0:
        receipt["launch"] = {
            "status": "FAIL",
            "processCount": 0,
            "projectPreviewCount": 0,
            "identityCurrent": False,
        }
        return fail_receipt(
            receipt,
            "LOCAL_PREVIEW_LAUNCH_FAILED",
            "The current preview was built but macOS did not accept the launch request.",
            "Open dist/Chengyin Companion.app manually, then run python3 scripts/audit-local-runtime-identity.py --json.",
        )

    after, running = wait_for_project_preview(dist_app)
    identity_current = running and verify_runtime_identity(root)
    receipt["launch"] = {
        "status": "PASS" if identity_current else "FAIL",
        "processCount": after["processCount"],
        "projectPreviewCount": after["projectPreviewCount"],
        "identityCurrent": identity_current,
    }
    if not identity_current:
        return fail_receipt(
            receipt,
            "LOCAL_PREVIEW_IDENTITY_MISMATCH",
            "The launched preview did not prove that its running identity matches the current source.",
            "Quit every Chengyin copy, rerun ./scripts/preview-local.sh, then inspect the local runtime identity receipt.",
        )

    receipt.update(
        status="PASS",
        code=None,
        message="The current project-local preview was built, relaunched and verified.",
        recoveryAction=None,
    )
    return receipt


def emit(receipt: dict[str, object], json_mode: bool) -> int:
    if json_mode:
        print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
    elif receipt["status"] == "PASS":
        print(f"Local preview: PASS ({receipt['mode']})")
        if receipt["build"]["identity"]:
            print(f"Build identity: {receipt['build']['identity']}")
        print("/Applications was not modified.")
        print(f"Release state: {RELEASE_STATE}")
    else:
        print(f"FAIL  [{receipt['code']}] {receipt['message']}", file=sys.stderr)
        if receipt["recoveryAction"]:
            print(f"ACTION  {receipt['recoveryAction']}", file=sys.stderr)
    return 0 if receipt["status"] == "PASS" else 1


def parse_arguments(argv: list[str]) -> argparse.Namespace | int:
    parser = argparse.ArgumentParser(
        description="Build and relaunch the project-local Chengyin preview without installation.",
        add_help=False,
    )
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--help", "-h", action="store_true")
    arguments, unknown = parser.parse_known_args(argv)
    if arguments.help:
        parser.print_help()
        return 0
    if unknown:
        receipt = fail_receipt(
            base_receipt("check-only" if arguments.check_only else "update-and-launch"),
            "LOCAL_PREVIEW_INVALID_ARGUMENT",
            "The local preview command received an unsupported option.",
            "Run ./scripts/preview-local.sh --help, remove the unsupported option, then retry.",
        )
        return emit(receipt, arguments.json)
    return arguments


def main() -> int:
    arguments = parse_arguments(sys.argv[1:])
    if isinstance(arguments, int):
        return arguments
    root = pathlib.Path(__file__).resolve().parent.parent
    try:
        receipt = run_preview(root, arguments.check_only)
    except Exception:
        receipt = fail_receipt(
            base_receipt("check-only" if arguments.check_only else "update-and-launch"),
            "LOCAL_PREVIEW_UNEXPECTED_ERROR",
            "The local preview flow stopped on an unexpected local error.",
            "Run ./scripts/preview-local.sh --check-only --json, repair the reported prerequisite, then retry.",
        )
    return emit(receipt, arguments.json)


if __name__ == "__main__":
    raise SystemExit(main())
