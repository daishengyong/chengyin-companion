import AVFoundation
import CompanionContracts
import Foundation
import QuartzCore

/// Process-local aggregate used by diagnostics and soak tests. It records no
/// media identity or filesystem location.
final class CompanionPlaybackHealthMonitor: @unchecked Sendable {
    static let shared = CompanionPlaybackHealthMonitor()

    private let lock = NSLock()
    private var health = CompanionPlaybackHealthAccumulator()

    private init() {}

    func beginAttempt() -> CompanionPlaybackAttemptToken {
        lock.lock()
        defer { lock.unlock() }
        return health.beginAttempt()
    }

    func recordFirstFrame(
        for token: CompanionPlaybackAttemptToken,
        milliseconds: Int
    ) {
        lock.lock()
        defer { lock.unlock() }
        health.recordFirstFrame(for: token, milliseconds: milliseconds)
    }

    func finishAttempt(
        _ token: CompanionPlaybackAttemptToken,
        reason: CompanionPlaybackTerminalReason
    ) {
        lock.lock()
        defer { lock.unlock() }
        health.finishAttempt(token, reason: reason)
    }

    var snapshot: CompanionPlaybackHealthSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return health.snapshot
    }
}

/// Bounded cache of local AVURLAssets. It prepares metadata for the remaining
/// steps of a selected sequence without constructing hidden players or doing
/// network work. The active item and at most three likely next items are kept.
final class CompanionMediaPrewarmCache: @unchecked Sendable {
    static let shared = CompanionMediaPrewarmCache(maximumAssetCount: 4)

    private let lock = NSLock()
    private let maximumAssetCount: Int
    private var assets: [URL: AVURLAsset] = [:]
    private var recency: [URL] = []
    private var inFlight: Set<URL> = []

    init(maximumAssetCount: Int) {
        self.maximumAssetCount = min(max(maximumAssetCount, 1), 8)
    }

    func playerItem(for url: URL) -> AVPlayerItem {
        let asset = cachedOrNewAsset(for: url)
        scheduleMetadataLoad(asset: asset, url: url)
        return AVPlayerItem(asset: asset)
    }

    func prewarm(urls: [URL]) {
        var seen: Set<URL> = []
        for url in urls where url.isFileURL && seen.insert(url).inserted {
            let asset = cachedOrNewAsset(for: url)
            scheduleMetadataLoad(asset: asset, url: url)
            if seen.count >= maximumAssetCount { break }
        }
    }

    func clear() {
        lock.lock()
        assets.removeAll(keepingCapacity: false)
        recency.removeAll(keepingCapacity: false)
        inFlight.removeAll(keepingCapacity: false)
        lock.unlock()
    }

    private func cachedOrNewAsset(for url: URL) -> AVURLAsset {
        lock.lock()
        defer { lock.unlock() }
        if let asset = assets[url] {
            touch(url)
            return asset
        }
        let asset = AVURLAsset(url: url)
        assets[url] = asset
        touch(url)
        evictIfNeeded()
        return asset
    }

    private func scheduleMetadataLoad(asset: AVURLAsset, url: URL) {
        guard url.isFileURL else { return }
        lock.lock()
        let shouldStart = inFlight.insert(url).inserted
        lock.unlock()
        guard shouldStart else { return }

        Task.detached(priority: .utility) { [weak self] in
            let playable = (try? await asset.load(.isPlayable)) == true
            self?.finishMetadataLoad(url: url, playable: playable)
        }
    }

    private func finishMetadataLoad(url: URL, playable: Bool) {
        lock.lock()
        inFlight.remove(url)
        if !playable {
            assets.removeValue(forKey: url)
            recency.removeAll { $0 == url }
        }
        lock.unlock()
    }

    private func touch(_ url: URL) {
        recency.removeAll { $0 == url }
        recency.append(url)
    }

    private func evictIfNeeded() {
        while assets.count > maximumAssetCount, let oldest = recency.first {
            recency.removeFirst()
            assets.removeValue(forKey: oldest)
            inFlight.remove(oldest)
        }
    }
}

