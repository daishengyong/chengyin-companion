#!/usr/bin/env python3
"""Keep the bounded no-follow Companion Event inbox wired end to end."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def source(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file() or path.is_symlink():
        raise SystemExit(f"FAIL  event spool integration: required source is missing: {relative}")
    return path.read_text(encoding="utf-8")


def require_all(text: str, claims: tuple[str, ...], boundary: str) -> None:
    missing = [claim for claim in claims if claim not in text]
    if missing:
        raise SystemExit(
            "FAIL  event spool integration: "
            f"{boundary} lost {missing[0]}"
        )


def main() -> None:
    spool = source("Sources/CompanionApp/CompanionEventSpool.swift")
    ingress = source("Sources/CompanionApp/CompanionEventIngress.swift")
    watcher = source("Sources/CompanionApp/CompanionEventWatcher.swift")
    signal_trust = source(
        "Sources/CompanionContracts/CompanionWorkdaySignalTrustPolicy.swift"
    )
    runtime = source("Sources/CompanionApp/CompanionWorkdayRuntimeCoordinator.swift")
    diagnostics = source("Sources/CompanionApp/CompanionDiagnostics.swift")
    smoke = source("scripts/event-spool-smoke.swift")
    workday_smoke = source("scripts/workday-runtime-coordinator-smoke.swift")
    registry = json.loads(source("Schemas/error-codes-v1.json"))

    require_all(
        spool,
        (
            "O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC",
            "Darwin.openat(",
            "O_NONBLOCK",
            "fstat(descriptor",
            "fstatat(",
            "AT_SYMLINK_NOFOLLOW",
            "unlinkat(",
            "state.st_uid == geteuid()",
            "state.st_nlink == 1",
            "mode_t(0o700)",
            "mode_t(0o600)",
            "defaultMaximumRetainedFiles = 512",
            "defaultMaximumDirectoryEntries = 4_096",
            "defaultMaximumAge: TimeInterval = 36 * 60 * 60",
            "CompanionEventCodec.maximumPayloadBytes",
            "do not claim to defeat another active",
        ),
        "descriptor and retention contract",
    )
    for forbidden in ("URLSession", "NSWorkspace", "Process(", "Data(contentsOf:"):
        if forbidden in spool:
            raise SystemExit(
                "FAIL  event spool integration: the event inbox gained an unsafe side channel"
            )

    require_all(
        ingress,
        (
            "struct CodexTaskSignal: Sendable, Equatable",
            "enum CodexProtocolEventExtractor",
            "CompanionWorkdaySignalSourcePolicy.origin(",
            "CompanionWorkdaySignalTrustPolicy.effectiveType(",
            "privacySafeTaskReference",
            "maximumRetainedDurationMs",
        ),
        "privacy-minimal ingress projection",
    )
    for forbidden in ("FileManager", "FileHandle", "URLSession", "NSWorkspace", "Process("):
        if forbidden in ingress:
            raise SystemExit(
                "FAIL  event spool integration: event ingress gained transport or process capability"
            )

    require_all(
        watcher,
        (
            "eventSpool.scan(root: protocolRoot",
            "signal.id.caseInsensitiveCompare(entry.eventID)",
            "deliveredProtocolIDOrder.count > 512",
            "pollWithHealth(now: Date = Date())",
            "legacySessionsEnabled: Bool = false",
            "primeProtocolInbox()",
            "private var primedSignals: [CodexTaskSignal] = []",
            "startedAt: .distantPast",
            "if signal.occurredAt >= startedAt",
        ),
        "watcher binding and deduplication",
    )
    require_all(
        signal_trust,
        (
            '("codex-skill", "terminal-events-v1")',
            '("codex-app-server", "turn-events-v1")',
            "case (.taskCompleted, .success, .companionTerminalEmitter)",
            "case (.taskCompleted, _, _)",
        ),
        "producer/version terminal trust",
    )
    if "Data(contentsOf:" in watcher:
        raise SystemExit(
            "FAIL  event spool integration: the explicit inbox bypasses descriptor reads"
        )

    require_all(
        runtime,
        (
            "@Published private(set) var eventBridgeCode: String?",
            "let receipt = await watcher.pollWithHealth()",
            ".integrationDisconnected",
            ".integrationHealth",
            "applyEventBridgeHealth(receipt.eventBridgeHealth)",
            "onReadinessChanged()",
        ),
        "live runtime health projection",
    )
    require_all(
        diagnostics,
        (
            "let eventBridgeStatusCode: String?",
            "Codex event bridge:",
            r"attention [\(safe(eventBridgeStatusCode))]",
            "excludes user names, file paths, Codex sessions, task text",
        ),
        "privacy-minimal diagnostics",
    )
    require_all(
        smoke,
        (
            "createSymbolicLink",
            "Darwin.link(",
            "Darwin.mkfifo",
            "maximumPayloadBytes + 1",
            "stalePruning",
            "capacityPruning",
            "directoryLimit",
            "rootHealth",
            "linked target changed",
        ),
        "hostile-entry and retention matrix",
    )
    require_all(
        workday_smoke,
        (
            "EVENT_SPOOL_ROOT_UNSAFE",
            "integrationDisconnected",
            "integrationHealthy",
            "readinessChanges == readinessBeforeHealth + 2",
            'sourceVersion: "terminal-events-v1"',
        ),
        "live unhealthy/repaired transition matrix",
    )

    codes = set(registry.get("codes", []))
    required_codes = {
        "EVENT_SPOOL_ROOT_UNAVAILABLE",
        "EVENT_SPOOL_ROOT_UNSAFE",
        "EVENT_SPOOL_ENTRY_LIMIT_EXCEEDED",
    }
    if not required_codes <= codes:
        raise SystemExit("FAIL  event spool integration: stable spool codes are unregistered")

    integration_claims = {
        ".github/workflows/ci.yml": (
            "check-event-spool-integration.py",
            "run-event-spool-smoke.sh",
        ),
        "scripts/doctor.sh": (
            "check-event-spool-integration.py",
            "run-event-spool-smoke.sh",
        ),
        "scripts/check-contribution.py": ("event-spool-security",),
        "scripts/build-portable-source.sh": (
            "CompanionEventSpool.swift",
            "CompanionEventIngress.swift",
            "CompanionEventWatcher.swift",
            "EVENT-SPOOL-SECURITY.md",
            "check-event-spool-integration.py",
            "run-event-spool-smoke.sh",
        ),
        "scripts/audit-portable-source.py": (
            "CompanionEventSpool.swift",
            "CompanionEventIngress.swift",
            "CompanionEventWatcher.swift",
            "EVENT-SPOOL-SECURITY.md",
            "check-event-spool-integration.py",
            "run-event-spool-smoke.sh",
        ),
        "scripts/run-portable-source-smoke.sh": (
            "event-spool-integration",
            "event-spool-security",
        ),
        "community/module-stewardship.json": (
            "event-spool-security",
            "Sources/CompanionApp/CompanionEventSpool.swift",
            "Sources/CompanionApp/CompanionEventIngress.swift",
            "Sources/CompanionApp/CompanionEventWatcher.swift",
        ),
    }
    for relative, claims in integration_claims.items():
        require_all(source(relative), claims, relative)

    for relative in (
        "docs/EVENT-SPOOL-SECURITY.md",
        "docs/EVENT-SPOOL-SECURITY.zh-Hans.md",
    ):
        document = source(relative)
        require_all(
            document,
            (
                "./scripts/run-event-spool-smoke.sh",
                "python3 scripts/check-event-spool-integration.py",
                "NOT_PUBLIC_RELEASE_READY",
            ),
            relative,
        )

    print(
        "PASS  event spool integration: bounded descriptor inbox, filename/content "
        "binding, live health recovery, path-free diagnostics, hostile-entry matrix, "
        "and clone/contribution gates; proofStrength=source-token-and-runtime-smoke-"
        "not-active-same-user-attack-proof"
    )


if __name__ == "__main__":
    main()
