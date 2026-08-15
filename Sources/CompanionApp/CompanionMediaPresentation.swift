import AppKit
import CompanionContracts
import SwiftUI

/// Focused media composition for actions, scenes, idle presence and local sprite fallbacks.
///
/// `ContentView` chooses the three presentation shapes; this module owns the
/// media ladder within those shapes: validated pack asset, bundled video,
/// then an offline sprite. It performs no content selection or window changes.
struct CompanionActionView: View {
    @ObservedObject var viewModel: CompanionViewModel
    let action: CompanionAction
    let outfit: CompanionOutfit
    let eventKind: CompanionEventKind?
    let presentationMode: CompanionPresentationMode

    var body: some View {
        if let asset = viewModel.contentPackVideo(
            for: action,
            eventKind: eventKind
        ) {
            ContentPackVideoView(
                viewModel: viewModel,
                asset: asset,
                presentationMode: presentationMode
            )
        } else if let url = bundledEventVideoURL(eventKind: eventKind)
            ?? bundledActionVideoURL(action: action, outfit: outfit) {
            let hasNativeAudio = eventKind == nil || eventKind == .taskComplete
            LoopingActionVideoView(
                url: url,
                isMuted: !hasNativeAudio,
                loops: !hasNativeAudio,
                projection: defaultMediaProjection(for: presentationMode)
            )
        } else {
            CompanionEventSpriteView(action: action, outfit: outfit)
        }
    }
}

struct CompanionSceneVideoView: View {
    @ObservedObject var viewModel: CompanionViewModel
    let scene: CompanionScene
    let presentationMode: CompanionPresentationMode

    var body: some View {
        if let asset = viewModel.contentPackVideo(for: scene) {
            ContentPackVideoView(
                viewModel: viewModel,
                asset: asset,
                presentationMode: presentationMode
            )
            .aspectRatio(16 / 9, contentMode: .fit)
        } else if let url = bundledVideoURL(named: scene.resourceName) {
            LoopingActionVideoView(
                url: url,
                isMuted: !scene.hasNativeAudio,
                loops: !scene.hasNativeAudio,
                projection: defaultMediaProjection(for: presentationMode)
                )
                .aspectRatio(16 / 9, contentMode: .fit)
        } else {
            CompanionIdleVideoView(
                viewModel: viewModel,
                isSpeaking: false,
                presentationMode: presentationMode
            )
        }
    }
}

struct CompanionMiniSceneVideoView: View {
    @ObservedObject var viewModel: CompanionViewModel
    let scene: CompanionMiniScene
    let presentationMode: CompanionPresentationMode

    var body: some View {
        if let asset = viewModel.contentPackVideo(for: scene) {
            ContentPackVideoView(
                viewModel: viewModel,
                asset: asset,
                presentationMode: presentationMode
            )
            .aspectRatio(
                presentationMode == .pet ? 1 : 16 / 9,
                contentMode: .fit
            )
        } else if let url = bundledVideoURL(named: scene.resourceName) {
            LoopingActionVideoView(
                url: url,
                isMuted: false,
                loops: false,
                projection: defaultMediaProjection(for: presentationMode)
            )
            .aspectRatio(
                presentationMode == .pet ? 1 : 16 / 9,
                contentMode: .fit
            )
        } else {
            CompanionIdleVideoView(
                viewModel: viewModel,
                isSpeaking: false,
                presentationMode: presentationMode
            )
        }
    }
}

struct CompanionIdleVideoView: View {
    @ObservedObject var viewModel: CompanionViewModel
    let isSpeaking: Bool
    let presentationMode: CompanionPresentationMode

