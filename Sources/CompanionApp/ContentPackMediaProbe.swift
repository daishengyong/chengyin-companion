import Foundation

enum ContentPackMediaProbeError: LocalizedError, Equatable, CompanionErrorCoding {
    case unsupportedExtension(asset: String, pathExtension: String)
    case mediaNotPlayable(String)
    case missingVideoTrack(String)
    case unsupportedVideoCodec(String)
    case durationMismatch(asset: String, declaredMs: Int, actualMs: Int)
    case dimensionsMismatch(
        asset: String,
        declaredWidth: Int,
        declaredHeight: Int,
        actualWidth: Int,
        actualHeight: Int
    )
    case audioDeclarationMismatch(
        asset: String,
        declared: Bool,
        actual: Bool
    )
    case unsupportedVideoAudioCodec(String)
    case firstFrameDecodeFailed(String)
    case checkpointDecodeFailed(
        asset: String,
        stream: ContentPackMediaStream,
        checkpoint: ContentPackMediaCheckpoint
    )
    case audioVideoTimelineMismatch(
        asset: String,
        startOffsetMs: Int,
        endOffsetMs: Int
    )
    case missingAudioTrack(String)
    case imageDecodeFailed(String)
    case invalidJSON(String)

    var companionErrorCode: String {
        switch self {
        case .unsupportedExtension: "PACK_MEDIA_UNSUPPORTED_EXTENSION"
        case .mediaNotPlayable: "PACK_MEDIA_NOT_PLAYABLE"
        case .missingVideoTrack: "PACK_MEDIA_VIDEO_TRACK_MISSING"
        case .unsupportedVideoCodec: "PACK_MEDIA_UNSUPPORTED_VIDEO_CODEC"
        case .durationMismatch: "PACK_MEDIA_DURATION_MISMATCH"
        case .dimensionsMismatch: "PACK_MEDIA_DIMENSIONS_MISMATCH"
        case .audioDeclarationMismatch: "PACK_MEDIA_AUDIO_DECLARATION_MISMATCH"
        case .unsupportedVideoAudioCodec: "PACK_MEDIA_UNSUPPORTED_AUDIO_CODEC"
        case .firstFrameDecodeFailed: "PACK_MEDIA_FIRST_FRAME_DECODE_FAILED"
        case .checkpointDecodeFailed: "PACK_MEDIA_CHECKPOINT_DECODE_FAILED"
        case .audioVideoTimelineMismatch: "PACK_MEDIA_AUDIO_VIDEO_TIMELINE_MISMATCH"
        case .missingAudioTrack: "PACK_MEDIA_AUDIO_TRACK_MISSING"
        case .imageDecodeFailed: "PACK_MEDIA_IMAGE_DECODE_FAILED"
        case .invalidJSON: "PACK_MEDIA_INVALID_JSON"
        }
    }

    var errorDescription: String? {
        switch self {
        case let .unsupportedExtension(asset, pathExtension):
            return "Asset \(asset) uses an unsupported extension: \(pathExtension)."
        case let .mediaNotPlayable(asset):
            return "Asset \(asset) is not playable by the system media framework."
        case let .missingVideoTrack(asset):
            return "Video asset \(asset) has no video track."
        case let .unsupportedVideoCodec(asset):
            return "Video asset \(asset) is not H.264 or H.265."
        case let .durationMismatch(asset, declared, actual):
            return "Asset \(asset) declares \(declared)ms but is \(actual)ms."
        case let .dimensionsMismatch(asset, dw, dh, aw, ah):
            return "Asset \(asset) declares \(dw)×\(dh) but is \(aw)×\(ah)."
        case let .audioDeclarationMismatch(asset, declared, actual):
            return "Asset \(asset) declares native audio as \(declared) but it is \(actual)."
        case let .unsupportedVideoAudioCodec(asset):
            return "Video asset \(asset) does not use AAC audio."
        case let .firstFrameDecodeFailed(asset):
            return "Video asset \(asset) cannot decode its first visible frame."
        case let .checkpointDecodeFailed(asset, stream, checkpoint):
            return "Asset \(asset) cannot decode its \(stream.rawValue) \(checkpoint.rawValue) checkpoint."
        case let .audioVideoTimelineMismatch(asset, start, end):
            return "Asset \(asset) has audio/video timeline offsets of \(start)ms at the start and \(end)ms at the end."
        case let .missingAudioTrack(asset):
            return "Audio asset \(asset) has no audio track."
        case let .imageDecodeFailed(asset):
            return "Image asset \(asset) cannot be decoded."
        case let .invalidJSON(asset):
            return "Declarative asset \(asset) is not valid JSON."
        }
    }
}

protocol ContentPackMediaProbing: Sendable {
    func probe(
        packageDirectory: URL,
        manifest: ContentPackManifest
    ) async throws
}

struct AVFoundationContentPackMediaProbe: ContentPackMediaProbing {
    private let nonVideoProbe: any ContentPackNonVideoMediaProbing
    private let videoProbe: any ContentPackVideoMediaProbing

    init(
        nonVideoProbe: any ContentPackNonVideoMediaProbing = SystemContentPackNonVideoMediaProbe(),
        videoDecodeFallback: (any ContentPackVideoDecodeFallback)? = nil
    ) {
        self.nonVideoProbe = nonVideoProbe
        videoProbe = AVFoundationContentPackVideoMediaProbe(
            videoDecodeFallback: videoDecodeFallback
        )
    }

    func probe(
        packageDirectory: URL,
        manifest: ContentPackManifest
    ) async throws {
        for asset in manifest.assets {
            let url = packageDirectory
                .appendingPathComponent(asset.path)
                .standardizedFileURL
            do {
                switch asset.kind {
                case .video:
                    try await videoProbe.probeVideo(asset, at: url)
                case .audio:
                    try await nonVideoProbe.probeAudio(asset, at: url)
                case .image:
                    try nonVideoProbe.probeImage(asset, at: url)
                case .game, .localization:
                    try nonVideoProbe.probeJSON(asset, at: url)
                }
            } catch let known as ContentPackMediaProbeError {
                throw known
            } catch let known as ContentPackValidationError {
                throw known
            } catch {
                switch asset.kind {
                case .video, .audio:
                    throw ContentPackMediaProbeError.mediaNotPlayable(asset.id)
                case .image:
                    throw ContentPackMediaProbeError.imageDecodeFailed(asset.id)
                case .game, .localization:
                    throw ContentPackMediaProbeError.invalidJSON(asset.id)
                }
            }
        }
    }

}
