#!/usr/bin/env python3
"""Keep declarative projection, runtime playback and creator preview aligned."""

from __future__ import annotations

import json
import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def fail(message: str) -> None:
    print(f"FAIL  presentation runtime integration: {message}", file=sys.stderr)
    raise SystemExit(1)


def read(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file() or path.is_symlink():
        fail(f"required regular file is missing: {relative}")
    return path.read_text(encoding="utf-8")


def require(relative: str, snippets: list[str]) -> str:
    text = read(relative)
    for snippet in snippets:
        if snippet not in text:
            fail(f"{relative} lost required projection binding")
    return text


def main() -> int:
    require(
        "Sources/CompanionContracts/CompanionPresentationProjection.swift",
        [
            "public struct CompanionMediaFocalTrack",
            "public struct CompanionMediaSafeArea",
            "anchor(atMilliseconds:",
            "atMilliseconds milliseconds: Double = 0",
            "let boundedX =",
            "let boundedY =",
        ],
    )
    require(
        "Sources/CompanionApp/ContentPackPlaybackModels.swift",
        [
            "let focalTracks: [String: [ContentPackAsset.FocalKeyframe]]",
            "let safeAreas: [String: ContentPackAsset.SafeArea]",
        ],
    )
    require(
        "Sources/CompanionApp/ContentPackRuntimeCatalog.swift",
        [
            "focalTracks: asset.focalTracks ?? [:]",
            "safeAreas: asset.safeAreas ?? [:]",
        ],
    )
    require(
        "Sources/CompanionApp/ContentPackRuntimeSelection.swift",
        [
            "extension ContentPackRuntimeCatalog",
            "func selectExperience(",
            "func selectVideo(",
            "private static func isCoolingDown(",
            "private static func bestLocaleMatches<Value>(",
            "CompanionLocaleResolutionPolicy.compatibilityScore(",
            "private struct ContentPackRandomSource",
        ],
    )
    player = require(
        "Sources/CompanionApp/CompanionVideoPlayer.swift",
        [
            "guard coordinator.currentProjection.hasDynamicFocalTrack else { return }",
            "CMTime(value: 1, timescale: 15)",
            "player.removeTimeObserver",
            "atMilliseconds: currentMilliseconds",
            "CompanionMediaPrewarmCache.shared.playerItem(for: url)",
            "coordinator.playbackLifecycle.begin(",
        ],
    )
    if player.count("addPeriodicTimeObserver(") != 1:
        fail("player must own exactly one bounded focal-time observer site")
    if "asyncAfter" in player or "seconds >= 0.08" in player:
        fail("first-frame health regressed to a delayed playback-time guess")

    require(
        "Sources/CompanionApp/CompanionPlaybackCoordinator.swift",
        [
            "maximumAssetCount: 4",
            "guard url.isFileURL else { return }",
            "\\.isReadyForDisplay",
            "CompanionPlaybackHealthMonitor.shared.recordFirstFrame",
            "finishHealth(reason: .cancelled)",
        ],
    )
    require(
        "Sources/CompanionApp/CompanionContentSequenceView.swift",
        [
            "CompanionMediaPrewarmCache.shared.prewarm(",
            "cursor.stepEnded(",
            "viewModel.reportContentSequenceFailure(sequence)",
        ],
    )

    content_view = read("Sources/CompanionApp/ContentView.swift")
    if "import AVFoundation" in content_view or "AVPlayerLayer" in content_view:
        fail("AVFoundation binding returned to ContentView.swift")

    require(
        "Sources/CompanionApp/ContentPackProjectionPreview.swift",
        [
            "projection.resolvedAnchor(",
            "renderStoryboard(",
            "projection-safe-area",
            "data-time-ms",
        ],
    )

    schema = json.loads(read("Schemas/content-pack-v2.schema.json"))
    asset = schema["$defs"]["asset"]["properties"]
    if not {"cropAnchors", "focalTracks", "safeAreas"} <= set(asset):
        fail("schema is missing an additive projection field")
    focal = asset["focalTracks"]["additionalProperties"]
    if focal.get("minItems") != 2 or focal.get("maxItems") != 32:
        fail("schema focal-track bounds changed")

    registry = set(json.loads(read("Schemas/error-codes-v1.json"))["codes"])
    required_codes = {
        "PACK_VALIDATION_INVALID_FOCAL_TRACK",
        "PACK_VALIDATION_INVALID_SAFE_AREA",
        "PACK_VALIDATION_PROJECTION_REQUIRES_APP_VERSION",
        "PACK_VALIDATION_SAFE_AREA_NOT_VISIBLE",
    }
    if not required_codes <= registry:
        fail("stable projection failure codes are incomplete")

    print(
        "PASS  presentation runtime integration: dynamic-only 15 Hz observer, "
        "real first-frame signal, bounded local prewarm, shared geometry, "
        "safe-area preview, focused AVFoundation modules"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
