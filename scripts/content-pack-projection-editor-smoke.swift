import Foundation

@main
private enum ContentPackProjectionEditorSmoke {
    static func main() throws {
        let asset = ContentPackAsset(
            id: "editor-video",
            kind: .video,
            path: "media/editor.mov",
            sha256: String(repeating: "a", count: 64),
            durationMs: 4_000,
            width: 1_280,
            height: 720,
            aspectRatio: "16:9",
            hasNativeAudio: true,
            loop: false,
            cropAnchors: [
                "pet": .init(x: 0.5, y: 0.35, scale: 2.8),
                "stage": .init(x: 0.5, y: 0.5, scale: 1),
                "fullscreen": .init(x: 0.5, y: 0.5, scale: 1)
            ],
            focalTracks: nil,
            safeAreas: nil,
            triggers: ["singleTap"],
            tags: ["editor"],
            cooldownSeconds: 0,
            weight: 1
        )
        let receipt = try ContentPackProjectionEditor.initialReceipt(
            packID: "cc.chengyin.example.editor",
            asset: asset,
            appVersion: "0.19.29"
        )
        try receipt.validate(durationMs: 4_000)
        try require(
            Set(receipt.focalTracks.keys) == Set(["pet", "stage", "fullscreen"]),
            "editor did not initialize all three runtime presentations"
        )
        try require(
            receipt.focalTracks.values.allSatisfy {
                $0.count == 2 && $0.first?.timeMs == 0 && $0.last?.timeMs == 4_000
            },
            "static anchors did not become bounded editable timelines"
        )

        let html = try ContentPackProjectionEditor.render(
            packID: receipt.packID,
            asset: asset,
            assetURL: URL(fileURLWithPath: "/tmp/editor-media.mov"),
            appVersion: "0.19.29",
            preferredLocale: "zh-Hans"
        )
        try require(
            html.contains("connect-src 'none'")
                && html.contains("data-network=\"disabled\"")
                && !html.contains("http://")
                && !html.contains("https://"),
            "offline editor introduced a remote-content route"
        )
        try require(
            !html.contains("fetch(")
                && !html.contains("XMLHttpRequest")
                && !html.contains("WebSocket")
                && !html.contains("EventSource"),
            "offline editor introduced a network API"
        )
        try require(
            html.contains("role=\"status\"")
                && html.contains("aria-live=\"polite\"")
                && html.contains("prefers-reduced-motion:reduce")
                && html.contains("aria-label=\"视频时间线\""),
            "editor lost keyboard, status or reduced-motion semantics"
        )
        try require(
            html.contains("50 - anchor.y * scale")
                && html.contains("{x:.5,y:.2,scale:2}")
                && html.contains("{x:.5,y:.8,scale:2}")
                && !html.contains("1 - anchor.y"),
            "editor geometry no longer follows the top-origin runtime contract"
        )
        try require(
            html.contains("safeAreaVisible(area, frame)")
                && html.contains("frames.every(frame => safeAreaVisible(area, frame))")
                && html.contains("The green region") == false,
            "editor safe-area timeline guard or locale selection changed"
        )

        let prefix = "<script id=\"initial-state\" type=\"application/octet-stream\">"
        let suffix = "</script>"
        guard let start = html.range(of: prefix),
              let end = html.range(of: suffix, range: start.upperBound..<html.endIndex),
              let data = Data(base64Encoded: String(html[start.upperBound..<end.lowerBound])) else {
            throw SmokeFailure(message: "editor initial receipt payload is not safe base64")
        }
        let decoded = try JSONDecoder().decode(
            CompanionProjectionAuthoringReceipt.self,
            from: data
        )
        try require(decoded == receipt, "embedded authoring receipt changed")
        let payload = String(decoding: data, as: UTF8.self)
        try require(
            !payload.contains("/tmp/")
                && !payload.contains("file://")
                && !payload.contains("editor-media.mov"),
            "portable authoring receipt leaked the local media location"
        )

        let english = try ContentPackProjectionEditor.render(
            packID: receipt.packID,
            asset: asset,
            assetURL: URL(fileURLWithPath: "/tmp/editor-media.mov"),
            appVersion: "0.19.29",
            preferredLocale: "en"
        )
        try require(
            english.contains("Projection focal and safe-area editor")
                && english.contains("Offline · no remote requests"),
            "English creator editor copy is incomplete"
        )
        print("Content-pack projection editor smoke: PASS (8/8)")
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        guard condition() else { throw SmokeFailure(message: message) }
    }
}

private struct SmokeFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
