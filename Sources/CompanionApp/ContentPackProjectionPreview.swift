import Foundation

#if canImport(CompanionContracts)
import CompanionContracts
#endif

struct ContentPackProjectionCSSFrame: Equatable, Sendable {
    let leftPercent: Double
    let topPercent: Double
    let widthPercent: Double
    let heightPercent: Double
}

struct ContentPackProjectionPreviewItem: Equatable, Sendable {
    let mode: CompanionPresentationMode
    let label: String
    let projection: CompanionPresentationProjection

    var modeName: String {
        mode.rawValue
    }

    var viewportClass: String {
        mode == .pet ? "pet" : "landscape"
    }

    var anchorSummary: String {
        guard let anchor = projection.anchor else {
            return "default · \(projection.gravity.rawValue)"
        }
        let key = projection.resolvedAnchorKey ?? mode.rawValue
        if let track = projection.focalTrack {
            return "\(key) · \(track.keyframes.count) focal keyframes"
        }
        return String(
            format: "%@ · x %.2f · y %.2f · %.2f×",
            locale: Locale(identifier: "en_US_POSIX"),
            key,
            anchor.x,
            anchor.y,
            anchor.scale
        )
    }

    var mediaStyle: String {
        mediaStyle(atMilliseconds: 0)
    }

    func mediaStyle(atMilliseconds milliseconds: Double) -> String {
        guard let frame = cssFrame(atMilliseconds: milliseconds) else {
            let objectFit = projection.gravity == .aspectFill ? "cover" : "contain"
            return "inset:0;width:100%;height:100%;object-fit:\(objectFit);"
        }
        return String(
            format: "left:%.4f%%;top:%.4f%%;width:%.4f%%;height:%.4f%%;object-fit:contain;",
            locale: Locale(identifier: "en_US_POSIX"),
            frame.leftPercent,
            frame.topPercent,
            frame.widthPercent,
            frame.heightPercent
        )
    }

    /// CSS measures `top` from the top edge. The runtime contract measures its
    /// Core Animation frame from the bottom edge, so only the runtime path uses
    /// `1 - y`; applying it here would vertically mirror author previews.
    var cssFrame: ContentPackProjectionCSSFrame? {
        cssFrame(atMilliseconds: 0)
    }

    func cssFrame(atMilliseconds milliseconds: Double) -> ContentPackProjectionCSSFrame? {
        guard let anchor = projection.resolvedAnchor(
            atMilliseconds: milliseconds
        ) else { return nil }
        let scale = anchor.scale * 100
        let minimumOffset = 100 - scale
        return ContentPackProjectionCSSFrame(
            leftPercent: min(max(50 - (anchor.x * scale), minimumOffset), 0),
            topPercent: min(max(50 - (anchor.y * scale), minimumOffset), 0),
            widthPercent: scale,
            heightPercent: scale
        )
    }

    func safeAreaStyle(atMilliseconds milliseconds: Double) -> String? {
        guard let safeArea = projection.safeArea,
              let frame = cssFrame(atMilliseconds: milliseconds) else {
            return nil
        }
        return String(
            format: "left:%.4f%%;top:%.4f%%;width:%.4f%%;height:%.4f%%;",
            locale: Locale(identifier: "en_US_POSIX"),
            frame.leftPercent + (safeArea.x * frame.widthPercent),
            frame.topPercent + (safeArea.y * frame.heightPercent),
            safeArea.width * frame.widthPercent,
            safeArea.height * frame.heightPercent
        )
    }
}

/// Generates the creator-facing view of the same projection decisions used by
/// the app player. It is pure HTML: no script, network request, analytics or
/// provider credential is introduced by previewing a local pack.
enum ContentPackProjectionPreview {
    static func items(
        for asset: ContentPackAsset
    ) -> [ContentPackProjectionPreviewItem] {
        let anchors = (asset.cropAnchors ?? [:]).mapValues {
            CompanionMediaCropAnchor(x: $0.x, y: $0.y, scale: $0.scale)
        }
        let focalTracks = (asset.focalTracks ?? [:]).mapValues { keyframes in
            CompanionMediaFocalTrack(
                keyframes: keyframes.map {
                    CompanionMediaFocalKeyframe(
                        timeMs: $0.timeMs,
                        x: $0.x,
                        y: $0.y,
                        scale: $0.scale
                    )
                }
            )
        }
        let safeAreas = (asset.safeAreas ?? [:]).mapValues {
            CompanionMediaSafeArea(
                x: $0.x,
                y: $0.y,
                width: $0.width,
                height: $0.height
            )
        }
        return [
            (.pet, "Pet"),
            (.stage, "Stage"),
            (.fullscreen, "Fullscreen")
        ].map { mode, label in
            ContentPackProjectionPreviewItem(
                mode: mode,
                label: label,
                projection: CompanionPresentationProjection.resolve(
                    mode: mode,
                    cropAnchors: anchors,
                    focalTracks: focalTracks,
                    safeAreas: safeAreas,
                    reducedDynamicEffectsEnabled: false
                )
            )
        }
    }

