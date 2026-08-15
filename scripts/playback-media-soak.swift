import AVFoundation
import CoreVideo
import Darwin
import Foundation

private struct Configuration {
    let mediaRoot: URL
    let durationSeconds: Double
    let maximumGrowthBytes: UInt64
    let maximumFirstFrameMilliseconds: Int

    static func parse(_ arguments: [String]) throws -> Configuration {
        var mediaRoot: URL?
        var durationSeconds = 1_800.0
        var maximumGrowthMB = 192.0
        var maximumFirstFrameMilliseconds = 500
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            func nextValue() throws -> String {
                guard index + 1 < arguments.count else {
                    throw SoakFailure.invalidArgument
                }
                index += 1
                return arguments[index]
            }
            switch argument {
            case "--media-root":
                mediaRoot = URL(fileURLWithPath: try nextValue(), isDirectory: true)
            case "--duration-seconds":
                guard let value = Double(try nextValue()), value >= 1, value <= 7_200 else {
                    throw SoakFailure.invalidArgument
                }
                durationSeconds = value
            case "--max-growth-mb":
                guard let value = Double(try nextValue()), value >= 16, value <= 2_048 else {
                    throw SoakFailure.invalidArgument
                }
                maximumGrowthMB = value
            case "--max-first-frame-ms":
                guard let value = Int(try nextValue()), value >= 100, value <= 10_000 else {
                    throw SoakFailure.invalidArgument
                }
                maximumFirstFrameMilliseconds = value
            default:
                throw SoakFailure.invalidArgument
            }
            index += 1
        }
        guard let mediaRoot else { throw SoakFailure.invalidArgument }
        return Configuration(
            mediaRoot: mediaRoot.standardizedFileURL,
            durationSeconds: durationSeconds,
            maximumGrowthBytes: UInt64(maximumGrowthMB * 1_048_576),
            maximumFirstFrameMilliseconds: maximumFirstFrameMilliseconds
        )
    }
}

private enum SoakFailure: Error {
    case invalidArgument
    case mediaMissing
    case decodeFailed
    case restrictedDecoderUnavailable
    case memoryGrowth
    case firstFrameSlow

    var code: String {
        switch self {
        case .invalidArgument: "PLAYBACK_SOAK_ARGUMENT_INVALID"
        case .mediaMissing: "PLAYBACK_SOAK_MEDIA_MISSING"
        case .decodeFailed: "PLAYBACK_SOAK_DECODE_FAILED"
        case .restrictedDecoderUnavailable:
            "PLAYBACK_SOAK_AVFOUNDATION_RESTRICTED"
        case .memoryGrowth: "PLAYBACK_SOAK_MEMORY_GROWTH"
        case .firstFrameSlow: "PLAYBACK_SOAK_FIRST_FRAME_SLOW"
        }
    }

    var recoveryAction: String {
        switch self {
        case .invalidArgument:
            "Provide a local media root and bounded numeric options, then retry."
        case .mediaMissing:
            "Restore at least one regular local MOV, MP4 or M4V asset, then retry."
        case .decodeFailed:
            "Run the content-pack media probe, replace the damaged asset and retry."
        case .restrictedDecoderUnavailable:
            "Rerun this AVFoundation probe on a physical clean Mac outside the restricted Codex sandbox; do not substitute a software decoder for runtime proof."
        case .memoryGrowth:
            "Inspect AVFoundation teardown and cache bounds before extending the soak."
        case .firstFrameSlow:
            "Reduce media complexity or improve prewarm before extending the soak."
        }
    }
}

private struct SoakReceipt: Codable {
    let schemaVersion: String
    let status: String
    let code: String?
    let proofKind: String
    let scope: String
    let releaseSoakSatisfied: Bool
    let requestedDurationSeconds: Double
    let elapsedSeconds: Double
    let mediaCount: Int
    let attempts: Int
    let decodedFrames: Int
    let attemptsWithAudio: Int
    let firstFrameP95Milliseconds: Int?
    let firstFrameTargetMilliseconds: Int
    let baselineResidentMB: Double
    let finalResidentMB: Double
    let peakGrowthMB: Double
    let recoveryAction: String?
}

