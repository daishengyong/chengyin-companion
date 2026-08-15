#!/usr/bin/env python3
"""Executable source-level guard for the offline projection-authoring loop."""

from __future__ import annotations

import json
import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"FAIL  projection authoring integration: {message}", file=sys.stderr)
        raise SystemExit(1)


def text(relative: str) -> str:
    path = ROOT / relative
    require(path.is_file() and not path.is_symlink(), f"missing or unsafe {relative}")
    return path.read_text(encoding="utf-8")


def main() -> int:
    core = text("Sources/CompanionContracts/CompanionProjectionAuthoring.swift")
    renderer = text("Sources/CompanionApp/ContentPackProjectionEditor.swift")
    cli = text("scripts/content-pack-projection-editor-cli.swift")
    builder = text("scripts/build-creator-tool.sh")
    wrapper = text("scripts/edit-content-pack-projection.sh")
    applicator = text("scripts/apply-content-pack-projection.py")
    ci = text(".github/workflows/ci.yml")
    schema = json.loads(text("Schemas/projection-authoring-receipt-v1.schema.json"))

    require(
        "public struct CompanionProjectionAuthoringReceipt" in core
        and "currentSchemaVersion" in core
        and 'Set(["pet", "stage", "fullscreen"])' in core
        and "safeAreaNotVisible" in core,
        "Core path-free receipt or safe-area contract is incomplete",
    )
    require(
        "ContentPackProjectionPreview.items(for: asset)" in renderer
        and "50 - anchor.x * scale" in renderer
        and "50 - anchor.y * scale" in renderer
        and "frames.every(frame => safeAreaVisible(area, frame))" in renderer,
        "editor stopped sharing projection resolution or top-origin geometry",
    )
    require(
        "connect-src 'none'" in renderer
        and 'body data-network="disabled"' in renderer
        and "base64EncodedString" in renderer
        and "prefers-reduced-motion:reduce" in renderer,
        "editor offline, portable-payload or accessibility boundary is incomplete",
    )
    for forbidden in ("fetch(", "XMLHttpRequest", "WebSocket", "EventSource"):
        require(forbidden not in renderer, f"editor contains network API {forbidden}")
    require(
        "ContentPackValidator().loadAndValidate" in cli
        and "creatorContentPackMediaProbe().probe(" in cli
        and "AVFoundationContentPackMediaProbe" not in cli
        and "CREATOR_PROJECTION_EDITOR_OUTPUT_INSIDE_PACK" in cli,
        "editor CLI does not validate pack/media/output boundaries",
    )
    require(
        "projection-editor)" in builder
        and "ContentPackProjectionEditor.swift" in builder
        and "ContentPackVideoDecodeFallback.swift" in builder
        and "content-pack-creator-media-fallback.swift" in builder
        and "build-creator-tool.sh\" projection-editor" in wrapper,
        "editor is outside the shared creator-tool registry",
    )
    require(
        "def create_backup(" in applicator
        and "def atomic_write(" in applicator
        and applicator.count("validator_passes(pack)") >= 2
        and "atomic_write(manifest_path, backup.read_bytes())" in applicator
        and "PROJECTION_RECEIPT_VALIDATION_FAILED" in applicator,
        "transactional apply, post-validation or rollback contract is incomplete",
    )
    for forbidden in ("requests", "urllib", "socket", "http.client"):
        require(forbidden not in applicator, f"applicator contains network dependency {forbidden}")
    require(
        schema.get("additionalProperties") is False
        and schema.get("properties", {}).get("schemaVersion", {}).get("const")
        == "chengyin.projection-authoring-receipt/v1"
        and set(
            schema["properties"]["focalTracks"]["propertyNames"]["enum"]
        ) == {"pet", "stage", "fullscreen"},
        "receipt JSON Schema is not closed or mode-bounded",
    )
    require(
        "run-content-pack-projection-editor-smoke.sh" in ci
        and "run-projection-receipt-apply-smoke.sh" in ci
        and "projection-authoring-receipt-v1.schema.json" in ci,
        "CI does not execute the editor, transaction and schema gates",
    )
    print(
        "PASS  projection authoring integration: shared Core receipt, offline editor, "
        "transactional apply, rollback and CI gates"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
