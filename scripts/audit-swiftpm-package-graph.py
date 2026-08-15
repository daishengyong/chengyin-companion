#!/usr/bin/env python3
"""Audit Chengyin's evaluated SwiftPM package graph without network access."""

from __future__ import annotations

import json
import os
import pathlib
import subprocess
import sys
import tempfile


CONTRACT = "chengyin.swiftpm-package-graph/v1"
DEFAULT_ROOT = pathlib.Path(__file__).resolve().parent.parent
EXPECTED_PRODUCTS = {
    "ChengyinCompanion": ("executable", ("CompanionApp",)),
    "CompanionContracts": ("library", ("CompanionContracts",)),
    "CompanionContractChecks": ("executable", ("CompanionContractChecks",)),
    "CompanionEventEmitter": ("executable", ("CompanionEventEmitter",)),
}
EXPECTED_TARGETS = {
    "CompanionContracts": {
        "type": "regular",
        "path": "Sources/CompanionContracts",
        "dependencies": (),
    },
    "CompanionApp": {
        "type": "executable",
        "path": "Sources/CompanionApp",
        "dependencies": ("CompanionContracts",),
    },
    "CompanionContractChecks": {
        "type": "executable",
        "path": "Tests/CompanionContractsTests",
        "dependencies": ("CompanionContracts",),
    },
    "CompanionEventEmitter": {
        "type": "executable",
        "path": "Tools/CompanionEventEmitter",
        "dependencies": ("CompanionContracts",),
    },
}
TOOLCHAIN_ENV = DEFAULT_ROOT / "scripts/swift-toolchain-env.sh"


class GraphFailure(Exception):
    def __init__(self, code: str, message: str, recovery: str):
        super().__init__(message)
        self.code = code
        self.message = message
        self.recovery = recovery


def fail(code: str, message: str, recovery: str) -> None:
    raise GraphFailure(code, message, recovery)


def configured_toolchain_environment() -> dict[str, str]:
    if not TOOLCHAIN_ENV.is_file() or TOOLCHAIN_ENV.is_symlink():
        fail(
            "SWIFTPM_GRAPH_EVALUATION_FAILED",
            "The shared Swift toolchain preflight is missing or unsafe.",
            "Restore scripts/swift-toolchain-env.sh and rerun the source preflight.",
        )
    try:
        completed = subprocess.run(
            [
                "/bin/bash",
                "-c",
                'source "$1" >/dev/null 2>&1 && /usr/bin/env -0',
                "chengyin-swiftpm-graph",
                str(TOOLCHAIN_ENV),
            ],
            check=False,
            capture_output=True,
            timeout=60,
        )
    except (OSError, subprocess.SubprocessError):
        fail(
            "SWIFTPM_GRAPH_EVALUATION_FAILED",
            "The shared Swift toolchain preflight could not run.",
            "Repair Command Line Tools and rerun the source preflight.",
        )
    if completed.returncode != 0:
        fail(
            "SWIFTPM_GRAPH_EVALUATION_FAILED",
            "The shared Swift toolchain preflight rejected the active toolchain.",
            "Repair Command Line Tools and rerun the source preflight.",
        )
    environment: dict[str, str] = {}
    for entry in completed.stdout.split(b"\0"):
        if not entry or b"=" not in entry:
            continue
        key, value = entry.split(b"=", 1)
        environment[os.fsdecode(key)] = os.fsdecode(value)
    if not environment.get("SDKROOT"):
        fail(
            "SWIFTPM_GRAPH_EVALUATION_FAILED",
            "The shared Swift toolchain preflight returned no compatible SDK.",
            "Repair Command Line Tools and rerun the source preflight.",
        )
    return environment