/// Owns exactly one AVPlayer attempt. `isReadyForDisplay` is the first-frame
/// signal; item readiness alone is not treated as visible playback. Every end,
/// failure or teardown is terminal exactly once, even if stale callbacks arrive.
final class CompanionPlaybackLifecycleCoordinator: @unchecked Sendable {
    private var statusObservation: NSKeyValueObservation?
    private var readyForDisplayObservation: NSKeyValueObservation?
    private var failureObserver: NSObjectProtocol?
    private var endObserver: NSObjectProtocol?
    private var attemptToken: CompanionPlaybackAttemptToken?
    private var attemptStartedAt: TimeInterval = 0
    private var firstFrameDelivered = false
    private var generation: UInt64 = 0
    private var onPlaybackReady: (() -> Void)?
    private var onPlaybackFailure: (() -> Void)?
    private var onPlaybackEnded: (() -> Void)?

    func updateCallbacks(
        onPlaybackReady: (() -> Void)?,
        onPlaybackFailure: (() -> Void)?,
        onPlaybackEnded: (() -> Void)?
    ) {
        self.onPlaybackReady = onPlaybackReady
        self.onPlaybackFailure = onPlaybackFailure
        self.onPlaybackEnded = onPlaybackEnded
    }

    func begin(
        item: AVPlayerItem,
        playerLayer: AVPlayerLayer,
        loops: Bool
    ) {
        clear()
        generation &+= 1
        let expectedGeneration = generation
        attemptToken = CompanionPlaybackHealthMonitor.shared.beginAttempt()
        attemptStartedAt = ProcessInfo.processInfo.systemUptime
        firstFrameDelivered = false

        readyForDisplayObservation = playerLayer.observe(
            \.isReadyForDisplay,
            options: [.initial, .new]
        ) { [weak self] layer, _ in
            guard layer.isReadyForDisplay, let self else { return }
            DispatchQueue.main.async { [self] in
                self.deliverFirstFrame(generation: expectedGeneration)
            }
        }
        statusObservation = item.observe(
            \.status,
            options: [.initial, .new]
        ) { [weak self] item, _ in
            guard item.status == .failed, let self else { return }
            DispatchQueue.main.async { [self] in
                self.deliverFailure(generation: expectedGeneration)
            }
        }
        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.deliverFailure(generation: expectedGeneration)
        }
        if !loops {
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.deliverEnd(generation: expectedGeneration)
            }
        }
    }

    func clear() {
        statusObservation?.invalidate()
        statusObservation = nil
        readyForDisplayObservation?.invalidate()
        readyForDisplayObservation = nil
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
        }
        failureObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        finishHealth(reason: .cancelled)
        generation &+= 1
        firstFrameDelivered = false
    }

    private func deliverFirstFrame(generation: UInt64) {
        guard generation == self.generation,
              !firstFrameDelivered,
              let token = attemptToken else { return }
        firstFrameDelivered = true
        let milliseconds = Int(
            max(
                0,
                (ProcessInfo.processInfo.systemUptime - attemptStartedAt) * 1_000
            ).rounded()
        )
        CompanionPlaybackHealthMonitor.shared.recordFirstFrame(
            for: token,
            milliseconds: milliseconds
        )
        onPlaybackReady?()
    }

    private func deliverFailure(generation: UInt64) {
        guard generation == self.generation, attemptToken != nil else { return }
        finishHealth(reason: .failed)
        onPlaybackFailure?()
    }

    private func deliverEnd(generation: UInt64) {
        guard generation == self.generation, attemptToken != nil else { return }
        finishHealth(reason: .ended)
        onPlaybackEnded?()
    }

    private func finishHealth(reason: CompanionPlaybackTerminalReason) {
        guard let token = attemptToken else { return }
        attemptToken = nil
        CompanionPlaybackHealthMonitor.shared.finishAttempt(token, reason: reason)
    }

    deinit {
        clear()
    }
}