    var body: some View {
        let policy = CompanionPerformancePolicy(
            reducedDynamicEffectsEnabled: viewModel.reducedDynamicEffectsEnabled,
            systemReduceMotionEnabled: false,
            requestedPlayback: viewModel.playbackMode == .audioVisual
                ? .audiovisual
                : .audioOnly
        )
        if !policy.permitsLoopingVideo {
            LiveSpriteView(isSpeaking: isSpeaking)
        } else if !viewModel.contentPackIdleVideos.isEmpty
            || !bundledSharedLandscapeVideoAssets().isEmpty {
            SharedLandscapeCompanionView(
                viewModel: viewModel,
                runtimeAssets: viewModel.contentPackIdleVideos,
                presentationMode: presentationMode
            )
        } else if let url = bundledVideoURL(named: "companion-idle-body") {
            LoopingActionVideoView(
                url: url,
                projection: defaultMediaProjection(for: presentationMode)
            )
        } else {
            LiveSpriteView(isSpeaking: isSpeaking)
        }
    }
}

private struct ContentPackVideoView: View {
    @ObservedObject var viewModel: CompanionViewModel
    let asset: CompanionVideoAsset
    let presentationMode: CompanionPresentationMode

    var body: some View {
        LoopingActionVideoView(
            url: asset.url,
            isMuted: !asset.hasNativeAudio,
            loops: asset.loops,
            projection: mediaProjection(
                for: asset,
                mode: presentationMode
            ),
            onPlaybackReady: {
                viewModel.reportContentPlaybackReady(asset)
            },
            onPlaybackFailure: {
                viewModel.reportContentPlaybackFailure(asset)
            }
        )
    }
}

struct CompanionEventSpriteView: View {
    let action: CompanionAction
    let outfit: CompanionOutfit

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let cellSide = min(width, height)
            let row = action.rawValue / 3
            let column = action.rawValue % 3

            ZStack {
                if let sheet = bundledImage(named: outfit.resourceName) {
                    Image(nsImage: sheet)
                        .resizable()
                        .frame(width: cellSide * 3, height: cellSide * 3)
                        .offset(
                            x: (1 - CGFloat(column)) * cellSide,
                            y: (1 - CGFloat(row)) * cellSide
                        )
                } else {
                    CodeOnlyPersonaFallback(
                        symbol: "sparkles",
                        accent: .pink,
                        isSpeaking: false
                    )
                    .frame(width: cellSide, height: cellSide)
                }
            }
            .frame(width: width, height: height)
            .clipped()
            .shadow(color: .black.opacity(0.32), radius: 18, y: 12)
        }
    }
}

private func bundledEventVideoURL(eventKind: CompanionEventKind?) -> URL? {
    guard let eventKind else { return nil }
    return bundledVideoURL(named: "companion-event-\(eventKind.rawValue)")
}

private func bundledActionVideoURL(
    action: CompanionAction,
    outfit: CompanionOutfit
) -> URL? {
    let name = "companion-action-\(outfit.rawValue)-\(action.rawValue)"
    return bundledVideoURL(named: name)
        ?? bundledVideoURL(named: "companion-action-\(action.rawValue)")
}

private func bundledVideoURL(named name: String) -> URL? {
    if let url = Bundle.main.url(forResource: name, withExtension: "mov") {
        return url
    }
    #if DEBUG
    if let url = Bundle.module.url(forResource: name, withExtension: "mov") {
        return url
    }
    #endif
    return nil
}

private func bundledSharedLandscapeVideoAssets() -> [CompanionVideoAsset] {
    [
        "companion-master-landscape",
        "companion-scene-lunar-orbit",
        "companion-scene-undersea-room",
        "companion-scene-time-cafe",
        "companion-scene-rain-portal"
    ].compactMap { name in
        bundledVideoURL(named: name).map {
            CompanionVideoAsset.bundled(
                id: name,
                url: $0,
                hasNativeAudio: false,
                loops: true
            )
        }
    }
}

struct LiveSpriteView: View {
    let isSpeaking: Bool

    @State private var isBlinking = false
    @State private var alternateMouth = false

