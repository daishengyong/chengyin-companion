import AVFoundation
import CoreMedia
import Foundation

enum ContentPackMediaStream: String, Equatable, Sendable {
    case video
    case audio
}

enum ContentPackMediaCheckpoint: String, Equatable, Sendable {
    case midpoint
    case tail
}

struct ContentPackMediaTimelineAlignment: Equatable, Sendable {
    let startOffsetMs: Int
    let endOffsetMs: Int

    var isAcceptable: Bool {
        startOffsetMs <= ContentPackMediaQualityPolicy.maximumTimelineOffsetMs
            && endOffsetMs <= ContentPackMediaQualityPolicy.maximumTimelineOffsetMs
    }
}

enum ContentPackMediaQualityPolicy {
    static let maximumTimelineOffsetMs = 250

    static func timelineAlignment(
        videoStartMs: Int,
        videoDurationMs: Int,
        audioStartMs: Int,
        audioDurationMs: Int
    ) -> ContentPackMediaTimelineAlignment {
        ContentPackMediaTimelineAlignment(
            startOffsetMs: abs(videoStartMs - audioStartMs),
            endOffsetMs: abs(
                (videoStartMs + videoDurationMs)
                    - (audioStartMs + audioDurationMs)
            )
        )
    }
}

/// Bounded install-time quality checks that are deliberately kept out of the
/// playback hot path. Each reader is restricted to a sub-second time range.
struct ContentPackMediaQualityProbe: Sendable {
    func probe(
        asset: AVAsset,
        videoTrack: AVAssetTrack,
        audioTracks: [AVAssetTrack],
        duration: CMTime,
        declarationID: String,
        validateSamples: Bool = true
    ) async throws {
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw ContentPackMediaProbeError.mediaNotPlayable(declarationID)
        }
        let checkpointDecoder = ContentPackMediaCheckpointDecoder()

        if validateSamples {
            try checkpointDecoder.decode(
                asset: asset,
                track: videoTrack,
                stream: .video,
                checkpoint: .midpoint,
                startSeconds: max(0, durationSeconds * 0.5 - 0.1),
                durationSeconds: durationSeconds,
                declarationID: declarationID
            )
            try checkpointDecoder.decode(
                asset: asset,
                track: videoTrack,
                stream: .video,
                checkpoint: .tail,
                startSeconds: max(
                    0,
                    durationSeconds - ContentPackMediaCheckpointDecoder.windowSeconds
                ),
                durationSeconds: durationSeconds,
                declarationID: declarationID
            )
        }

        let videoRange = try await videoTrack.load(.timeRange)
        for audioTrack in audioTracks {
            let audioRange = try await audioTrack.load(.timeRange)
            let alignment = try timelineAlignment(
                videoRange: videoRange,
                audioRange: audioRange,
                declarationID: declarationID
            )
            guard alignment.isAcceptable else {
                throw ContentPackMediaProbeError.audioVideoTimelineMismatch(
                    asset: declarationID,
                    startOffsetMs: alignment.startOffsetMs,
                    endOffsetMs: alignment.endOffsetMs
                )
            }
            if validateSamples {
                try checkpointDecoder.decode(
                    asset: asset,
                    track: audioTrack,
                    stream: .audio,
                    checkpoint: .tail,
                    startSeconds: max(
                        0,
                        durationSeconds - ContentPackMediaCheckpointDecoder.windowSeconds
                    ),
                    durationSeconds: durationSeconds,
                    declarationID: declarationID
                )
            }
        }
    }

    private func timelineAlignment(
        videoRange: CMTimeRange,
        audioRange: CMTimeRange,
        declarationID: String
    ) throws -> ContentPackMediaTimelineAlignment {
        guard let videoStart = milliseconds(videoRange.start),
              let videoDuration = milliseconds(videoRange.duration),
              let audioStart = milliseconds(audioRange.start),
              let audioDuration = milliseconds(audioRange.duration) else {
            throw ContentPackMediaProbeError.mediaNotPlayable(declarationID)
        }
        return ContentPackMediaQualityPolicy.timelineAlignment(
            videoStartMs: videoStart,
            videoDurationMs: videoDuration,
            audioStartMs: audioStart,
            audioDurationMs: audioDuration
        )
    }

    private func milliseconds(_ time: CMTime) -> Int? {
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite, seconds >= 0 else { return nil }
        return Int((seconds * 1_000).rounded())
    }

}
