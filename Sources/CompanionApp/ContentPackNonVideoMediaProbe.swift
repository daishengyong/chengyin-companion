import AVFoundation
import Foundation
import ImageIO

/// Focused install-time validation for audio, image and declarative assets.
/// Video codec, frame and timeline policy remains in ContentPackMediaProbe.
protocol ContentPackNonVideoMediaProbing: Sendable {
    func probeAudio(
        _ declaration: ContentPackAsset,
        at url: URL
    ) async throws

    func probeImage(
        _ declaration: ContentPackAsset,
        at url: URL
    ) throws

    func probeJSON(
        _ declaration: ContentPackAsset,
        at url: URL
    ) throws
}

struct SystemContentPackNonVideoMediaProbe: ContentPackNonVideoMediaProbing {
    private static let audioExtensions: Set<String> = ["aac", "m4a", "wav"]
    private static let imageExtensions: Set<String> = ["jpeg", "jpg", "png", "webp"]

    func probeAudio(
        _ declaration: ContentPackAsset,
        at url: URL
    ) async throws {
        guard Self.audioExtensions.contains(url.pathExtension.lowercased()) else {
            throw ContentPackMediaProbeError.unsupportedExtension(
                asset: declaration.id,
                pathExtension: url.pathExtension.lowercased()
            )
        }
        let asset = AVURLAsset(url: url)
        guard try await asset.load(.isPlayable) else {
            throw ContentPackMediaProbeError.mediaNotPlayable(declaration.id)
        }
        let duration = try await asset.load(.duration)
        let actualDurationMs = Int((CMTimeGetSeconds(duration) * 1_000).rounded())
        guard actualDurationMs > 0,
              actualDurationMs <= ContentPackValidator.maximumMediaDurationMs else {
            throw ContentPackValidationError.mediaDurationTooLong(declaration.id)
        }
        guard !(try await asset.loadTracks(withMediaType: .audio)).isEmpty else {
            throw ContentPackMediaProbeError.missingAudioTrack(declaration.id)
        }
    }

    func probeImage(
        _ declaration: ContentPackAsset,
        at url: URL
    ) throws {
        guard Self.imageExtensions.contains(url.pathExtension.lowercased()) else {
            throw ContentPackMediaProbeError.unsupportedExtension(
                asset: declaration.id,
                pathExtension: url.pathExtension.lowercased()
            )
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else {
            throw ContentPackMediaProbeError.imageDecodeFailed(declaration.id)
        }
        if let properties = CGImageSourceCopyPropertiesAtIndex(
            source,
            0,
            nil
        ) as? [CFString: Any],
           let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
           let height = properties[kCGImagePropertyPixelHeight] as? NSNumber {
            let pixels = width.int64Value * height.int64Value
            guard width.int64Value > 0, height.int64Value > 0,
                  pixels <= Int64(ContentPackValidator.maximumMediaPixels) else {
                throw ContentPackValidationError.mediaDimensionsTooLarge(
                    declaration.id
                )
            }
        }
        guard CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
            throw ContentPackMediaProbeError.imageDecodeFailed(declaration.id)
        }
    }

    func probeJSON(
        _ declaration: ContentPackAsset,
        at url: URL
    ) throws {
        guard url.pathExtension.lowercased() == "json" else {
            throw ContentPackMediaProbeError.unsupportedExtension(
                asset: declaration.id,
                pathExtension: url.pathExtension.lowercased()
            )
        }
        do {
            _ = try JSONSerialization.jsonObject(
                with: Data(contentsOf: url),
                options: [.fragmentsAllowed]
            )
        } catch {
            throw ContentPackMediaProbeError.invalidJSON(declaration.id)
        }
    }
}
