#!/usr/bin/env python3
"""Keep bounded local-health recovery wired without destructive side effects."""

from __future__ import annotations

import json
import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def fail(message: str) -> None:
    print(f"FAIL  runtime-support integration: {message}", file=sys.stderr)
    raise SystemExit(1)


def source(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file() or path.is_symlink():
        fail(f"required regular file is missing: {relative}")
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        fail(f"required UTF-8 source is unreadable: {relative}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def main() -> int:
    core = source("Sources/CompanionContracts/CompanionRuntimeReadiness.swift")
    repairer = source("Sources/CompanionApp/CompanionEventBridgeRepair.swift")
    support = source("Sources/CompanionApp/CompanionRuntimeSupport.swift")
    coordinator = source(
        "Sources/CompanionApp/CompanionRuntimeRepairCoordinator.swift"
    )
    presentation = source(
        "Sources/CompanionApp/CompanionRuntimeReadinessPresentation.swift"
    )
    settings = source("Sources/CompanionApp/CompanionSupportDiagnosticsSection.swift")
    view_model = source("Sources/CompanionApp/CompanionViewModel.swift")
    workday_runtime = source(
        "Sources/CompanionApp/CompanionWorkdayRuntimeCoordinator.swift"
    )
    tests = source("Tests/CompanionContractsTests/main.swift")
    smoke = source("scripts/runtime-repair-smoke.swift")
    registry = set(json.loads(source("Schemas/error-codes-v1.json"))["codes"])
    doctor = source("scripts/doctor.sh")
    ci = source(".github/workflows/ci.yml")

    for claim in (
        "public enum CompanionRuntimeRecoveryAction",
        "case repairEventBridge",
        "case recoverContentLibrary",
        "public static func safeRecoveryActions",
        "public static func hasManualAttention",
        "contentLibraryHealthy",
    ):
        require(claim in core, f"Core runtime-recovery contract lost {claim}")

    for claim in ("lstat(", "O_NOFOLLOW", "fstat(", "fchmod("):
        require(claim in repairer, f"event repairer lost no-follow guard {claim}")
    for forbidden in (
        "removeItem(",
        "moveItem(",
        "replaceItemAt(",
        "URLSession",
        "NSWorkspace",
        "Process(",
    ):
        require(forbidden not in repairer, f"event repairer gained forbidden side effect {forbidden}")
    require(
        "UI_RUNTIME_REPAIR_REFUSED" in repairer
        and "UI_RUNTIME_REPAIR_FAILED" in repairer,
        "event repairer lost privacy-safe stable failures",
    )

    require(
        "CompanionRuntimeReadiness.evaluate(facts)" in support
        and "CompanionRuntimeReadiness.safeRecoveryActions(checks)" in support,
        "runtime support projection is not delegated to Core",
    )
    require(
        "CompanionRuntimeHealthSettingsSection" in settings
        and "CompanionSupportDiagnosticsSettingsSection" in settings,
        "focused settings surfaces are missing",
    )
    require(
        "private let runtimeRepair = CompanionRuntimeRepairCoordinator()" in view_model
        and "runtimeRepair.objectWillChange.sink" in view_model
        and "runtimeRepair.refresh(" in view_model
        and "runtimeRepair.repair(" in view_model
        and "runtimeRepair.rebuild(" in view_model,
        "view model lost the focused runtime-repair binding",
    )
    for claim in (
        "final class CompanionRuntimeRepairCoordinator: ObservableObject",
        "@Published private(set) var snapshot",
        "@Published private(set) var isRepairing",
        "@Published private(set) var message",
        "private var operationTask: Task<Void, Never>?",
        "workdayRuntime.repairEventBridge()",
        "recoverInterruptedInstalls()",
        "guard !Task.isCancelled",
    ):
        require(claim in coordinator, f"focused repair coordinator lost {claim}")
    for forbidden in (
        "import AppKit",
        "import SwiftUI",
        "UserDefaults",
        "NSPasteboard",
        "NSWorkspace",
        "URLSession",
        "Process(",
        "removeItem(",
        "moveItem(",
        "replaceItemAt(",
    ):
        require(
            forbidden not in coordinator,
            f"focused repair coordinator gained forbidden side effect {forbidden}",
        )
    for claim in (
        "extension CompanionViewModel",
        "var runtimeReadinessSummary: String",
        "var runtimeReadinessChecks: [CompanionRuntimeReadinessCheck]",
        "var runtimeSafeRepairAvailable: Bool",
        "func runtimeReadinessTitle(",
        "func runtimeReadinessDetail(",
    ):
        require(claim in presentation, f"readiness presentation lost {claim}")
    for forbidden in (
        "import AppKit",
        "import SwiftUI",
        "UserDefaults",
        "Task {",
        "repairEventBridge",
        "recoverInterruptedInstalls",
    ):
        require(
            forbidden not in presentation,
            f"readiness presentation gained side effect {forbidden}",
        )
    for obsolete in (
        "@Published private(set) var runtimeSupportSnapshot",
        "@Published private(set) var runtimeRepairInProgress",
        "@Published private(set) var runtimeRepairMessage",
        "private var contentLibraryHealthy",
        "var runtimeReadinessSummary: String",
        "func runtimeReadinessTitle(",
    ):
        require(obsolete not in view_model, f"runtime repair state returned to view model: {obsolete}")
    require(
        "func repairEventBridge() async" in workday_runtime
        and "watcher.repairProtocolBridge()" in workday_runtime
        and "eventBridgeReady = receipt.isReady" in workday_runtime,
        "workday runtime lost bounded event-bridge repair delegation",
    )
    for obsolete in (
        "runtimeReadinessReadyCount",
        "runtimeReadinessPausedCount",
        "runtimeReadinessAttentionCount",
        "starterContractStatus(",
    ):
        require(obsolete not in view_model, f"scattered runtime state returned: {obsolete}")

    for code in ("UI_RUNTIME_REPAIR_REFUSED", "UI_RUNTIME_REPAIR_FAILED"):
        require(code in registry, f"stable error registry lost {code}")
    for test_name in (
        "Runtime repair policy is bounded and non-destructive",
        "refused repair changed the occupying file",
        "refused repair followed the symbolic link",
    ):
        require(test_name in tests or test_name in smoke, f"repair matrix lost {test_name}")
    require(
        "check-runtime-support-integration.py" in doctor
        and "check-runtime-support-integration.py" in ci
        and "run-runtime-repair-smoke.sh" in doctor
        and "run-runtime-repair-smoke.sh" in ci,
        "Doctor or CI does not execute runtime support guards",
    )

    print(
        "PASS  runtime-support integration: Core-bounded actions, no-follow "
        "event repair, transactional library recovery, focused cancellable "
        "repair coordinator and side-effect-free diagnostics projection"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
