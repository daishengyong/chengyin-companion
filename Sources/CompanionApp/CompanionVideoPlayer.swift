import AppKit
import AVFoundation
import CompanionContracts
import QuartzCore
import SwiftUI

func defaultMediaProjection(
    for mode: CompanionPresentationMode
) -> CompanionPresentationProjection {
    CompanionPresentationProjection.resolve(
        mode: mode,
        cropAnchors: [:],
        reducedDynamicEffectsEnabled: false
    )
}

func mediaProjection(
    for asset: CompanionVideoAsset,
    mode: CompanionPresentationMode
) -> CompanionPresentationProjection {
    let anchors = asset.cropAnchors.mapValues {
        CompanionMediaCropAnchor(x: $0.x, y: $0.y, scale: $0.scale)
    }
    let focalTracks = asset.focalTracks.mapValues { keyframes in
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
    let safeAreas = asset.safeAreas.mapValues {
        CompanionMediaSafeArea(
            x: $0.x,
            y: $0.y,
            width: $0.width,
            height: $0.height
        )
    }
    return CompanionPresentationProjection.resolve(
        mode: mode,
        cropAnchors: anchors,
        focalTracks: focalTracks,
        safeAreas: safeAreas,
        reducedDynamicEffectsEnabled: false
    )
}

private extension CompanionMediaGravity {
    var avLayerVideoGravity: AVLayerVideoGravity {
        switch self {
        case .aspectFit: .resizeAspect
        case .aspectFill: .resizeAspectFill
        }
    }
}

/// AVFoundation binding for the pure projection contract. Dynamic focal tracks
/// use a bounded 15 Hz observer; static content has no periodic observer.
struct LoopingActionVideoView: NSViewRepresentable {
    let url: URL
    var isMuted = true
    var loops = true
    var projection = defaultMediaProjection(for: .stage)
    var onPlaybackReady: (() -> Void)?
    var onPlaybackFailure: (() -> Void)?
    var onPlaybackEnded: (() -> Void)?

    final class Coordinator: @unchecked Sendable {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
        var currentURL: URL?
        var currentLoops = true
        var currentProjection = defaultMediaProjection(for: .stage)
        let playbackLifecycle = CompanionPlaybackLifecycleCoordinator()
        var focalTimeObserver: Any?

        func clearPlaybackObservation() {
            playbackLifecycle.clear()
            if let player, let focalTimeObserver {
                player.removeTimeObserver(focalTimeObserver)
            }
            focalTimeObserver = nil
        }

        deinit {
            clearPlaybackObservation()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> ActionVideoNSView {
        let view = ActionVideoNSView()
        updateCallbacks(context.coordinator)
        installPlayer(in: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: ActionVideoNSView, context: Context) {
        updateCallbacks(context.coordinator)
        if context.coordinator.currentURL != url
            || context.coordinator.currentLoops != loops {
            installPlayer(in: nsView, coordinator: context.coordinator)
            return
        }
        context.coordinator.player?.isMuted = isMuted
        updateProjection(
            projection,
            in: nsView,
            coordinator: context.coordinator
        )
        if loops, context.coordinator.player?.timeControlStatus != .playing {
            context.coordinator.player?.play()
        }
    }

    private func installPlayer(
        in view: ActionVideoNSView,
        coordinator: Coordinator
    ) {
        coordinator.clearPlaybackObservation()
        coordinator.player?.pause()
        coordinator.looper = nil
        coordinator.player = nil
        view.playerLayer.player = nil

        let item = CompanionMediaPrewarmCache.shared.playerItem(for: url)
        let player = loops ? AVQueuePlayer() : AVQueuePlayer(items: [item])
        player.isMuted = isMuted
        player.actionAtItemEnd = .none
        let looper = loops
            ? AVPlayerLooper(player: player, templateItem: item)
            : nil
        view.reset(projection)
        view.playerLayer.player = player
        coordinator.player = player
        coordinator.looper = looper
        coordinator.currentURL = url
        coordinator.currentLoops = loops
        coordinator.currentProjection = projection
        updateFocalObserver(in: view, coordinator: coordinator)
        installPlaybackObservation(
            item: player.currentItem ?? item,
            playerLayer: view.playerLayer,
            coordinator: coordinator
        )
        player.play()
    }

    private func updateProjection(
        _ newProjection: CompanionPresentationProjection,
        in view: ActionVideoNSView,
        coordinator: Coordinator
    ) {
        let observerRequirementChanged =
            coordinator.currentProjection.hasDynamicFocalTrack
                != newProjection.hasDynamicFocalTrack
        coordinator.currentProjection = newProjection
        let milliseconds = (coordinator.player?.currentTime().seconds ?? 0) * 1_000
        view.apply(newProjection, atMilliseconds: milliseconds)
        if observerRequirementChanged {
            updateFocalObserver(in: view, coordinator: coordinator)
        }
    }

    private func updateFocalObserver(
        in view: ActionVideoNSView,
        coordinator: Coordinator
    ) {
        guard let player = coordinator.player else { return }
        if let existing = coordinator.focalTimeObserver {
            player.removeTimeObserver(existing)
            coordinator.focalTimeObserver = nil
        }
        guard coordinator.currentProjection.hasDynamicFocalTrack else { return }
        coordinator.focalTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 15),
            queue: .main
        ) { [weak coordinator, weak view] time in
            Task { @MainActor [weak coordinator, weak view] in
                guard let coordinator, let view else { return }
                let seconds = time.seconds
                guard seconds.isFinite else { return }
                view.apply(
                    coordinator.currentProjection,
                    atMilliseconds: seconds * 1_000
                )
            }
        }
    }

    private func updateCallbacks(_ coordinator: Coordinator) {
        coordinator.playbackLifecycle.updateCallbacks(
            onPlaybackReady: onPlaybackReady,
            onPlaybackFailure: onPlaybackFailure,
            onPlaybackEnded: onPlaybackEnded
        )
    }

    private func installPlaybackObservation(
        item: AVPlayerItem,
        playerLayer: AVPlayerLayer,
        coordinator: Coordinator
    ) {
        coordinator.playbackLifecycle.begin(
            item: item,
            playerLayer: playerLayer,
            loops: loops
        )
    }

    static func dismantleNSView(
        _ nsView: ActionVideoNSView,
        coordinator: Coordinator
    ) {
        coordinator.clearPlaybackObservation()
        coordinator.player?.pause()
        coordinator.looper = nil
        coordinator.player = nil
        nsView.playerLayer.player = nil
    }
}

final class ActionVideoNSView: NSView {
    let playerLayer = AVPlayerLayer()
    private var projection = defaultMediaProjection(for: .stage)
    private var currentMilliseconds: Double = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = true
        playerLayer.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(playerLayer)
        apply(projection, atMilliseconds: 0)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        apply(projection, atMilliseconds: currentMilliseconds)
    }

    func reset(_ projection: CompanionPresentationProjection) {
        currentMilliseconds = 0
        apply(projection, atMilliseconds: 0)
    }

    func apply(
        _ projection: CompanionPresentationProjection,
        atMilliseconds milliseconds: Double
    ) {
        self.projection = projection
        currentMilliseconds = milliseconds.isFinite ? max(0, milliseconds) : 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.videoGravity = projection.gravity.avLayerVideoGravity
        playerLayer.frame = projection.playerLayerFrame(
            in: bounds,
            atMilliseconds: currentMilliseconds
        )
        CATransaction.commit()
    }
}