    private var frameIndex: Int {
        if isSpeaking {
            return alternateMouth ? 3 : 2
        }
        return isBlinking ? 1 : 0
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let cellSide = max(width, height)
            let row = frameIndex / 2
            let column = frameIndex % 2

            ZStack {
                if let spriteSheet = bundledImage(named: "companion-live-sprites-alpha-v1") {
                    Image(nsImage: spriteSheet)
                        .resizable()
                        .frame(width: cellSide * 2, height: cellSide * 2)
                        .offset(
                            x: (0.5 - CGFloat(column)) * cellSide,
                            y: (0.5 - CGFloat(row)) * cellSide
                        )
                } else {
                    CodeOnlyPersonaFallback(
                        symbol: "person.crop.circle.fill",
                        accent: .cyan,
                        isSpeaking: isSpeaking
                    )
                    .frame(width: cellSide, height: cellSide)
                }
            }
            .frame(width: width, height: height)
            .clipped()
            .shadow(color: .black.opacity(0.34), radius: 16, y: 10)
        }
        .task(id: isSpeaking) {
            alternateMouth = false
            guard isSpeaking else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 170_000_000)
                alternateMouth.toggle()
            }
        }
        .task {
            while !Task.isCancelled {
                let delay = UInt64.random(in: 3_000_000_000...5_500_000_000)
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled, !isSpeaking else { continue }
                isBlinking = true
                try? await Task.sleep(nanoseconds: 135_000_000)
                isBlinking = false
            }
        }
    }
}

struct AnimatedHeadPetView: View {
    @ObservedObject var viewModel: CompanionViewModel
    let isSpeaking: Bool

    var body: some View {
        let policy = CompanionPerformancePolicy(
            reducedDynamicEffectsEnabled: viewModel.reducedDynamicEffectsEnabled,
            systemReduceMotionEnabled: false,
            requestedPlayback: viewModel.playbackMode == .audioVisual
                ? .audiovisual
                : .audioOnly
        )
        if !policy.permitsLoopingVideo {
            LiveSpriteView(isSpeaking: isSpeaking)
        } else if viewModel.contentPackIdleVideos.isEmpty
            && bundledSharedLandscapeVideoAssets().isEmpty {
            SpriteHeadPetView(isSpeaking: isSpeaking)
        } else {
            SharedLandscapeCompanionView(
                viewModel: viewModel,
                runtimeAssets: viewModel.contentPackIdleVideos,
                presentationMode: .pet
            )
        }
    }
}

private struct SharedLandscapeCompanionView: View {
    @ObservedObject var viewModel: CompanionViewModel
    let runtimeAssets: [CompanionVideoAsset]
    let presentationMode: CompanionPresentationMode

    private var isHeadCrop: Bool {
        presentationMode == .pet
    }

    @State private var clipIndex = 0
    private let rotationTimer = Timer.publish(
        every: 11.5,
        on: .main,
        in: .common
    ).autoconnect()

    private var clips: [CompanionVideoAsset] {
        runtimeAssets.isEmpty
            ? bundledSharedLandscapeVideoAssets()
            : runtimeAssets
    }

