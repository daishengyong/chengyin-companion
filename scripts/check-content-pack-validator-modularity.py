#!/usr/bin/env python3
"""Keep the untrusted content-pack validator split by capability."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def fail(message: str) -> None:
    print(f"FAIL  content-pack validator modularity: {message}", file=sys.stderr)
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
    orchestrator = source("Sources/CompanionApp/ContentPack.swift")
    raw_fields = source(
        "Sources/CompanionApp/ContentPackManifestFieldValidator.swift"
    )
    contribution = source(
        "Sources/CompanionApp/ContentPackContributionValidator.swift"
    )
    contribution_support = source(
        "Sources/CompanionApp/ContentPackContributionValidationSupport.swift"
    )
    rights = source("Sources/CompanionApp/ContentPackRightsValidator.swift")
    accessibility = source(
        "Sources/CompanionApp/ContentPackAccessibilityValidator.swift"
    )
    fallback = source("Sources/CompanionApp/ContentPackFallbackValidator.swift")
    package_contents = source(
        "Sources/CompanionApp/ContentPackPackageContentsValidator.swift"
    )
    asset_files = source("Sources/CompanionApp/ContentPackAssetFileValidator.swift")
    asset_projection = source(
        "Sources/CompanionApp/ContentPackAssetProjectionValidator.swift"
    )
    assets = source("Sources/CompanionApp/ContentPackAssetValidator.swift")
    architecture = source("docs/CONTRIBUTOR-ARCHITECTURE.md")
    boundary = source("scripts/audit-core-module-boundaries.py")
    content_smoke = source("scripts/run-content-pack-smoke.sh")
    creator_builder = source("scripts/build-creator-tool.sh")
    doctor = source("scripts/doctor.sh")
    ci = source(".github/workflows/ci.yml")
    portable = source("scripts/run-portable-source-smoke.sh")
    source_builder = source("scripts/build-portable-source.sh")
    source_auditor = source("scripts/audit-portable-source.py")

    for claim in (
        "ContentPackManifestFieldValidator.validate(manifestData)",
        "ContentPackContributionValidator().validate(",
        "ContentPackAssetValidator(fileManager: fileManager)",
        "assetValidator.validate(asset, packageRoot: root)",
        "assetValidator.validatePackageContents(",
    ):
        require(claim in orchestrator, f"orchestrator lost delegation: {claim}")
    for forbidden in (
        "JSONSerialization.jsonObject",
        "unknownManifestField",
        "privatePathInContribution",
        "strictRightsMetadataMissing",
        "strictAccessibilityMetadataMissing",
        "strictFallbackMetadataMissing",
        "resourceValues(",
        "isExecutableFile(",
        "safeAreaNotVisible",
    ):
        require(forbidden not in orchestrator, f"orchestrator reabsorbed policy: {forbidden}")
    require(len(orchestrator.splitlines()) <= 420, "orchestrator exceeded its 420-line budget")

    for claim in (
        "JSONSerialization.jsonObject",
        "unknownManifestField",
        "rejectUnknownKeys(",
        '"<invalid-key>"',
    ):
        require(claim in raw_fields, f"raw-field validator lost {claim}")
    require(len(raw_fields.splitlines()) <= 240, "raw-field validator exceeded its 240-line budget")

    for claim in (
        "private let rightsValidator = ContentPackRightsValidator()",
        "private let accessibilityValidator = ContentPackAccessibilityValidator()",
        "private let fallbackValidator = ContentPackFallbackValidator()",
        "try rightsValidator.validate(",
        "try accessibilityValidator.validate(",
        "try fallbackValidator.validate(",
    ):
        require(claim in contribution, f"contribution orchestrator lost {claim}")
    for forbidden in (
        "strictPackageMetadataMissing",
        "strictRightsMetadataMissing",
        "strictAccessibilityMetadataMissing",
        "strictFallbackMetadataMissing",
        "privatePathInContribution",
        "invalidAssetFallback",
    ):
        require(forbidden not in contribution, f"contribution orchestrator reabsorbed {forbidden}")
    require(len(contribution.splitlines()) <= 100, "contribution orchestrator exceeded its 100-line budget")

    for label, text, budget, claims in (
        (
            "shared contribution field policy",
            contribution_support,
            180,
            (
                "privatePathInContribution",
                "invalidPackageContributionField",
                "invalidRightsField",
                "invalidAccessibilityField",
                "evidenceIdentifierPattern",
            ),
        ),
        (
            "rights validator",
            rights,
            240,
            (
                "strictPackageMetadataMissing",
                "strictRightsMetadataMissing",
                "validatePackageProvenance(",
                "validateStrictRights(",
            ),
        ),
        (
            "accessibility validator",
            accessibility,
            240,
            (
                "strictAccessibilityMetadataMissing",
                "validateStrictAccessibility(",
                "validateLocalizedAccessibility(",
            ),
        ),
        (
            "fallback validator",
            fallback,
            80,
            (
                "strictFallbackMetadataMissing",
                "invalidAssetFallback",
                "duplicateFallbackAsset",
            ),
        ),
    ):
        for claim in claims:
            require(claim in text, f"{label} lost {claim}")
        require(len(text.splitlines()) <= budget, f"{label} exceeded its {budget}-line budget")

    for claim in (
        "private let packageContentsValidator: ContentPackPackageContentsValidator",
        "private let assetFileValidator: ContentPackAssetFileValidator",
        "private let projectionValidator = ContentPackAssetProjectionValidator()",
        "try packageContentsValidator.validate(",
        "try assetFileValidator.validate(asset, packageRoot: packageRoot)",
        "try projectionValidator.validate(asset)",
    ):
        require(claim in assets, f"asset dispatcher lost {claim}")
    for forbidden in (
        "fileManager.enumerator(", "hardLinkNotAllowed", "isExecutableFile(",
        "ContentPackValidator.sha256(", "safeAreaNotVisible", "validateFocalTracks(",
    ):
        require(forbidden not in assets, f"asset dispatcher reabsorbed {forbidden}")
    require(len(assets.splitlines()) <= 80, "asset dispatcher exceeded its 80-line budget")

    for label, text, budget, claims in (
        (
            "package-contents validator",
            package_contents,
            140,
            (
                "fileManager.enumerator(", "hiddenPathNotAllowed",
                "caseInsensitivePathCollision", "symbolicLinkNotAllowed",
                "hardLinkNotAllowed", "undeclaredFile", "maximumFileCount",
                "maximumUnpackedBytes",
            ),
        ),
        (
            "asset-file validator",
            asset_files,
            140,
            (
                "invalidAssetPath", "resolvingSymlinksInPath", "fileExists(",
                "maximumSingleAssetBytes", "isExecutableFile(",
                "ContentPackValidator.sha256(", "hashMismatch",
            ),
        ),
        (
            "asset-projection validator",
            asset_projection,
            220,
            (
                "invalidVideoMetadata", "maximumMediaDurationMs",
                "invalidCropAnchor", "validateFocalTracks(",
                "validateSafeAreas(", "safeAreaNotVisible",
                "ContentPackTriggerContract.isAllowed",
            ),
        ),
    ):
        for claim in claims:
            require(claim in text, f"{label} lost {claim}")
        require(len(text.splitlines()) <= budget, f"{label} exceeded its {budget}-line budget")

    for label, text in (
        ("raw-field validator", raw_fields),
        ("contribution orchestrator", contribution),
        ("shared contribution field policy", contribution_support),
        ("rights validator", rights),
        ("accessibility validator", accessibility),
        ("fallback validator", fallback),
        ("package-contents validator", package_contents),
        ("asset-file validator", asset_files),
        ("asset-projection validator", asset_projection),
        ("asset dispatcher", assets),
    ):
        for forbidden in (
            "URLSession", "import Network", "import SwiftUI", "import AppKit",
            "import AVFoundation", "UserDefaults", "Process(", "NSWorkspace",
            "Task {", "Task<",
        ):
            require(forbidden not in text, f"{label} gained unrelated capability: {forbidden}")
    for label, text in (
        ("raw-field validator", raw_fields),
        ("contribution orchestrator", contribution),
        ("shared contribution field policy", contribution_support),
        ("rights validator", rights),
        ("accessibility validator", accessibility),
        ("fallback validator", fallback),
    ):
        for forbidden in ("FileManager", "Data(contentsOf:", "resourceValues(", "sha256("):
            require(forbidden not in text, f"{label} gained filesystem/hash capability: {forbidden}")
    for forbidden in (
        "FileManager", "Data(contentsOf:", "resourceValues(", "sha256(",
        "fileExists(", "isExecutableFile(",
    ):
        require(
            forbidden not in asset_projection,
            f"asset-projection validator gained filesystem/hash capability: {forbidden}",
        )
    for forbidden in (
        "safeAreaNotVisible", "invalidFocalTrack", "invalidCropAnchor",
        "ContentPackTriggerContract.isAllowed", "maximumMediaDurationMs",
    ):
        require(
            forbidden not in package_contents and forbidden not in asset_files,
            f"filesystem validator reabsorbed projection policy: {forbidden}",
        )
    for forbidden in (
        "fileManager.enumerator(", "maximumFileCount", "maximumUnpackedBytes",
        "undeclaredFile", "hardLinkNotAllowed",
    ):
        require(
            forbidden not in asset_files,
            f"asset-file validator reabsorbed package enumeration: {forbidden}",
        )
    for forbidden in (
        "ContentPackValidator.sha256(", "hashMismatch", "isExecutableFile(",
        "maximumSingleAssetBytes",
    ):
        require(
            forbidden not in package_contents,
            f"package-contents validator reabsorbed asset authentication: {forbidden}",
        )

    for required in (
        "ContentPackManifestFieldValidator.swift",
        "ContentPackContributionValidationSupport.swift",
        "ContentPackRightsValidator.swift",
        "ContentPackAccessibilityValidator.swift",
        "ContentPackFallbackValidator.swift",
        "ContentPackContributionValidator.swift",
        "ContentPackPackageContentsValidator.swift",
        "ContentPackAssetFileValidator.swift",
        "ContentPackAssetProjectionValidator.swift",
        "ContentPackAssetValidator.swift",
    ):
        require(required in architecture, f"contributor architecture omits {required}")
        require(required in content_smoke, f"content-pack behavior smoke omits {required}")
        require(required in creator_builder, f"creator tools omit {required}")
        require(required in doctor, f"Doctor compile surface omits {required}")
        require(required in ci, f"CI compile surface omits {required}")
        require(required in boundary, f"Core boundary audit omits {required}")
        for label, surface in (
            ("source builder", source_builder),
            ("source auditor", source_auditor),
            ("portable source smoke", portable),
        ):
            require(required in surface, f"{label} omits {required}")
    for label, surface in (("Doctor", doctor), ("CI", ci), ("portable source smoke", portable)):
        require(
            "check-content-pack-validator-modularity.py" in surface,
            f"{label} does not execute validator modularity guard",
        )
    for label, surface in (("source builder", source_builder), ("source auditor", source_auditor)):
        require(
            "check-content-pack-validator-modularity.py" in surface,
            f"{label} omits validator modularity guard",
        )

    print(
        "PASS  content-pack validator modularity: bounded orchestration, fail-closed raw fields, "
        "focused pure rights/accessibility/fallback policies, no-follow package enumeration, "
        "asset-file authentication and value-only projection validation"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
