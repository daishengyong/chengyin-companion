import AVFoundation
import CoreMedia
import Foundation

/// Decodes a small, bounded media window for install-time integrity checks.
/// This component owns codec/output mechanics only; checkpoint selection and
/// audio/video timeline policy remain in `ContentPackMediaQualityProbe`.
struct ContentPackMediaCheckpointDecoder: Sendable {
    static let windowSeconds = 0.45

    func decode(
        asset: AVAsset,
        track: AVAssetTrack,
        stream: ContentPackMediaStream,
        checkpoint: ContentPackMediaCheckpoint,
        startSeconds: Double,
        durationSeconds: Double,
        declarationID: String
    ) throws {
        let window = min(
            Self.windowSeconds,
            max(durationSeconds - startSeconds, 0.04)
        )
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any]
        switch stream {
        case .video:
            settings = [
                kCVPixelBufferPixelFormatTypeKey as String:
                    Int(kCVPixelFormatType_32BGRA)
            ]
        case .audio:
            settings = [AVFormatIDKey: Int(kAudioFormatLinearPCM)]
        }
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: settings
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            throw failure(
                asset: declarationID,
                stream: stream,
                checkpoint: checkpoint
            )
        }
        reader.add(output)
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: startSeconds, preferredTimescale: 600),
            duration: CMTime(seconds: window, preferredTimescale: 600)
        )
        guard reader.startReading() else {
            throw failure(
                asset: declarationID,
                stream: stream,
                checkpoint: checkpoint
            )
        }

        var decodedSamples = 0
        while let sample = output.copyNextSampleBuffer() {
            guard CMSampleBufferDataIsReady(sample) else { continue }
            decodedSamples += 1
        }
        let completed = reader.status == .completed
        reader.cancelReading()
        guard completed, decodedSamples > 0 else {
            throw failure(
                asset: declarationID,
                stream: stream,
                checkpoint: checkpoint
            )
        }
    }

    private func failure(
        asset: String,
        stream: ContentPackMediaStream,
        checkpoint: ContentPackMediaCheckpoint
    ) -> ContentPackMediaProbeError {
        .checkpointDecodeFailed(
            asset: asset,
            stream: stream,
            checkpoint: checkpoint
        )
    }
}