    static func renderVideo(
        asset: ContentPackAsset,
        assetURL: URL,
        accessibilityLabel: String
    ) -> String {
        let source = escape(assetURL.absoluteString)
        let safeLabel = escape(accessibilityLabel)
        let panels = items(for: asset).map { item in
            let anchorKey = item.projection.resolvedAnchorKey ?? ""
            let safeAreaKey = item.projection.resolvedSafeAreaKey ?? ""
            let safeAreaOverlay = item.safeAreaStyle(atMilliseconds: 0).map {
                "<span class=\"projection-safe-area\" aria-hidden=\"true\" style=\"\(escape($0))\"></span>"
            } ?? ""
            let storyboard = renderStoryboard(
                item: item,
                source: source,
                safeLabel: safeLabel
            )
            return """
            <figure class="projection-panel"
                    data-presentation-mode="\(escape(item.modeName))"
                    data-projection-source="\(escape(item.projection.source.rawValue))"
                    data-anchor-key="\(escape(anchorKey))"
                    data-safe-area-key="\(escape(safeAreaKey))"
                    data-gravity="\(escape(item.projection.gravity.rawValue))">
              <div class="projection-viewport \(escape(item.viewportClass))">
                <video controls playsinline muted preload="metadata"
                       aria-label="\(safeLabel) · \(escape(item.label)) projection"
                       style="\(escape(item.mediaStyle))">
                  <source src="\(source)">
                </video>
                \(safeAreaOverlay)
              </div>
              <figcaption>
                <strong>\(escape(item.label))</strong>
                <span>\(escape(item.anchorSummary))</span>
                <small>\(escape(item.projection.source.rawValue))</small>
              </figcaption>
              \(storyboard)
            </figure>
            """
        }.joined(separator: "\n")

        return """
        <section class="projection-review" aria-label="Three-presentation crop review">
          <p class="projection-review-note">Projection previews start muted. Unmute one viewport to review native audio.</p>
          <div class="projection-grid">\(panels)</div>
        </section>
        """
    }

    private static func renderStoryboard(
        item: ContentPackProjectionPreviewItem,
        source: String,
        safeLabel: String
    ) -> String {
        guard let track = item.projection.focalTrack else { return "" }
        let indices = Array(Set([
            0,
            track.keyframes.count / 2,
            track.keyframes.count - 1
        ])).sorted()
        let frames = indices.map { index in
            let keyframe = track.keyframes[index]
            let milliseconds = Double(keyframe.timeMs)
            let seconds = milliseconds / 1_000
            let timedSource = String(
                format: "%@#t=%.3f",
                locale: Locale(identifier: "en_US_POSIX"),
                source,
                seconds
            )
            let overlay = item.safeAreaStyle(atMilliseconds: milliseconds).map {
                "<span class=\"projection-safe-area\" aria-hidden=\"true\" style=\"\(escape($0))\"></span>"
            } ?? ""
            return """
            <figure class="projection-story-frame" data-time-ms="\(keyframe.timeMs)">
              <div class="projection-story-viewport \(escape(item.viewportClass))">
                <video playsinline muted preload="metadata"
                       aria-label="\(safeLabel) · \(escape(item.label)) · \(keyframe.timeMs) milliseconds"
                       style="\(escape(item.mediaStyle(atMilliseconds: milliseconds)))">
                  <source src="\(timedSource)">
                </video>
                \(overlay)
              </div>
              <figcaption>\(formatTime(keyframe.timeMs))</figcaption>
            </figure>
            """
        }.joined(separator: "\n")
        return """
        <div class="projection-storyboard" aria-label="\(escape(item.label)) focal timeline">
          \(frames)
        </div>
        """
    }

    private static func formatTime(_ milliseconds: Int) -> String {
        String(
            format: "%.2fs",
            locale: Locale(identifier: "en_US_POSIX"),
            Double(milliseconds) / 1_000
        )
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