@main
private enum PlaybackMediaSoak {
    static func main() async {
        let startedAt = ProcessInfo.processInfo.systemUptime
        do {
            let configuration = try Configuration.parse(
                Array(CommandLine.arguments.dropFirst())
            )
            let media = try discoverMedia(in: configuration.mediaRoot)
            guard !media.isEmpty else { throw SoakFailure.mediaMissing }

            let baseline = residentBytes()
            var peak = baseline
            var health = CompanionPlaybackHealthAccumulator(
                maximumSampleCount: 128,
                firstFrameTargetMilliseconds: configuration.maximumFirstFrameMilliseconds
            )
            var decodedFrames = 0
            var attemptsWithAudio = 0
            var attempts = 0
            var failures = 0
            let deadline = startedAt + configuration.durationSeconds

            repeat {
                for url in media {
                    let token = health.beginAttempt()
                    do {
                        let decoded = try await decodeProbe(url: url)
                        _ = health.recordFirstFrame(
                            for: token,
                            milliseconds: decoded.firstFrameMilliseconds
                        )
                        _ = health.finishAttempt(token, reason: .ended)
                        decodedFrames += decoded.frameCount
                        if decoded.hasAudio { attemptsWithAudio += 1 }
                    } catch {
                        _ = health.finishAttempt(token, reason: .failed)
                        failures += 1
                    }
                    attempts += 1
                    peak = max(peak, residentBytes())
                    if ProcessInfo.processInfo.systemUptime >= deadline { break }
                }
            } while ProcessInfo.processInfo.systemUptime < deadline

            let final = residentBytes()
            let snapshot = health.snapshot
            let peakGrowth = peak > baseline ? peak - baseline : 0
            let restrictedDecoderPending = ProcessInfo.processInfo.environment[
                "CODEX_SANDBOX"
            ] != nil
                && ProcessInfo.processInfo.environment[
                    "CHENGYIN_ALLOW_RESTRICTED_DECODE_PENDING"
                ] == "1"
                && attempts > 0
                && failures == attempts
                && decodedFrames == 0
                && peakGrowth <= configuration.maximumGrowthBytes
            let failure: SoakFailure?
            if restrictedDecoderPending {
                failure = nil
            } else if failures > 0 {
                failure = .decodeFailed
            } else if peakGrowth > configuration.maximumGrowthBytes {
                failure = .memoryGrowth
            } else if snapshot.firstFrameStatus == .aboveTarget {
                failure = .firstFrameSlow
            } else {
                failure = nil
            }
            let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
            let releaseSatisfied = failure == nil
                && !restrictedDecoderPending
                && configuration.durationSeconds >= 1_800
                && elapsed >= 1_800
            let receipt = SoakReceipt(
                schemaVersion: "chengyin.playback-media-soak/v1",
                status: restrictedDecoderPending
                    ? "PENDING"
                    : (failure == nil ? "PASS" : "FAIL"),
                code: restrictedDecoderPending
                    ? SoakFailure.restrictedDecoderUnavailable.code
                    : failure?.code,
                proofKind: restrictedDecoderPending
                    ? "NO_DECODE_PROOF_RESTRICTED_SANDBOX"
                    : (failure == nil
                        ? "HEADLESS_AVFOUNDATION_DECODE"
                        : "NO_DECODE_PROOF"),
                scope: configuration.durationSeconds >= 1_800
                    ? "release-soak"
                    : "short-probe",
                releaseSoakSatisfied: releaseSatisfied,
                requestedDurationSeconds: configuration.durationSeconds,
                elapsedSeconds: elapsed,
                mediaCount: media.count,
                attempts: attempts,
                decodedFrames: decodedFrames,
                attemptsWithAudio: attemptsWithAudio,
                firstFrameP95Milliseconds: snapshot.firstFrameP95Milliseconds,
                firstFrameTargetMilliseconds: snapshot.firstFrameTargetMilliseconds,
                baselineResidentMB: megabytes(baseline),
                finalResidentMB: megabytes(final),
                peakGrowthMB: megabytes(peakGrowth),
                recoveryAction: restrictedDecoderPending
                    ? SoakFailure.restrictedDecoderUnavailable.recoveryAction
                    : failure?.recoveryAction
            )
            write(receipt)
            exit(restrictedDecoderPending ? 2 : (failure == nil ? 0 : 1))
        } catch let failure as SoakFailure {
            write(failureReceipt(failure, startedAt: startedAt))
            exit(1)
        } catch {
            let failure = SoakFailure.decodeFailed
            write(failureReceipt(failure, startedAt: startedAt))
            exit(1)
        }
    }

