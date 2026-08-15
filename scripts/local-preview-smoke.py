#!/usr/bin/env python3
"""Deterministic negative and lifecycle tests for the zero-install preview."""

from __future__ import annotations

import importlib.util
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time


ROOT = pathlib.Path(__file__).resolve().parent.parent
MODULE_PATH = ROOT / "scripts/local-preview.py"
SPEC = importlib.util.spec_from_file_location("chengyin_local_preview", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)

checks = 0


def check(condition: bool, label: str) -> None:
    global checks
    checks += 1
    if not condition:
        raise AssertionError(label)
    print(f"PASS  {label}")


with tempfile.TemporaryDirectory(prefix="chengyin-local-preview-") as raw_tmp:
    tmp = pathlib.Path(raw_tmp).resolve()
    dist_app = tmp / "project/dist/Chengyin Companion.app"
    dist_executable = dist_app / "Contents/MacOS/ChengyinCompanion"
    installed_app = tmp / "Applications/Chengyin Companion.app"
    installed_executable = installed_app / "Contents/MacOS/ChengyinCompanion"
    other_executable = tmp / "copied/Chengyin Companion.app/Contents/MacOS/ChengyinCompanion"
    for executable in (dist_executable, installed_executable, other_executable):
        executable.parent.mkdir(parents=True, exist_ok=True)
        executable.write_bytes(b"fixture")

    empty, candidate = MODULE.classify_processes([], dist_app, installed_app)
    check(empty["state"] == "notRunning" and candidate is None, "No-process plan")

    preview = MODULE.RunningProcess(101, dist_executable)
    summary, candidate = MODULE.classify_processes([preview], dist_app, installed_app)
    check(
        summary["state"] == "projectPreview" and candidate == preview,
        "Exact project preview is the only stoppable origin",
    )

    inspection_source = tmp / "inspection-source"
    for relative in (
        "Package.swift",
        "Info.plist",
        "scripts/bootstrap-local.sh",
        "scripts/build-app.sh",
    ):
        path = inspection_source / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("fixture\n", encoding="utf-8")
    original_run_hidden = MODULE.run_hidden
    original_discovery = MODULE.discover_running_processes

    def unavailable_discovery() -> list[MODULE.RunningProcess]:
        raise MODULE.ProcessInspectionError("fixture")

    try:
        MODULE.run_hidden = lambda command, root, timeout: 0
        MODULE.discover_running_processes = unavailable_discovery
        unavailable = MODULE.run_preview(inspection_source, check_only=True)
    finally:
        MODULE.run_hidden = original_run_hidden
        MODULE.discover_running_processes = original_discovery
    check(
        unavailable["status"] == "FAIL"
        and unavailable["code"]
        == "LOCAL_PREVIEW_PROCESS_INSPECTION_UNAVAILABLE"
        and unavailable["applicationsDirectoryModified"] is False,
        "Unavailable process inspection fails closed",
    )

    installed = MODULE.RunningProcess(102, installed_executable)
    summary, candidate = MODULE.classify_processes([installed], dist_app, installed_app)
    code, _, action = MODULE.process_conflict(summary)
    check(
        code == "LOCAL_PREVIEW_INSTALLED_PROCESS_ACTIVE"
        and candidate is None
        and "Quit" in action,
        "Installed app is never terminated by preview flow",
    )

    unverified = MODULE.RunningProcess(103, other_executable)
    summary, candidate = MODULE.classify_processes([unverified], dist_app, installed_app)
    code, _, _ = MODULE.process_conflict(summary)
    check(
        code == "LOCAL_PREVIEW_UNVERIFIED_PROCESS_ACTIVE" and candidate is None,
        "Unverified copy is never terminated",
    )

    summary, candidate = MODULE.classify_processes(
        [preview, installed], dist_app, installed_app
    )
    code, _, _ = MODULE.process_conflict(summary)
    check(
        code == "LOCAL_PREVIEW_MULTIPLE_PROCESSES" and candidate is None,
        "Multiple processes fail closed",
    )

    executable = tmp / "runtime/dist/Chengyin Companion.app/Contents/MacOS/ChengyinCompanion"
    executable.parent.mkdir(parents=True)
    module_cache = tmp / "runtime/swift-module-cache"
    module_cache.mkdir(parents=True)
    compiler_environment = os.environ.copy()
    compiler_environment["CLANG_MODULE_CACHE_PATH"] = str(module_cache)
    compiler_environment["SWIFTPM_MODULECACHE_OVERRIDE"] = str(module_cache)
    subprocess.run(
        [
            "/usr/bin/xcrun",
            "swiftc",
            "-module-cache-path",
            str(module_cache),
            str(ROOT / "scripts/local-preview-sleeper.swift"),
            "-o",
            str(executable),
        ],
        check=True,
        env=compiler_environment,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    process = subprocess.Popen([str(executable)])
    try:
        deadline = time.monotonic() + 5
        while MODULE.process_command(process.pid) is None and time.monotonic() < deadline:
            time.sleep(0.05)
        stopped = MODULE.stop_verified_preview(
            MODULE.RunningProcess(process.pid, executable),
            tmp / "runtime/dist/Chengyin Companion.app",
        )
        process.wait(timeout=5)
        check(stopped and process.returncode is not None, "Verified preview exits on SIGTERM")
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)

    process = subprocess.Popen([str(executable)])
    try:
        deadline = time.monotonic() + 5
        while MODULE.process_command(process.pid) is None and time.monotonic() < deadline:
            time.sleep(0.05)
        refused = MODULE.stop_verified_preview(
            MODULE.RunningProcess(process.pid, dist_executable),
            dist_app,
        )
        check(not refused and process.poll() is None, "PID/path revalidation prevents wrong-process stop")
    finally:
        process.terminate()
        process.wait(timeout=5)

    receipt = MODULE.fail_receipt(
        MODULE.base_receipt("check-only"),
        "LOCAL_PREVIEW_PREFLIGHT_FAILED",
        "The source-only preflight failed.",
        "Run the source-only preflight and retry.",
    )
    encoded = json.dumps(receipt, ensure_ascii=False)
    check(
        raw_tmp not in encoded and "/Users/" not in encoded and "/Volumes/" not in encoded,
        "Failure receipt is path-safe",
    )
    check(
        receipt["applicationsDirectoryModified"] is False
        and receipt["networkRequired"] is False
        and receipt["providerCredentialsRequired"] is False,
        "Zero-install and offline boundaries are explicit",
    )

