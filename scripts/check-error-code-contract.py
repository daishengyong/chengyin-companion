#!/usr/bin/env python3
"""Freeze the public content-pack and backup error-code inventory."""

from __future__ import annotations

import json
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "Schemas/error-codes-v1.json"
SOURCES = [
    ROOT / "Sources/CompanionApp/CompanionFailureReceipt.swift",
    ROOT / "Sources/CompanionApp/ContentPackMediaProbe.swift",
    ROOT / "Sources/CompanionApp/ContentPackRecoveryCatalog.swift",
    ROOT / "Sources/CompanionApp/ContentPackStore.swift",
    ROOT / "Sources/CompanionApp/ContentPackStoreModels.swift",
    ROOT / "Sources/CompanionApp/ContentPackArchiveImporter.swift",
    ROOT / "Sources/CompanionApp/CompanionBackupService.swift",
    ROOT / "Sources/CompanionApp/CompanionLifestyleMemoryAdapter.swift",
    ROOT / "Sources/CompanionApp/CompanionEventBridgeRepair.swift",
    ROOT / "Sources/CompanionApp/CompanionEventSpool.swift",
    ROOT / "Sources/CompanionApp/CompanionWorkdayAdapter.swift",
    ROOT / "Sources/CompanionContracts/CompanionBackup.swift",
    ROOT / "Sources/CompanionContracts/CodexAppServerMapper.swift",
    ROOT / "Sources/CompanionContracts/CompanionProjectionAuthoring.swift",
    ROOT / "scripts/content-pack-validator-cli.swift",
    ROOT / "scripts/content-pack-audit-cli.swift",
    ROOT / "scripts/content-pack-preview-cli.swift",
    ROOT / "scripts/content-pack-projection-editor-cli.swift",
    ROOT / "scripts/content-pack-migration-cli.swift",
    ROOT / "scripts/content-pack-locale-matrix-cli.swift",
    ROOT / "scripts/create-content-pack.py",
    ROOT / "scripts/content-pack-archive-audit-cli.swift",
    ROOT / "scripts/build-content-pack-archive.py",
    ROOT / "scripts/build-creator-tool.sh",
    ROOT / "scripts/build-portable-source.sh",
    ROOT / "scripts/audit-public-source-secrets.py",
    ROOT / "scripts/check-python-runtime.sh",
    ROOT / "scripts/audit-portable-source.py",
    ROOT / "scripts/bootstrap-public-git.py",
    ROOT / "scripts/audit-product-boundary.py",
    ROOT / "scripts/refresh-starter-media-manifest.py",
    ROOT / "scripts/audit-starter-media.py",
    ROOT / "scripts/audit-community-pack-index.py",
    ROOT / "scripts/audit-module-stewardship.py",
    ROOT / "scripts/audit-core-module-boundaries.py",
    ROOT / "scripts/audit-accessibility-localization.py",
    ROOT / "scripts/audit-swiftpm-package-graph.py",
    ROOT / "scripts/audit-swift-compiler-boundaries.py",
    ROOT / "scripts/check-contribution.py",
    ROOT / "scripts/apply-content-pack-projection.py",
    ROOT / "scripts/apply-content-pack-experience.py",
    ROOT / "scripts/window-presence-audit.swift",
    ROOT / "scripts/audit-local-runtime-identity.py",
    ROOT / "scripts/local-preview.py",
    ROOT / "scripts/audit-direct-play-runtime.py",
    ROOT / "scripts/direct-play-window-audit.swift",
    ROOT / "scripts/english-first-use-visual-audit.swift",
    ROOT / "scripts/playback-media-soak.swift",
]
CODE_PATTERN = re.compile(
        r'"((?:(?:ACCESSIBILITY|APP_SERVER|PACK|BACKUP|CARE|COMMUNITY|CONTRIBUTOR|CORE|CREATOR|EVENT|EXPERIENCE|FIRST_USE|LOCAL|PLAYBACK|PRODUCT_BOUNDARY|PROJECTION|PUBLIC_GIT|SOURCE|STARTER|STEWARDSHIP|SWIFT_COMPILER_BOUNDARY|UI|WORKDAY)|SWIFTPM_GRAPH)_[A-Z0-9_]*[A-Z0-9])"'
)


def main() -> int:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    if registry.get("schemaVersion") != 1:
        print("FAIL  unsupported error-code registry schema", file=sys.stderr)
        return 1
    registered = registry.get("codes")
    if not isinstance(registered, list) or not all(
        isinstance(code, str) for code in registered
    ):
        print("FAIL  error-code registry must contain a string array", file=sys.stderr)
        return 1
    if registered != sorted(registered):
        print("FAIL  error-code registry is not sorted", file=sys.stderr)
        return 1
    if len(registered) != len(set(registered)):
        print("FAIL  error-code registry contains duplicates", file=sys.stderr)
        return 1

    implemented: set[str] = set()
    for source in SOURCES:
        implemented.update(
            CODE_PATTERN.findall(source.read_text(encoding="utf-8"))
        )

    missing = sorted(set(registered) - implemented)
    unregistered = sorted(implemented - set(registered))
    if missing or unregistered:
        if missing:
            print("FAIL  registered but not implemented: " + ", ".join(missing))
        if unregistered:
            print("FAIL  implemented but not registered: " + ", ".join(unregistered))
        return 1

    print(f"PASS  stable error-code contract: {len(registered)} registered codes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