    private static func discoverMedia(in root: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: root.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            throw SoakFailure.mediaMissing
        }
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .isSymbolicLinkKey
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw SoakFailure.mediaMissing
        }
        let extensions = Set(["mov", "mp4", "m4v"])
        return enumerator.compactMap { value -> URL? in
            guard let url = value as? URL,
                  extensions.contains(url.pathExtension.lowercased()),
                  let properties = try? url.resourceValues(forKeys: Set(keys)),
                  properties.isRegularFile == true,
                  properties.isSymbolicLink != true else {
                return nil
            }
            return url
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func decodeProbe(url: URL) async throws -> (
        firstFrameMilliseconds: Int,
        frameCount: Int,
        hasAudio: Bool
    ) {
        let startedAt = ProcessInfo.processInfo.systemUptime
        let asset = AVURLAsset(url: url)
        guard try await asset.load(.isPlayable) else {
            throw SoakFailure.decodeFailed
        }
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw SoakFailure.decodeFailed
        }
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_32BGRA
            ]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw SoakFailure.decodeFailed }
        reader.add(output)
        guard reader.startReading() else { throw SoakFailure.decodeFailed }
        var frameCount = 0
        var firstFrameMilliseconds: Int?
        while frameCount < 12, output.copyNextSampleBuffer() != nil {
            frameCount += 1
            if firstFrameMilliseconds == nil {
                firstFrameMilliseconds = Int(
                    max(
                        0,
                        (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
                    ).rounded()
                )
            }
        }
        reader.cancelReading()
        guard frameCount > 0, let firstFrameMilliseconds else {
            throw SoakFailure.decodeFailed
        }
        return (firstFrameMilliseconds, frameCount, !audioTracks.isEmpty)
    }

    private static func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size
                / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.resident_size) : 0
    }

    private static func megabytes(_ bytes: UInt64) -> Double {
        (Double(bytes) / 1_048_576 * 100).rounded() / 100
    }

    private static func failureReceipt(
        _ failure: SoakFailure,
        startedAt: TimeInterval
    ) -> SoakReceipt {
        SoakReceipt(
            schemaVersion: "chengyin.playback-media-soak/v1",
            status: "FAIL",
            code: failure.code,
            proofKind: "NO_DECODE_PROOF",
            scope: "not-started",
            releaseSoakSatisfied: false,
            requestedDurationSeconds: 0,
            elapsedSeconds: ProcessInfo.processInfo.systemUptime - startedAt,
            mediaCount: 0,
            attempts: 0,
            decodedFrames: 0,
            attemptsWithAudio: 0,
            firstFrameP95Milliseconds: nil,
            firstFrameTargetMilliseconds:
                CompanionPlaybackHealthAccumulator.defaultFirstFrameTargetMilliseconds,
            baselineResidentMB: 0,
            finalResidentMB: 0,
            peakGrowthMB: 0,
            recoveryAction: failure.recoveryAction
        )
    }

    private static func write(_ receipt: SoakReceipt) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(receipt) {
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
    }
}