def evaluated_manifest(root: pathlib.Path) -> tuple[dict[str, object], bool, bool]:
    manifest = root / "Package.swift"
    if not manifest.is_file() or manifest.is_symlink():
        fail(
            "SWIFTPM_GRAPH_MANIFEST_MISSING",
            "The SwiftPM manifest is missing or unsafe.",
            "Restore the tracked regular Package.swift file and retry.",
        )
    environment = configured_toolchain_environment()
    try:
        swift = subprocess.run(
            ["/usr/bin/xcrun", "--find", "swift"],
            check=True,
            capture_output=True,
            text=True,
            timeout=15,
            env=environment,
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        fail(
            "SWIFTPM_GRAPH_EVALUATION_FAILED",
            "A compatible local Swift toolchain could not be selected.",
            "Run the source preflight, repair Command Line Tools, and retry.",
        )
    try:
        with tempfile.TemporaryDirectory(prefix="chengyin-swiftpm-graph-") as temporary:
            temp = pathlib.Path(temporary).resolve()
            module_cache = temp / "module-cache"
            clang_cache = temp / "clang-cache"
            for directory in (module_cache, clang_cache):
                directory.mkdir(parents=True)
            command = [
                swift,
                "package",
                "--package-path",
                str(root),
                "--scratch-path",
                str(temp / "scratch"),
                "--cache-path",
                str(temp / "cache"),
                "--config-path",
                str(temp / "config"),
                "--security-path",
                str(temp / "security"),
                "--disable-dependency-cache",
                "--manifest-cache",
                "none",
                "--disable-netrc",
                "--disable-keychain",
                "--disable-automatic-resolution",
                "dump-package",
            ]
            environment["TMPDIR"] = str(temp)
            environment["SWIFTPM_MODULECACHE_OVERRIDE"] = str(module_cache)
            environment["CLANG_MODULE_CACHE_PATH"] = str(clang_cache)
            result = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
                timeout=60,
                env=environment,
            )
            manifest_sandboxed = True
            outer_sandbox_fallback = False
            nested_sandbox_denied = (
                result.returncode != 0
                and "sandbox-exec: sandbox_apply: Operation not permitted"
                in result.stderr
            )
            if nested_sandbox_denied and environment.get("CODEX_SANDBOX"):
                retry_command = command.copy()
                retry_command.insert(2, "--disable-sandbox")
                result = subprocess.run(
                    retry_command,
                    check=False,
                    capture_output=True,
                    text=True,
                    timeout=60,
                    env=environment,
                )
                manifest_sandboxed = False
                outer_sandbox_fallback = True
    except (OSError, subprocess.SubprocessError):
        fail(
            "SWIFTPM_GRAPH_EVALUATION_FAILED",
            "SwiftPM could not evaluate the local package manifest.",
            "Run the source preflight, correct Package.swift, and retry.",
        )
    if result.returncode != 0:
        fail(
            "SWIFTPM_GRAPH_EVALUATION_FAILED",
            "SwiftPM rejected the local package manifest.",
            "Correct Package.swift with a compatible local toolchain and retry.",
        )
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        fail(
            "SWIFTPM_GRAPH_EVALUATION_FAILED",
            "SwiftPM returned an unreadable package graph.",
            "Repair the local Swift toolchain and rerun the source preflight.",
        )
    if not isinstance(payload, dict):
        fail(
            "SWIFTPM_GRAPH_EVALUATION_FAILED",
            "SwiftPM returned an unsupported package graph.",
            "Use the documented Swift toolchain and retry.",
        )
    return payload, manifest_sandboxed, outer_sandbox_fallback


def dependency_name(value: object) -> str | None:
    if not isinstance(value, dict) or set(value) != {"byName"}:
        return None
    by_name = value.get("byName")
    if (
        not isinstance(by_name, list)
        or len(by_name) != 2
        or not isinstance(by_name[0], str)
        or by_name[1] is not None
    ):
        return None
    return by_name[0]


def product_kind(value: object) -> str | None:
    if not isinstance(value, dict) or len(value) != 1:
        return None
    if "executable" in value and value["executable"] is None:
        return "executable"
    library = value.get("library")
    if isinstance(library, list) and library == ["automatic"]:
        return "library"
    return None


