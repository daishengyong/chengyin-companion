#!/usr/bin/env python3
"""Executable source guard for safe `.chengyinpack` build, audit and UI import."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"FAIL  content-pack archive integration: {message}", file=sys.stderr)
        raise SystemExit(1)


def text(relative: str) -> str:
    path = ROOT / relative
    require(path.is_file() and not path.is_symlink(), f"missing or unsafe {relative}")
    return path.read_text(encoding="utf-8")


def main() -> int:
    policy = text("Sources/CompanionApp/ContentPackArchivePolicy.swift")
    importer = text("Sources/CompanionApp/ContentPackArchiveImporter.swift")
    library = text("Sources/CompanionApp/CompanionContentLibrary.swift")
    panel = text("Sources/CompanionApp/CompanionContentPackImportPanel.swift")
    error_ui = text("Sources/CompanionApp/CompanionErrorPresentation.swift")
    creator_registry = text("scripts/build-creator-tool.sh")
    builder = text("scripts/build-content-pack-archive.py")
    archive_cli = text("scripts/content-pack-archive-audit-cli.swift")
    smoke = text("scripts/run-content-pack-archive-smoke.sh")
    doctor = text("scripts/doctor.sh")
    ci = text(".github/workflows/ci.yml")
    source_builder = text("scripts/build-portable-source.sh")
    source_auditor = text("scripts/audit-portable-source.py")

    require(
        "struct ContentPackArchivePolicy" in policy
        and "maximumArchiveBytes" in policy
        and "maximumUnpackedBytes" in policy
        and "compressionRatioThreshold" in policy
        and "validateLocalHeader" in policy
        and "payloadIntervals" in policy
        and "Process(" not in policy,
        "read-only central/local ZIP policy is incomplete or owns side effects",
    )
    require(
        '"input.chengyinpack"' in importer
        and "copyItem(at: source, to: snapshot)" in importer
        and "ContentPackArchivePolicy().inspect(snapshot)" in importer
        and 'URL(fileURLWithPath: "/usr/bin/ditto")' in importer
        and "verifyExtraction" in importer
        and "removeItem(at: workspace)" in importer,
        "private snapshot, fixed extractor, postcondition or cleanup is disconnected",
    )
    require(
        "archiveImporter.extract(from: source)" in library
        and "defer { archiveImporter.removeExtraction(extraction) }" in library
        and "store.install(from: extraction.packageDirectory)" in library,
        "archive import does not converge on the transactional content library",
    )
    require(
        "panel.canChooseFiles = true" in panel
        and "panel.canChooseDirectories = true" in panel
        and 'UTType(filenameExtension: "chengyinpack")' in panel,
        "graphical import no longer accepts both archive and authoring directory",
    )
    require(
        "case is ContentPackArchiveError" in error_ui
        and 'key: "error.presentation.packArchive"' in error_ui,
        "localized archive error identity is disconnected from UI",
    )
    require(
        "archive-audit)" in creator_registry
        and "ContentPackArchivePolicy.swift" in creator_registry
        and "ContentPackArchiveImporter.swift" in creator_registry
        and "ContentPackArchiveImporter()" in archive_cli
        and "extraction.inspection" in archive_cli,
        "archive auditor is outside the shared creator-tool source registry",
    )
    require(
        "validate-content-pack.sh" in builder
        and "audit-content-pack-archive.sh" in builder
        and "os.replace(temporary, output)" in builder
        and 'ZipFile(destination, "x", allowZip64=False)' in builder,
        "builder lost prevalidation, independent post-audit or atomic publication",
    )
    require(
        "valid-flat.chengyinpack" in smoke
        and "valid-wrapped.chengyinpack" in smoke
        and "local-header-mismatch.chengyinpack" in smoke
        and "compression-bomb.chengyinpack" in smoke
        and "PACK_ARCHIVE_BUILD_INVALID_TARGET" in smoke,
        "archive threat matrix no longer covers the accepted and hostile states",
    )
    for integration in (doctor, ci):
        require(
            "run-content-pack-archive-smoke.sh" in integration
            and "check-content-pack-archive-integration.py" in integration,
            "doctor or CI is missing archive behavior/integration gates",
        )
    for portable in (source_builder, source_auditor):
        require(
            "ContentPackArchivePolicy.swift" in portable
            and "ContentPackArchiveImporter.swift" in portable
            and "run-content-pack-archive-smoke.sh" in portable,
            "portable source contract omitted archive runtime or threat checks",
        )
    print(
        "PASS  content-pack archive integration: pure ZIP policy, private extraction, "
        "transactional UI import, atomic creator build/audit and CI gates"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
