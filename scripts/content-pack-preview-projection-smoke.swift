import Foundation

@main
private enum ContentPackPreviewProjectionSmoke {
    static func main() throws {
        let modern = asset(
            anchors: [
                "pet": .init(x: 0.5, y: 0.35, scale: 2.8),
                "stage": .init(x: 0.4, y: 0.45, scale: 1.2),
                "fullscreen": .init(x: 0.5, y: 0.5, scale: 1)
            ]
        )
        let modernItems = ContentPackProjectionPreview.items(for: modern)
        try require(modernItems.count == 3, "preview did not expose all three modes")
        try require(
            modernItems.map(\.mode) == [.pet, .stage, .fullscreen],
            "preview mode order changed"
        )
        try require(
            modernItems.allSatisfy { $0.projection.source == .declared },
            "modern crop keys did not use declared projections"
        )
        try require(
            modernItems[0].mediaStyle.contains("left:-90.0000%")
                && modernItems[0].mediaStyle.contains("top:-48.0000%"),
            "pet focal geometry differs from the runtime contract"
        )

        try assertVerticalCoordinateAgreement(y: 0.2)
        try assertVerticalCoordinateAgreement(y: 0.8)
        try assertEdgeClamping()

        let tracked = asset(
            anchors: [:],
            focalTracks: [
                "pet": [
                    .init(timeMs: 0, x: 0.45, y: 0.45, scale: 2),
                    .init(timeMs: 1_000, x: 0.55, y: 0.55, scale: 2),
                    .init(timeMs: 2_000, x: 0.45, y: 0.45, scale: 2)
                ]
            ],
            safeAreas: [
                "pet": .init(x: 0.35, y: 0.35, width: 0.3, height: 0.3)
            ]
        )
        let trackedPet = ContentPackProjectionPreview.items(for: tracked)[0]
        try require(
            trackedPet.projection.source == .declaredTrack
                && trackedPet.projection.hasDynamicFocalTrack,
            "dynamic focal preview did not use the runtime track"
        )
        try require(
            trackedPet.mediaStyle(atMilliseconds: 500).contains("left:-50.0000%")
                && trackedPet.safeAreaStyle(atMilliseconds: 500) != nil,
            "dynamic focal or safe-area preview geometry changed"
        )

        let legacy = asset(
            anchors: [
                "pet": .init(x: 0.5, y: 0.5, scale: 2),
                "partial": .init(x: 0.5, y: 0.5, scale: 1),
                "full": .init(x: 0.5, y: 0.5, scale: 1)
            ]
        )
        let legacyItems = ContentPackProjectionPreview.items(for: legacy)
        try require(
            legacyItems[1].projection.source == .legacyAlias
                && legacyItems[1].projection.resolvedAnchorKey == "partial",
            "v1 partial alias is missing from creator preview"
        )
        try require(
            legacyItems[2].projection.source == .legacyAlias
                && legacyItems[2].projection.resolvedAnchorKey == "full",
            "v1 full alias is missing from creator preview"
        )

        let invalid = asset(
            anchors: ["pet": .init(x: .nan, y: 3, scale: 99)]
        )
        let invalidPet = ContentPackProjectionPreview.items(for: invalid)[0]
        try require(
            invalidPet.projection.source == .modeDefault
                && invalidPet.projection.anchor == nil
                && invalidPet.mediaStyle.contains("object-fit:cover"),
            "invalid preview metadata escaped the safe pet fallback"
        )

        let html = ContentPackProjectionPreview.renderVideo(
            asset: modern,
            assetURL: URL(fileURLWithPath: "/tmp/creator-preview.mov"),
            accessibilityLabel: "Adult companion demonstrates <movement>"
        )
        try require(
            html.components(separatedBy: "data-presentation-mode=").count - 1 == 3,
            "rendered preview does not contain exactly three projections"
        )
        try require(
            html.contains("data-presentation-mode=\"pet\"")
                && html.contains("data-presentation-mode=\"stage\"")
                && html.contains("data-presentation-mode=\"fullscreen\""),
            "rendered preview lost a presentation identifier"
        )
        try require(
            html.contains("Adult companion demonstrates &lt;movement&gt;"),
            "accessibility description was not escaped"
        )
        try require(
            !html.localizedCaseInsensitiveContains("<script")
                && !html.contains("http://")
                && !html.contains("https://"),
            "projection preview introduced executable or remote content"
        )
        let trackedHTML = ContentPackProjectionPreview.renderVideo(
            asset: tracked,
            assetURL: URL(fileURLWithPath: "/tmp/creator-preview.mov"),
            accessibilityLabel: "Adult companion stays inside the author envelope"
        )
        try require(
            trackedHTML.components(separatedBy: "data-time-ms=").count - 1 == 3
                && trackedHTML.contains("data-safe-area-key=\"pet\"")
                && trackedHTML.contains("projection-safe-area")
                && !trackedHTML.localizedCaseInsensitiveContains("<script"),
            "offline focal storyboard or safe-area overlay is incomplete"
        )
        print("Content-pack projection preview smoke: PASS (9/9, dynamic focal, safe area, edge clamp)")
    }

    private static func assertVerticalCoordinateAgreement(y: Double) throws {
        let asymmetric = asset(
            anchors: ["pet": .init(x: 0.5, y: y, scale: 2)]
        )
        let preview = ContentPackProjectionPreview.items(for: asymmetric)[0]
        guard let cssFrame = preview.cssFrame else {
            throw PreviewSmokeFailure(message: "asymmetric crop lost its CSS frame")
        }
        let viewport = CGRect(x: 0, y: 0, width: 100, height: 100)
        let runtimeFrame = preview.projection.playerLayerFrame(in: viewport)
        let runtimeTopInCSSCoordinates = viewport.height - runtimeFrame.maxY
        try require(
            abs(cssFrame.topPercent - runtimeTopInCSSCoordinates) < 0.000_001,
            "CSS top coordinate vertically disagrees with runtime at y=\(y)"
        )
    }

    private static func assertEdgeClamping() throws {
        let edge = asset(
            anchors: ["pet": .init(x: 0.05, y: 0.05, scale: 3)]
        )
        guard let frame = ContentPackProjectionPreview.items(for: edge)[0].cssFrame else {
            throw PreviewSmokeFailure(message: "edge crop lost its CSS frame")
        }
        try require(
            frame.leftPercent == 0 && frame.topPercent == 0,
            "creator preview exposed a blank edge gutter"
        )
    }

    private static func asset(
        anchors: [String: ContentPackAsset.CropAnchor],
        focalTracks: [String: [ContentPackAsset.FocalKeyframe]]? = nil,
        safeAreas: [String: ContentPackAsset.SafeArea]? = nil
    ) -> ContentPackAsset {
        ContentPackAsset(
            id: "preview-video",
            kind: .video,
            path: "media/preview.mov",
            sha256: String(repeating: "a", count: 64),
            durationMs: 4_000,
            width: 1_280,
            height: 720,
            aspectRatio: "16:9",
            hasNativeAudio: true,
            loop: false,
            cropAnchors: anchors,
            focalTracks: focalTracks,
            safeAreas: safeAreas,
            triggers: ["singleTap"],
            tags: ["preview"],
            cooldownSeconds: 0,
            weight: 1
        )
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        guard condition() else {
            throw PreviewSmokeFailure(message: message)
        }
    }
}

private struct PreviewSmokeFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