    var body: some View {
        Group {
            if clips.isEmpty {
                Color.clear
            } else {
                let safeIndex = clipIndex % clips.count
                let asset = clips[safeIndex]
                Group {
                    if asset.packReference == nil {
                        LoopingActionVideoView(
                            url: asset.url,
                            isMuted: true,
                            loops: true,
                            projection: defaultMediaProjection(
                                for: presentationMode
                            )
                        )
                    } else {
                        ContentPackVideoView(
                            viewModel: viewModel,
                            asset: asset,
                            presentationMode: presentationMode
                        )
                    }
                }
                .id(asset.id)
                .transition(.opacity)
            }
        }
        .background(Color.black.opacity(isHeadCrop ? 0.12 : 0.28))
        .clipShape(
            RoundedRectangle(
                cornerRadius: isHeadCrop ? 24 : 30,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: isHeadCrop ? 24 : 30,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .onReceive(rotationTimer) { _ in
            guard clips.count > 1 else { return }
            clipIndex = (clipIndex + 1) % clips.count
        }
        .animation(.easeInOut(duration: 0.24), value: clipIndex)
    }
}

private struct SpriteHeadPetView: View {
    let isSpeaking: Bool

    @State private var frameIndex = 0
    @State private var floating = false
    @State private var lookingOffset: CGFloat = 0
    @State private var idleSequenceIndex = 0

    var body: some View {
        GeometryReader { proxy in
            let cellSide = max(proxy.size.width, proxy.size.height)
            let row = frameIndex / 4
            let column = frameIndex % 4

            ZStack {
                if let spriteSheet = bundledImage(named: "companion-head-sprites-alpha") {
                    Image(nsImage: spriteSheet)
                        .resizable()
                        .frame(width: cellSide * 4, height: cellSide * 4)
                        .offset(
                            x: (1.5 - CGFloat(column)) * cellSide,
                            y: (1.5 - CGFloat(row)) * cellSide
                        )
                } else {
                    CodeOnlyPersonaFallback(
                        symbol: "heart.fill",
                        accent: .pink,
                        isSpeaking: isSpeaking
                    )
                    .frame(width: cellSide, height: cellSide)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .offset(x: lookingOffset, y: floating ? -4 : 3)
            .rotationEffect(.degrees(floating ? 2.2 : -2.2))
            .scaleEffect(floating ? 1.035 : 0.985, anchor: .bottom)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.15).repeatForever(autoreverses: true)
            ) {
                floating = true
            }
        }
        .task(id: isSpeaking) {
            while !Task.isCancelled {
                if isSpeaking {
                    frameIndex = [8, 0, 11, 8, 14, 0].randomElement() ?? 8
                    try? await Task.sleep(nanoseconds: 280_000_000)
                } else {
                    let sequence = [
                        0, 1, 0, 2, 0, 4, 0, 6, 0,
                        3, 0, 5, 0, 7, 0, 11, 0, 13
                    ]
                    frameIndex = sequence[idleSequenceIndex % sequence.count]
                    idleSequenceIndex += 1
                    lookingOffset = frameIndex == 2
                        ? -2
                        : (frameIndex == 3 ? 2 : lookingOffset * 0.55)
                    try? await Task.sleep(
                        nanoseconds: UInt64.random(
                            in: 520_000_000...920_000_000
                        )
                    )
                    lookingOffset *= 0.55
                }
            }
        }
    }
}

/// A deliberately non-person-specific, asset-free fallback for the public MIT
/// checkout. It keeps the pet visible and responsive without redistributing
/// private Starter media or implying that those assets share the code license.
private struct CodeOnlyPersonaFallback: View {
    let symbol: String
    let accent: Color
    let isSpeaking: Bool

    @State private var floating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.58), .black.opacity(0.9)],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 150
                    )
                )
            Circle()
                .stroke(.white.opacity(0.24), lineWidth: 1)
            Image(systemName: symbol)
                .font(.system(size: isSpeaking ? 50 : 44, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .scaleEffect(floating ? 1.08 : 0.94)
                .rotationEffect(.degrees(floating ? 3 : -3))
            Image(systemName: "sparkle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .offset(x: 38, y: -38)
        }
        .padding(8)
        .onAppear {
            withAnimation(
                .easeInOut(duration: isSpeaking ? 0.34 : 1.05)
                .repeatForever(autoreverses: true)
            ) {
                floating = true
            }
        }
    }
}

private func bundledImage(named name: String) -> NSImage? {
    if let url = Bundle.main.url(forResource: name, withExtension: "png"),
       let image = NSImage(contentsOf: url) {
        return image
    }
    #if DEBUG
    if let url = Bundle.module.url(forResource: name, withExtension: "png"),
       let image = NSImage(contentsOf: url) {
        return image
    }
    #endif
    return nil
}