required_integrations = {
    ROOT / ".github/workflows/ci.yml": "run-local-preview-smoke.sh",
    ROOT / "scripts/build-portable-source.sh": "scripts/local-preview.py",
    ROOT / "scripts/audit-portable-source.py": "scripts/preview-local.sh",
    ROOT / "Schemas/error-codes-v1.json": "LOCAL_PREVIEW_BUILD_FAILED",
    ROOT / "scripts/macos_process_inspection.py": "proc_listpids",
    ROOT / "README.md": "./scripts/preview-local.sh",
    ROOT / "README.en.md": "./scripts/preview-local.sh",
}
check(
    all(marker in path.read_text(encoding="utf-8") for path, marker in required_integrations.items()),
    "CI, source package, registry and bilingual entrypoints are integrated",
)

invalid = subprocess.run(
    [str(ROOT / "scripts/preview-local.sh"), "--unsupported", "--json"],
    check=False,
    capture_output=True,
    text=True,
)
invalid_receipt = json.loads(invalid.stdout)
check(
    invalid.returncode == 1
    and invalid_receipt["code"] == "LOCAL_PREVIEW_INVALID_ARGUMENT"
    and invalid_receipt["recoveryAction"],
    "Unknown option returns a stable machine-readable failure",
)

print(f"Local preview smoke: PASS ({checks}/{checks})")
