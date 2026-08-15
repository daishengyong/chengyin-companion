import AVFoundation
import CoreMedia
import Foundation

/// Focused install-time validation for video containers, tracks, declarations,
/// the first visible frame and bounded quality checkpoints. The outer media
/// probe owns only asset iteration and kind routing.
protocol ContentPackVideoMediaProbing: Sendable {
    func probeVideo(
        _ declaration: ContentPackAsset,
        at url: URL
    ) async throws
}

struct AVFoundationContentPackVideoMediaProbe: ContentPackVideoMediaProbing {
    private static let videoExtensions: Set<String> = ["mov", "mp4"]
    private let videoDecodeFallback: (any ContentPackVideoDecodeFallback)?

    init(
        videoDecodeFallback: (any ContentPackVideoDecodeFallback)? = nil
    ) {
        self.videoDecodeFallback = videoDecodeFallback
    }

    func probeVideo(
        _ declaration: ContentPackAsset,
        at url: URL
    ) async throws {
        guard Self.videoExtensions.contains(url.pathExtension.lowercased()) else {
            throw ContentPackMediaProbeError.unsupportedExtension(
                asset: declaration.id,
                pathExtension: url.pathExtension.lowercased()
            )
        }
        let asset = AVURLAsset(url: url)
        guard try await asset.load(.isPlayable) else {
            throw ContentPackMediaProbeError.mediaNotPlayable(declaration.id)
        }
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw ContentPackMediaProbeError.missingVideoTrack(declaration.id)
        }
        let videoFormats = try await videoTrack.load(.formatDescriptions)
        let allowedVideoCodecs: Set<FourCharCode> = [
            kCMVideoCodecType_H264,
            kCMVideoCodecType_HEVC,
        ]
        guard videoFormats.contains(where: {
            allowedVideoCodecs.contains(CMFormatDescriptionGetMediaSubType($0))
        }) else {
            throw ContentPackMediaProbeError.unsupportedVideoCodec(declaration.id)
        }

        let duration = try await asset.load(.duration)
        let actualDurationMs = Int((CMTimeGetSeconds(duration) * 1_000).rounded())
        guard actualDurationMs > 0,
              actualDurationMs <= ContentPackValidator.maximumMediaDurationMs else {
            throw ContentPackValidationError.mediaDurationTooLong(declaration.id)
        }
        if let declaredDurationMs = declaration.durationMs,
           abs(actualDurationMs - declaredDurationMs) > 250 {
            throw ContentPackMediaProbeError.durationMismatch(
                asset: declaration.id,
                declaredMs: declaredDurationMs,
                actualMs: actualDurationMs
            )
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let presentedSize = naturalSize.applying(transform)
        let actualWidth = Int(abs(presentedSize.width).rounded())
        let actualHeight = Int(abs(presentedSize.height).rounded())
        guard actualWidth > 0, actualHeight > 0,
              Int64(actualWidth) * Int64(actualHeight)
                <= Int64(ContentPackValidator.maximumMediaPixels) else {
            throw ContentPackValidationError.mediaDimensionsTooLarge(
                declaration.id
            )
        }
        if let declaredWidth = declaration.width,
           let declaredHeight = declaration.height,
           (actualWidth != declaredWidth || actualHeight != declaredHeight) {
            throw ContentPackMediaProbeError.dimensionsMismatch(
                asset: declaration.id,
                declaredWidth: declaredWidth,
                declaredHeight: declaredHeight,
                actualWidth: actualWidth,
                actualHeight: actualHeight
            )
        }

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let hasAudio = !audioTracks.isEmpty
        if let declaredAudio = declaration.hasNativeAudio,
           declaredAudio != hasAudio {
            throw ContentPackMediaProbeError.audioDeclarationMismatch(
                asset: declaration.id,
                declared: declaredAudio,
                actual: hasAudio
            )
        }
        for audioTrack in audioTracks {
            let descriptions = try await audioTrack.load(.formatDescriptions)
            guard descriptions.contains(where: {
                CMFormatDescriptionGetMediaSubType($0) == kAudioFormatMPEG4AAC
            }) else {
                throw ContentPackMediaProbeError.unsupportedVideoAudioCodec(
                    declaration.id
                )
            }
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(
            seconds: 0.25,
            preferredTimescale: 600
        )
        let probeSeconds = min(
            max(CMTimeGetSeconds(duration) * 0.1, 0.04),
            0.25
        )
        var fullDecodeVerifiedByFallback = false
        do {
            _ = try await generator.image(
                at: CMTime(seconds: probeSeconds, preferredTimescale: 600)
            )
        } catch {
            guard let videoDecodeFallback else {
                throw ContentPackMediaProbeError.firstFrameDecodeFailed(
                    declaration.id
                )
            }
            try videoDecodeFallback.decodeVideo(
                at: url,
                declarationID: declaration.id
            )
            fullDecodeVerifiedByFallback = true
        }

        do {
            try await ContentPackMediaQualityProbe().probe(
                asset: asset,
                videoTrack: videoTrack,
                audioTracks: audioTracks,
                duration: duration,
                declarationID: declaration.id,
                validateSamples: !fullDecodeVerifiedByFallback
            )
        } catch let error as ContentPackMediaProbeError {
            guard case .checkpointDecodeFailed = error,
                  let videoDecodeFallback,
                  !fullDecodeVerifiedByFallback else {
                throw error
            }
            try videoDecodeFallback.decodeVideo(
                at: url,
                declarationID: declaration.id
            )
            try await ContentPackMediaQualityProbe().probe(
                asset: asset,
                videoTrack: videoTrack,
                audioTracks: audioTracks,
                duration: duration,
                declarationID: declaration.id,
                validateSamples: false
            )
        }
    }
}