def audit(root: pathlib.Path) -> dict[str, object]:
    graph, manifest_sandboxed, outer_sandbox_fallback = evaluated_manifest(root)
    tools = graph.get("toolsVersion")
    if (
        graph.get("name") != "ChengyinCompanion"
        or graph.get("defaultLocalization") != "zh-Hans"
        or not isinstance(tools, dict)
        or tools.get("_version") != "5.10.0"
    ):
        fail(
            "SWIFTPM_GRAPH_PLATFORM_DRIFT",
            "The evaluated package identity, tools version, or default locale drifted.",
            "Restore the documented package identity, Swift tools 5.10, and zh-Hans default locale.",
        )
    platforms = graph.get("platforms")
    if (
        not isinstance(platforms, list)
        or len(platforms) != 1
        or not isinstance(platforms[0], dict)
        or platforms[0].get("platformName") != "macos"
        or platforms[0].get("version") != "14.0"
    ):
        fail(
            "SWIFTPM_GRAPH_PLATFORM_DRIFT",
            "The evaluated package no longer has the supported macOS 14 platform boundary.",
            "Restore the reviewed macOS 14 package platform declaration and retry.",
        )
    dependencies = graph.get("dependencies")
    if not isinstance(dependencies, list):
        fail(
            "SWIFTPM_GRAPH_EVALUATION_FAILED",
            "The evaluated package dependency graph is malformed.",
            "Repair the SwiftPM manifest and retry.",
        )
    if dependencies:
        fail(
            "SWIFTPM_GRAPH_EXTERNAL_DEPENDENCY",
            "The local-first package introduced an external package dependency.",
            "Remove the external dependency or complete a separately reviewed architecture and supply-chain change.",
        )

    products = graph.get("products")
    if not isinstance(products, list) or len(products) != len(EXPECTED_PRODUCTS):
        fail(
            "SWIFTPM_GRAPH_PRODUCT_DRIFT",
            "The evaluated SwiftPM product set changed.",
            "Restore the four reviewed products or document and review a compatibility migration.",
        )
    observed_products: dict[str, tuple[str | None, tuple[str, ...]]] = {}
    for product in products:
        if not isinstance(product, dict) or not isinstance(product.get("name"), str):
            fail(
                "SWIFTPM_GRAPH_PRODUCT_DRIFT",
                "The evaluated SwiftPM product graph is malformed.",
                "Repair the product declarations and retry.",
            )
        targets = product.get("targets")
        if not isinstance(targets, list) or not all(isinstance(item, str) for item in targets):
            fail(
                "SWIFTPM_GRAPH_PRODUCT_DRIFT",
                "A product has an invalid target projection.",
                "Restore the reviewed product-to-target mapping and retry.",
            )
        observed_products[product["name"]] = (
            product_kind(product.get("type")),
            tuple(targets),
        )
    if observed_products != EXPECTED_PRODUCTS:
        fail(
            "SWIFTPM_GRAPH_PRODUCT_DRIFT",
            "The evaluated product type or target projection changed.",
            "Restore the reviewed product graph or document and review a compatibility migration.",
        )

    targets = graph.get("targets")
    if not isinstance(targets, list) or len(targets) != len(EXPECTED_TARGETS):
        fail(
            "SWIFTPM_GRAPH_TARGET_DRIFT",
            "The evaluated SwiftPM target set changed.",
            "Restore the four reviewed targets or complete a separately reviewed module migration.",
        )
    observed_targets: dict[str, dict[str, object]] = {}
    for target in targets:
        if not isinstance(target, dict) or not isinstance(target.get("name"), str):
            fail(
                "SWIFTPM_GRAPH_TARGET_DRIFT",
                "The evaluated SwiftPM target graph is malformed.",
                "Repair the target declarations and retry.",
            )
        raw_dependencies = target.get("dependencies")
        if not isinstance(raw_dependencies, list):
            fail(
                "SWIFTPM_GRAPH_DEPENDENCY_VIOLATION",
                "A target has an unreadable dependency projection.",
                "Restore by-name dependencies to CompanionContracts only and retry.",
            )
        names = tuple(dependency_name(item) or "" for item in raw_dependencies)
        if any(not name for name in names):
            fail(
                "SWIFTPM_GRAPH_DEPENDENCY_VIOLATION",
                "A target introduced a non-reviewed dependency kind.",
                "Use only the reviewed by-name CompanionContracts edges and retry.",
            )
        observed_targets[target["name"]] = {
            "type": target.get("type"),
            "path": target.get("path"),
            "dependencies": names,
            "resources": target.get("resources"),
            "settings": target.get("settings"),
        }
    if set(observed_targets) != set(EXPECTED_TARGETS):
        fail(
            "SWIFTPM_GRAPH_TARGET_DRIFT",
            "The evaluated SwiftPM target identities changed.",
            "Restore the reviewed target names or complete a separately reviewed module migration.",
        )
    for name, expected in EXPECTED_TARGETS.items():
        observed = observed_targets[name]
        if observed["type"] != expected["type"] or observed["path"] != expected["path"]:
            fail(
                "SWIFTPM_GRAPH_TARGET_DRIFT",
                "A target type or source root changed.",
                "Restore the reviewed regular source root and target kind, then retry.",
            )
        if observed["dependencies"] != expected["dependencies"]:
            fail(
                "SWIFTPM_GRAPH_DEPENDENCY_VIOLATION",
                "A target lost or bypassed the one-way CompanionContracts dependency boundary.",
                "Keep Core dependency-free and bind each executable to CompanionContracts only.",
            )

    for name in ("CompanionContracts", "CompanionContractChecks", "CompanionEventEmitter"):
        if observed_targets[name]["resources"] != []:
            fail(
                "SWIFTPM_GRAPH_RESOURCE_DRIFT",
                "A non-App target introduced a resource-processing surface.",
                "Keep resources in CompanionApp and deterministic contracts resource-free.",
            )
        if observed_targets[name]["settings"] != []:
            fail(
                "SWIFTPM_GRAPH_SETTING_VIOLATION",
                "A Core, check, or emitter target introduced compiler settings.",
                "Remove the unreviewed target setting or complete a separately reviewed architecture change.",
            )

    app_resources = observed_targets["CompanionApp"]["resources"]
    if (
        not isinstance(app_resources, list)
        or len(app_resources) != 1
        or not isinstance(app_resources[0], dict)
        or app_resources[0].get("path") != "Resources"
        or app_resources[0].get("rule") != {"process": {}}
    ):
        fail(
            "SWIFTPM_GRAPH_RESOURCE_DRIFT",
            "The App resource-processing root or rule changed.",
            "Restore the single processed Resources root and retry.",
        )
    app_settings = observed_targets["CompanionApp"]["settings"]
    if (
        not isinstance(app_settings, list)
        or len(app_settings) != 1
        or not isinstance(app_settings[0], dict)
        or app_settings[0].get("condition")
        != {"config": "debug", "platformNames": []}
        or app_settings[0].get("kind")
        != {"unsafeFlags": {"_0": ["-Xfrontend", "-warn-concurrency"]}}
        or app_settings[0].get("tool") != "swift"
    ):
        fail(
            "SWIFTPM_GRAPH_SETTING_VIOLATION",
            "The App compiler-setting contract changed.",
            "Restore the debug-only concurrency warning setting or review the toolchain change separately.",
        )

    return {
        "schemaVersion": 1,
        "contract": CONTRACT,
        "status": "PASS",
        "code": None,
        "message": "The evaluated local SwiftPM package graph matches the reviewed module boundary.",
        "recoveryAction": None,
        "packageName": "ChengyinCompanion",
        "toolsVersion": "5.10.0",
        "defaultLocalization": "zh-Hans",
        "minimumMacOSVersion": "14.0",
        "productCount": len(EXPECTED_PRODUCTS),
        "targetCount": len(EXPECTED_TARGETS),
        "externalDependencyCount": 0,
        "coreTargetDependencyCount": 0,
        "appTargetDependencies": ["CompanionContracts"],
        "resourceRuleCount": 1,
        "networkRequired": False,
        "manifestSandboxed": manifest_sandboxed,
        "outerSandboxFallback": outer_sandbox_fallback,
        "proofStrength": (
            "codex-outer-sandbox-evaluated-swiftpm-manifest-graph-not-compiler-ast-or-external-resolution"
            if outer_sandbox_fallback
            else "swiftpm-sandboxed-evaluated-manifest-graph-not-compiler-ast-or-external-resolution"
        ),
        "releaseState": "NOT_PUBLIC_RELEASE_READY",
    }


