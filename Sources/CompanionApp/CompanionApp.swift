import SwiftUI
import AppKit
import Combine
import CompanionContracts

@main
struct ChengyinCompanionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                viewModel: appDelegate.viewModel,
                displayCatalog: appDelegate.displayCatalog
            )
                .frame(width: 480, height: 640)
                .padding(24)
        }
        .commands {
            CommandMenu("伴侣") {
                Button("切换显示大小") {
                    appDelegate.viewModel.toggleDisplayMode()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Button("迷你头像") {
                    appDelegate.viewModel.setDisplayMode(.head)
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])

                Button("半身陪伴") {
                    appDelegate.viewModel.setDisplayMode(.compact)
                }
                .keyboardShortcut("2", modifiers: [.command, .shift])

                Button("全屏互动舞台") {
                    appDelegate.viewModel.setDisplayMode(.full)
                }
                .keyboardShortcut("3", modifiers: [.command, .shift])

                Button("预览随机动作") {
                    appDelegate.viewModel.playRandomAction()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("预览任务完成庆祝") {
                    appDelegate.viewModel.previewEvent(.taskComplete)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("体验完整 Codex 工作弧") {
                    appDelegate.viewModel.previewCodexWorkArc()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])

                Button(
                    appDelegate.viewModel.catchGameActive
                        ? "结束“抓住我”"
                        : "开始“抓住我”"
                ) {
                    appDelegate.viewModel.toggleCatchGame()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(
                    appDelegate.viewModel.petGameActive
                        && !appDelegate.viewModel.catchGameActive
                )

                Button(
                    appDelegate.viewModel.hideGameActive
                        ? "结束“躲猫猫”"
                        : "开始“边缘躲猫猫”"
                ) {
                    appDelegate.viewModel.toggleHideGame()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                .disabled(
                    appDelegate.viewModel.petGameActive
                        && !appDelegate.viewModel.hideGameActive
                )

                Button(
                    appDelegate.viewModel.comboGameActive
                        ? "结束“动作连招”"
                        : "开始“动作连招”"
                ) {
                    appDelegate.viewModel.toggleComboGame()
                }
                .keyboardShortcut("j", modifiers: [.command, .shift])
                .disabled(
                    appDelegate.viewModel.petGameActive
                        && !appDelegate.viewModel.comboGameActive
                )

                Button(
                    appDelegate.viewModel.heartTraceGameActive
                        ? "结束“画心挑战”"
                        : "开始“画心挑战”"
                ) {
                    appDelegate.viewModel.toggleHeartTraceGame()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(
                    appDelegate.viewModel.petGameActive
                        && !appDelegate.viewModel.heartTraceGameActive
                )

                Button(
                    appDelegate.viewModel.rhythmGameActive
                        ? "结束“心跳节拍”"
                        : "开始“心跳节拍”"
                ) {
                    appDelegate.viewModel.toggleRhythmGame()
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .disabled(
                    appDelegate.viewModel.petGameActive
                        && !appDelegate.viewModel.rhythmGameActive
                )

                Button(
                    appDelegate.viewModel.feedGameActive
                        ? "结束“投喂时刻”"
                        : "开始“投喂时刻”"
                ) {
                    appDelegate.viewModel.toggleFeedGame()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(
                    appDelegate.viewModel.petGameActive
                        && !appDelegate.viewModel.feedGameActive
                )
            }
        }
    }
}

private struct CompanionPanelRoot: View {
    @ObservedObject var viewModel: CompanionViewModel
    @ObservedObject var displayCatalog: CompanionDisplayCatalog
    @Environment(\.accessibilityReduceMotion) private var systemReducesMotion
    @Environment(\.accessibilityReduceTransparency) private var systemReducesTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        ContentView(
            viewModel: viewModel,
            presentationVisibleFrame: selectedVisibleFrame
        )
            .frame(
                width: contentSize(for: viewModel.displayMode).width,
                height: contentSize(for: viewModel.displayMode).height
            )
            .background(
                WindowConfigurator(
                    mode: viewModel.displayMode,
                    playPalettePresented: viewModel.playPalettePresented,
                    appearance: viewModel.presentationAppearance,
                    displayTarget: viewModel.displayTarget,
                    displayCatalog: displayCatalog,
                    displayCatalogRevision: displayCatalog.revision,
                    systemReducesTransparency: systemReducesTransparency,
                    systemIncreasesContrast: colorSchemeContrast == .increased,
                    animatesTransitions: !viewModel.reducedDynamicEffectsEnabled
                        && !systemReducesMotion
                )
            )
    }

    private func contentSize(for mode: CompanionDisplayMode) -> NSSize {
        if mode == .head, viewModel.playPalettePresented {
            return CompanionWindowPolicy.playPaletteContentSize(
                visibleFrame: selectedVisibleFrame
            )
        }
        return CompanionWindowPolicy.contentSize(
            for: presentationMode(for: mode),
            visibleFrame: selectedVisibleFrame
        )
    }

    private var selectedVisibleFrame: CGRect {
        displayCatalog.companionWindowSelection(
            for: viewModel.displayTarget
        ).descriptor.visibleFrame
    }
}

private final class CompanionPanel: NSPanel {
    // A nonactivating panel may become key without activating the application.
    // SwiftUI controls and the custom pet gesture surface need that key-window
    // delivery path in order to receive clicks while the editor stays active.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    let viewModel = CompanionViewModel()
    let displayCatalog = CompanionDisplayCatalog()
    private var companionPanel: CompanionPanel?
    private var visibilityKeeper: CompanionWindowVisibilityKeeper?
    private var panelGeometryObservation: AnyCancellable?
    private var panelGeometryGeneration: UInt64 = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let initialSize = CompanionWindowPolicy.contentSize(
            for: viewModel.displayMode.presentationMode,
            visibleFrame: displayCatalog.companionWindowSelection(
                for: viewModel.displayTarget
            ).descriptor.visibleFrame
        )
        let panel = CompanionPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "澄音"
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.worksWhenModal = true
        panel.contentView = NSHostingView(
            rootView: CompanionPanelRoot(
                viewModel: viewModel,
                displayCatalog: displayCatalog
            )
        )
        companionPanel = panel
        let keeper = CompanionWindowVisibilityKeeper(application: NSApp)
        visibilityKeeper = keeper
        keeper.start()
        startPanelGeometryRecovery()
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelGeometryObservation?.cancel()
        panelGeometryObservation = nil
        visibilityKeeper?.stop()
        visibilityKeeper = nil
        companionPanel?.orderOut(nil)
        companionPanel = nil
    }

    /// SwiftUI can replace the representable that owns `WindowConfigurator`
    /// during the same click that changes a pet into a stage. The configurator
    /// remains the primary animated path; this delayed observer only repairs a
    /// size transition if that replacement dropped the AppKit update. Audio is
    /// never allowed to continue inside a stale pet-sized frame merely because
    /// one transient representable was detached.
    private func startPanelGeometryRecovery() {
        panelGeometryObservation = viewModel.$displayMode
            .combineLatest(
                viewModel.$playPalettePresented,
                viewModel.$displayTarget
            )
            .sink { [weak self] mode, palettePresented, _ in
                self?.schedulePanelGeometryRecovery(
                    mode: mode,
                    palettePresented: palettePresented
                )
            }
    }

    private func schedulePanelGeometryRecovery(
        mode: CompanionDisplayMode,
        palettePresented: Bool
    ) {
        panelGeometryGeneration &+= 1
        if panelGeometryGeneration == 0 {
            panelGeometryGeneration = 1
        }
        let generation = panelGeometryGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [weak self] in
            guard let self,
                  self.panelGeometryGeneration == generation,
                  self.viewModel.displayMode == mode,
                  self.viewModel.playPalettePresented == palettePresented
            else { return }
            self.repairPanelGeometryIfNeeded(
                mode: mode,
                palettePresented: palettePresented
            )
        }
    }

    private func repairPanelGeometryIfNeeded(
        mode: CompanionDisplayMode,
        palettePresented: Bool
    ) {
        guard let panel = companionPanel else { return }
        let selection = displayCatalog.companionWindowSelection(
            for: viewModel.displayTarget
        )
        let targetScreen = displayCatalog.screen(
            for: viewModel.displayTarget,
            currentScreen: panel.screen
        )
        let visibleFrame = targetScreen?.visibleFrame
            ?? selection.descriptor.visibleFrame
        let contentSize = mode == .head && palettePresented
            ? CompanionWindowPolicy.playPaletteContentSize(
                visibleFrame: visibleFrame
            )
            : CompanionWindowPolicy.contentSize(
                for: mode.presentationMode,
                visibleFrame: visibleFrame
            )
        let targetSize = panel.frameRect(
            forContentRect: NSRect(origin: .zero, size: contentSize)
        ).size
        guard let recoveryFrame = CompanionWindowPolicy.geometryRecoveryFrame(
            currentFrame: panel.frame,
            targetFrameSize: targetSize,
            mode: mode.presentationMode,
            visibleFrame: visibleFrame
        ) else { return }
        panel.setFrame(
            recoveryFrame,
            display: true,
            animate: false
        )
        displayCatalog.noteCompanionWindowScreen(targetScreen ?? panel.screen)
        panel.level = .floating
        panel.orderFrontRegardless()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // The companion lives in an AppKit panel rather than a SwiftUI scene
        // window. Closing Settings or a transient popover must not terminate
        // the pet; explicit Quit remains available in the UI and app menu.
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            visibilityKeeper?.reveal()
        }
        return true
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    let mode: CompanionDisplayMode
    let playPalettePresented: Bool
    let appearance: CompanionPresentationAppearance
    let displayTarget: CompanionDisplayTarget
    let displayCatalog: CompanionDisplayCatalog
    let displayCatalogRevision: Int
    let systemReducesTransparency: Bool
    let systemIncreasesContrast: Bool
    let animatesTransitions: Bool

    final class Coordinator {
        weak var window: NSWindow?
        var configurationGeneration: UInt64 = 0
        var lastMode: CompanionDisplayMode?
        var lastPlayPalettePresented = false
        var lastAppearance: CompanionPresentationAppearance?
        var lastDisplayTarget: CompanionDisplayTarget?
        var lastDisplayCatalogRevision = -1
        var lastSystemReducesTransparency = false
        var lastSystemIncreasesContrast = false
        var lastAnimatesTransitions = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        scheduleConfiguration(for: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard
            context.coordinator.lastMode != mode
                || context.coordinator.lastPlayPalettePresented != playPalettePresented
                || context.coordinator.lastAppearance != appearance
                || context.coordinator.lastDisplayTarget != displayTarget
                || context.coordinator.lastDisplayCatalogRevision != displayCatalogRevision
                || context.coordinator.lastSystemReducesTransparency != systemReducesTransparency
                || context.coordinator.lastSystemIncreasesContrast != systemIncreasesContrast
                || context.coordinator.lastAnimatesTransitions != animatesTransitions
        else { return }
        scheduleConfiguration(for: nsView, coordinator: context.coordinator)
    }

    /// Window-size changes are requested from inside the control that triggered
    /// the SwiftUI tree replacement. Keep a stable panel reference and coalesce
    /// rapid mode/palette updates so a detached representable cannot silently
    /// drop the expansion while its audio continues playing.
    private func scheduleConfiguration(
        for view: NSView,
        coordinator: Coordinator
    ) {
        coordinator.configurationGeneration &+= 1
        if coordinator.configurationGeneration == 0 {
            coordinator.configurationGeneration = 1
        }
        let generation = coordinator.configurationGeneration
        applyScheduledConfiguration(
            for: view,
            coordinator: coordinator,
            generation: generation,
            attemptsRemaining: 3
        )
    }

    private func applyScheduledConfiguration(
        for view: NSView,
        coordinator: Coordinator,
        generation: UInt64,
        attemptsRemaining: Int
    ) {
        DispatchQueue.main.async {
            guard coordinator.configurationGeneration == generation else {
                return
            }
            guard let window = view.window ?? coordinator.window else {
                guard attemptsRemaining > 0 else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    applyScheduledConfiguration(
                        for: view,
                        coordinator: coordinator,
                        generation: generation,
                        attemptsRemaining: attemptsRemaining - 1
                    )
                }
                return
            }
            coordinator.window = window
            configure(
                window,
                mode: mode,
                playPalettePresented: playPalettePresented,
                appearance: appearance,
                displayTarget: displayTarget,
                previousMode: coordinator.lastMode,
                animatesTransitions: animatesTransitions
            )
            rememberConfiguration(in: coordinator)
        }
    }

    private func rememberConfiguration(in coordinator: Coordinator) {
        coordinator.lastMode = mode
        coordinator.lastPlayPalettePresented = playPalettePresented
        coordinator.lastAppearance = appearance
        coordinator.lastDisplayTarget = displayTarget
        coordinator.lastDisplayCatalogRevision = displayCatalogRevision
        coordinator.lastSystemReducesTransparency = systemReducesTransparency
        coordinator.lastSystemIncreasesContrast = systemIncreasesContrast
        coordinator.lastAnimatesTransitions = animatesTransitions
    }

    private func configure(
        _ window: NSWindow,
        mode: CompanionDisplayMode,
        playPalettePresented: Bool,
        appearance: CompanionPresentationAppearance,
        displayTarget: CompanionDisplayTarget,
        previousMode: CompanionDisplayMode?,
        animatesTransitions: Bool
    ) {
        displayCatalog.noteCompanionWindowScreen(window.screen)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating
        window.collectionBehavior = CompanionWindowVisibilityPolicy
            .steadyCollectionBehavior
        window.canHide = false
        window.hidesOnDeactivate = false
        window.isRestorable = false

        let presentation = presentationMode(for: mode)
        let petMode = CompanionWindowPolicy.isPetPresentation(presentation)
        let surfacePlan = CompanionPresentationSurfacePolicy.plan(
            mode: presentation,
            requestedAppearance: appearance,
            systemReduceTransparencyEnabled: systemReducesTransparency,
            systemIncreaseContrastEnabled: systemIncreasesContrast
        )
        window.hasShadow = surfacePlan.showsWindowShadow
        window.standardWindowButton(.closeButton)?.isHidden = petMode
        window.standardWindowButton(.miniaturizeButton)?.isHidden = petMode
        window.standardWindowButton(.zoomButton)?.isHidden = petMode

        let targetScreen = displayCatalog.screen(
            for: displayTarget,
            currentScreen: window.screen
        )
        let visibleFrame = targetScreen?.visibleFrame
            ?? CompanionWindowPolicy.fallbackVisibleFrame
        let contentSize = mode == .head && playPalettePresented
            ? CompanionWindowPolicy.playPaletteContentSize(
                visibleFrame: visibleFrame
            )
            : CompanionWindowPolicy.contentSize(
                for: presentation,
                visibleFrame: visibleFrame
            )
        let frameSize = window.frameRect(
            forContentRect: NSRect(origin: .zero, size: contentSize)
        ).size

        let origin: CGPoint
        if mode == .head,
           playPalettePresented,
           previousMode == .head {
            origin = CGPoint(
                x: min(
                    visibleFrame.maxX - frameSize.width,
                    max(visibleFrame.minX, window.frame.maxX - frameSize.width)
                ),
                y: min(
                    visibleFrame.maxY - frameSize.height,
                    max(visibleFrame.minY, window.frame.minY)
                )
            )
        } else if mode == .head,
                  !playPalettePresented,
                  previousMode == .head,
                  window.frame.width > frameSize.width + 1 {
            origin = CGPoint(
                x: min(
                    visibleFrame.maxX - frameSize.width,
                    max(visibleFrame.minX, window.frame.maxX - frameSize.width)
                ),
                y: min(
                    visibleFrame.maxY - frameSize.height,
                    max(visibleFrame.minY, window.frame.minY)
                )
            )
        } else {
            origin = CompanionWindowPolicy.initialOrigin(
                for: presentation,
                visibleFrame: visibleFrame,
                windowFrameSize: frameSize,
                savedPetOrigin: PetWindowPositionStore.load()
            )
        }

        window.setFrame(
            NSRect(origin: origin, size: frameSize),
            display: true,
            animate: previousMode != nil && animatesTransitions
        )
        displayCatalog.noteCompanionWindowScreen(targetScreen ?? window.screen)
        window.level = .floating
        window.orderFrontRegardless()
    }
}

private func presentationMode(for mode: CompanionDisplayMode) -> CompanionPresentationMode {
    mode.presentationMode
}
