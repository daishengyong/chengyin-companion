import Foundation

public enum CompanionPlaybackTerminalReason: String, Equatable, Sendable {
    case ended
    case failed
    case cancelled
}

public enum CompanionPlaybackFirstFrameStatus: String, Equatable, Sendable {
    case unavailable
    case withinTarget
    case aboveTarget
}

public struct CompanionPlaybackAttemptToken: Hashable, Sendable {
    fileprivate let rawValue: UInt64

    fileprivate init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

/// Privacy-minimal, in-memory playback health. It stores counts and bounded
/// latency numbers only: never URLs, asset IDs, pack IDs or user content.
public struct CompanionPlaybackHealthSnapshot: Equatable, Sendable {
    public let startedCount: Int
    public let readyCount: Int
    public let endedCount: Int
    public let failureCount: Int
    public let cancelledCount: Int
    public let activeAttemptCount: Int
    public let peakActiveAttemptCount: Int
    public let firstFrameSampleCount: Int
    public let firstFrameP95Milliseconds: Int?
    public let firstFrameTargetMilliseconds: Int

    public var firstFrameStatus: CompanionPlaybackFirstFrameStatus {
        guard let firstFrameP95Milliseconds else { return .unavailable }
        return firstFrameP95Milliseconds <= firstFrameTargetMilliseconds
            ? .withinTarget
            : .aboveTarget
    }
}

/// Exactly-once accumulator for concurrent AVPlayer attempts. Stale or repeated
/// callbacks are ignored by opaque tokens, and first-frame samples remain
/// bounded so a long desktop session cannot grow memory indefinitely.
public struct CompanionPlaybackHealthAccumulator: Sendable {
    public static let defaultFirstFrameTargetMilliseconds = 500

    private let maximumSampleCount: Int
    private let firstFrameTargetMilliseconds: Int
    private var nextTokenRawValue: UInt64 = 1
    private var activeTokens: Set<CompanionPlaybackAttemptToken> = []
    private var readyTokens: Set<CompanionPlaybackAttemptToken> = []
    private var firstFrameSamples: [Int] = []
    private var startedCount = 0
    private var readyCount = 0
    private var endedCount = 0
    private var failureCount = 0
    private var cancelledCount = 0
    private var peakActiveAttemptCount = 0

    public init(
        maximumSampleCount: Int = 128,
        firstFrameTargetMilliseconds: Int = defaultFirstFrameTargetMilliseconds
    ) {
        self.maximumSampleCount = min(max(maximumSampleCount, 1), 512)
        self.firstFrameTargetMilliseconds = min(
            max(firstFrameTargetMilliseconds, 100),
            10_000
        )
    }

    public mutating func beginAttempt() -> CompanionPlaybackAttemptToken {
        let token = CompanionPlaybackAttemptToken(rawValue: nextTokenRawValue)
        nextTokenRawValue = nextTokenRawValue == UInt64.max
            ? 1
            : nextTokenRawValue + 1
        activeTokens.insert(token)
        startedCount += 1
        peakActiveAttemptCount = max(peakActiveAttemptCount, activeTokens.count)
        return token
    }

    @discardableResult
    public mutating func recordFirstFrame(
        for token: CompanionPlaybackAttemptToken,
        milliseconds: Int
    ) -> Bool {
        guard activeTokens.contains(token), !readyTokens.contains(token) else {
            return false
        }
        readyTokens.insert(token)
        readyCount += 1
        firstFrameSamples.append(min(max(milliseconds, 0), 60_000))
        if firstFrameSamples.count > maximumSampleCount {
            firstFrameSamples.removeFirst(
                firstFrameSamples.count - maximumSampleCount
            )
        }
        return true
    }

    @discardableResult
    public mutating func finishAttempt(
        _ token: CompanionPlaybackAttemptToken,
        reason: CompanionPlaybackTerminalReason
    ) -> Bool {
        guard activeTokens.remove(token) != nil else { return false }
        readyTokens.remove(token)
        switch reason {
        case .ended:
            endedCount += 1
        case .failed:
            failureCount += 1
        case .cancelled:
            cancelledCount += 1
        }
        return true
    }

    public var snapshot: CompanionPlaybackHealthSnapshot {
        let sorted = firstFrameSamples.sorted()
        let p95: Int?
        if sorted.isEmpty {
            p95 = nil
        } else {
            let rank = Int(ceil(Double(sorted.count) * 0.95))
            p95 = sorted[min(max(rank - 1, 0), sorted.count - 1)]
        }
        return CompanionPlaybackHealthSnapshot(
            startedCount: startedCount,
            readyCount: readyCount,
            endedCount: endedCount,
            failureCount: failureCount,
            cancelledCount: cancelledCount,
            activeAttemptCount: activeTokens.count,
            peakActiveAttemptCount: peakActiveAttemptCount,
            firstFrameSampleCount: firstFrameSamples.count,
            firstFrameP95Milliseconds: p95,
            firstFrameTargetMilliseconds: firstFrameTargetMilliseconds
        )
    }
}