def failure_receipt(error: GraphFailure) -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "contract": CONTRACT,
        "status": "FAIL",
        "code": error.code,
        "message": error.message,
        "recoveryAction": error.recovery,
        "proofStrength": "evaluated-swiftpm-manifest-graph-not-compiler-ast-or-external-resolution",
        "releaseState": "NOT_PUBLIC_RELEASE_READY",
    }


def parse_arguments(arguments: list[str]) -> tuple[pathlib.Path, bool]:
    root = DEFAULT_ROOT
    json_output = False
    index = 0
    while index < len(arguments):
        argument = arguments[index]
        if argument == "--json":
            json_output = True
        elif argument == "--root" and index + 1 < len(arguments):
            index += 1
            root = pathlib.Path(arguments[index])
        elif argument in {"--help", "-h"}:
            print("Usage: audit-swiftpm-package-graph.py [--root DIR] [--json]")
            raise SystemExit(0)
        else:
            fail(
                "SWIFTPM_GRAPH_INVALID_ARGUMENT",
                "The SwiftPM graph audit received an unsupported argument.",
                "Use only --root DIR and --json, then retry.",
            )
        index += 1
    if not root.is_dir() or root.is_symlink():
        fail(
            "SWIFTPM_GRAPH_INVALID_ARGUMENT",
            "The SwiftPM graph audit root is missing or unsafe.",
            "Provide a regular extracted project directory and retry.",
        )
    return root, json_output


def render(receipt: dict[str, object], json_output: bool) -> None:
    if json_output:
        print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
        return
    if receipt["status"] == "PASS":
        print(
            "PASS  evaluated SwiftPM graph: "
            f"{receipt['targetCount']} targets, {receipt['productCount']} products, "
            "0 external dependencies"
        )
    else:
        print(f"FAIL  {receipt['code']}: {receipt['message']}", file=sys.stderr)
        print(f"RECOVERY  {receipt['recoveryAction']}", file=sys.stderr)


def main() -> int:
    json_output = "--json" in sys.argv[1:]
    try:
        root, json_output = parse_arguments(sys.argv[1:])
        receipt = audit(root)
    except GraphFailure as error:
        receipt = failure_receipt(error)
        render(receipt, json_output)
        return 1
    except Exception:
        receipt = failure_receipt(
            GraphFailure(
                "SWIFTPM_GRAPH_UNEXPECTED_ERROR",
                "The SwiftPM graph audit encountered an unexpected local error.",
                "Run the source preflight, restore the tracked manifest, and retry.",
            )
        )
        render(receipt, json_output)
        return 1
    render(receipt, json_output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
