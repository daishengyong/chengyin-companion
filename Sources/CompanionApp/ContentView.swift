import AppKit
import CompanionContracts
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: CompanionViewModel
    let presentationVisibleFrame: CGRect
    @State private var compactHover = false
    @Environment(\.accessibilityReduceMotion) var reducesMotion
    @Environment(\.accessibilityReduceTransparency) var reducesTransparency
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                switch viewModel.displayMode {
                case .full:
                    fullView
                case .compact:
                    compactView
                case .head:
                    headView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            if viewModel.playPalettePresented {
                CompanionPlayPaletteOverlay(viewModel: viewModel, layout: CompanionPlayPaletteLayout.plan(visibleFrame: presentationVisibleFrame))
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .topTrailing
                    )
                    .padding(10)
                    .transition(.scale(scale: 0.92, anchor: .bottomTrailing).combined(with: .opacity))
            }

            CompanionFirstSessionCoachLayer(viewModel: viewModel)
        }
        .background(CompanionPresentationSurface(plan: surfacePlan))
        .preferredColorScheme(.dark)
    }
    private var presenceColor: Color {
        switch viewModel.codexVisualState {
        case .working:
            return .blue
        case .completed:
            return .yellow
        case .awaitingReply:
            return .pink
        case .idle:
            return viewModel.directInteractionActive ? .pink : .green
        }
    }

    private var fullStageSize: CGSize {
        let width = min(
            1180,
            presentationVisibleFrame.width * 0.88,
            presentationVisibleFrame.height * 0.68 * 16 / 9
        )
        return CGSize(width: width, height: width * 9 / 16)
    }

    private var fullView: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()

            if viewModel.isPresentingMedia {
                PetResponsiveLayer(
                    viewModel: viewModel,
                    allowsWindowDrag: false
                ) {
                    companionMedia()
                }
                .frame(
                    width: fullStageSize.width,
                    height: fullStageSize.height
                )
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("澄音")
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                            Text(viewModel.status)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.68))
                        }
                        Spacer()
                        RelationshipStatusPill(
                            viewModel: viewModel,
                            showsChapter: true
                        )
                        WorkdayStatusPill(
                            viewModel: viewModel,
                            showsLabel: true
                        )
                        ActionPlayMenu(viewModel: viewModel, showsTitle: true)
                        PlaybackModeButton(viewModel: viewModel, showsTitle: true)
                        DisplayModeButtons(viewModel: viewModel)
                        Button {
                            NSApp.terminate(nil)
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.70))
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.horizontal, 24)
                    .padding(.top, 14)

                    Spacer(minLength: 8)

                    PetResponsiveLayer(
                        viewModel: viewModel,
                        allowsWindowDrag: false
                    ) {
                        companionMedia()
                    }
                    .frame(
                        width: fullStageSize.width,
                        height: fullStageSize.height
                    )

                    VStack(spacing: 12) {
                        Text(viewModel.latestCompanionText)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.94))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 11)
                            .background(.ultraThinMaterial, in: Capsule())

                        HStack(spacing: 18) {
                            interactionHint("cursorarrow.click.2", "单击回应")
                            interactionHint("hand.tap.fill", "长按抚摸")
                            interactionHint("arrow.up.and.down.and.arrow.left.and.right", "拖动与甩动")
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .animation(presentationAnimation, value: viewModel.eventAction)
        .animation(presentationAnimation, value: viewModel.activeScene)
        .animation(presentationAnimation, value: viewModel.activeMiniScene)
        .animation(presentationAnimation, value: viewModel.activeContentSequence)
    }

    private var compactView: some View {
        ZStack {
            if viewModel.isPresentingMedia || viewModel.heartTraceGameActive {
                PetResponsiveLayer(
                    viewModel: viewModel,
                    allowsWindowDrag: !viewModel.heartTraceGameActive
                ) {
                    companionMedia()
                }
                .frame(width: 540, height: 303.75)
                .transition(.opacity)
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 9) {
                        Circle()
                            .fill(presenceColor)
                            .frame(width: 8, height: 8)
                            .shadow(
                                color: presenceColor,
                                radius: 5
                            )

                        Text(viewModel.status)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .lineLimit(1)

                        Spacer()

                        RelationshipStatusPill(
                            viewModel: viewModel,
                            showsChapter: false
                        )
                        WorkdayStatusPill(
                            viewModel: viewModel,
                            showsLabel: false
                        )
                        ActionPlayMenu(viewModel: viewModel)
                        PlaybackModeButton(viewModel: viewModel)
                        DisplayModeButtons(viewModel: viewModel)

                        Button {
                            NSApp.terminate(nil)
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                        .help("退出澄音")
                    }
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .opacity(compactHover ? 1 : 0.82)

                    PetResponsiveLayer(
                        viewModel: viewModel,
                        allowsWindowDrag: true
                    ) {
                        companionMedia()
                    }
                    .frame(width: 520, height: 292.5)

                    Text(viewModel.latestCompanionText)
                        .font(.system(size: 13.5, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .padding(26)
            }
        }
        .animation(presentationAnimation, value: viewModel.eventAction)
        .animation(presentationAnimation, value: viewModel.activeMiniScene)
        .animation(presentationAnimation, value: viewModel.activeContentSequence)
        .onHover { compactHover = $0 }
        .contextMenu {
            Button("打开互动舞台") { viewModel.setDisplayMode(.full) }
            Button("缩成头像") { viewModel.setDisplayMode(.head) }
            Button("预览随机动作") { viewModel.playRandomAction() }
            Button("预览任务完成动画") {
                viewModel.previewEvent(.taskComplete)
            }
            Button(
                viewModel.catchGameActive
                    ? "结束“抓住我”"
                    : "开始“20 秒抓住我”"
            ) {
                viewModel.toggleCatchGame()
            }
            .disabled(viewModel.petGameActive && !viewModel.catchGameActive)
            Button(
                viewModel.hideGameActive
                    ? "结束“躲猫猫”"
                    : "开始“边缘躲猫猫”"
            ) {
                viewModel.toggleHideGame()
            }
            .disabled(viewModel.petGameActive && !viewModel.hideGameActive)
            Button(
                viewModel.comboGameActive
                    ? "结束“动作连招”"
                    : "开始“动作连招”"
            ) {
                viewModel.toggleComboGame()
            }
            .disabled(viewModel.petGameActive && !viewModel.comboGameActive)
            Button(
                viewModel.heartTraceGameActive
                    ? "结束“画心挑战”"
                    : "开始“画心挑战”"
            ) {
                viewModel.toggleHeartTraceGame()
            }
            .disabled(viewModel.petGameActive && !viewModel.heartTraceGameActive)
            Button(
                viewModel.rhythmGameActive
                    ? "结束“心跳节拍”"
                    : "开始“心跳节拍”"
            ) {
                viewModel.toggleRhythmGame()
            }
            .disabled(viewModel.petGameActive && !viewModel.rhythmGameActive)
            Button(
                viewModel.feedGameActive
                    ? "结束“投喂时刻”"
                    : "开始“投喂时刻”"
            ) {
                viewModel.toggleFeedGame()
            }
            .disabled(viewModel.petGameActive && !viewModel.feedGameActive)
            Divider()
            Button("退出澄音") { NSApp.terminate(nil) }
        }
    }

    @ViewBuilder
    private func companionMedia() -> some View {
        let presentationMode = viewModel.displayMode.presentationMode
        let baseProjection = CompanionPresentationProjection.resolve(
            mode: presentationMode,
            cropAnchors: [:],
            reducedDynamicEffectsEnabled: viewModel.reducedDynamicEffectsEnabled
        )
        Group {
            if !baseProjection.permitsVideo {
                if let action = viewModel.eventAction {
                    CompanionEventSpriteView(
                        action: action,
                        outfit: viewModel.outfit
                    )
                } else {
                    LiveSpriteView(isSpeaking: viewModel.isSpeaking)
                }
            } else if let sequence = viewModel.activeContentSequence {
                CompanionContentSequenceView(
                    viewModel: viewModel,
                    sequence: sequence,
                    presentationMode: presentationMode
                )
                .id(sequence.id)
                .transition(mediaTransition)
            } else if let miniScene = viewModel.activeMiniScene {
                CompanionMiniSceneVideoView(
                    viewModel: viewModel,
                    scene: miniScene,
                    presentationMode: presentationMode
                )
                .transition(mediaTransition)
            } else if let scene = viewModel.activeScene {
                CompanionSceneVideoView(
                    viewModel: viewModel,
                    scene: scene,
                    presentationMode: presentationMode
                )
                    .transition(mediaTransition)
            } else if let action = viewModel.eventAction {
                CompanionActionView(
                    viewModel: viewModel,
                    action: action,
                    outfit: viewModel.outfit,
                    eventKind: viewModel.activeEventKind,
                    presentationMode: presentationMode
                )
                .transition(mediaTransition)
            } else {
                CompanionIdleVideoView(
                    viewModel: viewModel,
                    isSpeaking: viewModel.isSpeaking,
                    presentationMode: presentationMode
                )
                .transition(.opacity)
            }
        }
        .accessibilityElement(children: .ignore)
        .companionMediaAccessibility(viewModel)
    }

    private var headView: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                PetResponsiveLayer(
                    viewModel: viewModel,
                    allowsWindowDrag: true
                ) {
                    if viewModel.keepsMediaInHead,
                       viewModel.isPresentingMedia {
                        companionMedia()
                    } else {
                        AnimatedHeadPetView(
                            viewModel: viewModel,
                            isSpeaking: viewModel.isSpeaking
                        )
                    }
                    }
                .clipShape(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .scaleEffect(
                    compactHover
                        && !reducesMotion
                        && !viewModel.reducedDynamicEffectsEnabled
                        ? 1.035
                        : 1
                )
                .animation(
                    reducesMotion || viewModel.reducedDynamicEffectsEnabled
                        ? nil
                        : .spring(response: 0.25, dampingFraction: 0.72),
                    value: compactHover
                )

                Circle()
                    .fill(presenceColor)
                    .frame(width: 8, height: 8)
                    .shadow(
                        color: presenceColor,
                        radius: 5
                    )
                    .padding(7)

                VStack {
                    Spacer()
                    HStack {
                        RelationshipStatusPill(
                            viewModel: viewModel,
                            showsChapter: false
                        )
                        Spacer()
                    }
                }
                .padding(6)
                .allowsHitTesting(false)
            }
            .frame(width: 104, height: 104)
            .shadow(color: .black.opacity(0.34), radius: 12, y: 8)
            .overlay(alignment: .bottomTrailing) {
                if viewModel.relationshipState.isSurpriseGuaranteed {
                    SurpriseCornerStar()
                        .padding(6)
                        .transition(
                            .scale(scale: 0.5).combined(with: .opacity)
                        )
                }
            }
            .overlay(alignment: .bottom) {
                if let lesson = viewModel.gestureCoachLesson {
                    GestureCoachBubble(lesson: lesson)
                        .padding(.bottom, 7)
                        .transition(
                            .move(edge: .bottom)
                                .combined(with: .scale(scale: 0.82))
                                .combined(with: .opacity)
                        )
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 6) {
                Button {
                    viewModel.setDisplayMode(.compact)
                } label: {
                    Image(systemName: "person.crop.rectangle")
                }
                .help("展开半身")

                Button {
                    viewModel.setDisplayMode(.full)
                } label: {
                    Image(systemName: "rectangle.inset.filled")
                }
                .help("打开互动舞台")

                PlaybackModeButton(viewModel: viewModel)
                ActionPlayMenu(viewModel: viewModel)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.white.opacity(0.94))
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .accessibilityElement(children: .contain)
        }
        .padding(4)
        .onHover { compactHover = $0 }
        .animation(
            .spring(response: 0.30, dampingFraction: 0.72),
            value: viewModel.gestureCoachLesson
        )
        .contextMenu {
            Button("展开半身") { viewModel.setDisplayMode(.compact) }
            Button("打开互动舞台") { viewModel.setDisplayMode(.full) }
            Button("预览随机动作") { viewModel.playRandomAction() }
            Button(
                viewModel.petInteractionsEnabled
                    ? "暂停头像点击互动"
                    : "开启头像点击互动"
            ) {
                viewModel.petInteractionsEnabled.toggle()
            }
            Button("预览任务完成动画") {
                viewModel.previewEvent(.taskComplete)
            }
            Button(
                viewModel.catchGameActive
                    ? "结束“抓住我”"
                    : "开始“20 秒抓住我”"
            ) {
                viewModel.toggleCatchGame()
            }
            .disabled(viewModel.petGameActive && !viewModel.catchGameActive)
            Button(
                viewModel.hideGameActive
                    ? "结束“躲猫猫”"
                    : "开始“边缘躲猫猫”"
            ) {
                viewModel.toggleHideGame()
            }
            .disabled(viewModel.petGameActive && !viewModel.hideGameActive)
            Button(
                viewModel.comboGameActive
                    ? "结束“动作连招”"
                    : "开始“动作连招”"
            ) {
                viewModel.toggleComboGame()
            }
            .disabled(viewModel.petGameActive && !viewModel.comboGameActive)
            Button(
                viewModel.heartTraceGameActive
                    ? "结束“画心挑战”"
                    : "开始“画心挑战”"
            ) {
                viewModel.toggleHeartTraceGame()
            }
            .disabled(viewModel.petGameActive && !viewModel.heartTraceGameActive)
            Button(
                viewModel.rhythmGameActive
                    ? "结束“心跳节拍”"
                    : "开始“心跳节拍”"
            ) {
                viewModel.toggleRhythmGame()
            }
            .disabled(viewModel.petGameActive && !viewModel.rhythmGameActive)
            Button(
                viewModel.feedGameActive
                    ? "结束“投喂时刻”"
                    : "开始“投喂时刻”"
            ) {
                viewModel.toggleFeedGame()
            }
            .disabled(viewModel.petGameActive && !viewModel.feedGameActive)
            Divider()
            Button("退出澄音") { NSApp.terminate(nil) }
        }
    }

    private func interactionHint(
        _ systemImage: String,
        _ text: String
    ) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.68))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct GestureCoachBubble: View {
    let lesson: CompanionGestureLesson
    @State private var pulses = false

    var body: some View {
        Label(lesson.title, systemImage: lesson.systemImage)
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(.black.opacity(0.70), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.pink.opacity(0.76), lineWidth: 1)
            )
            .shadow(color: .pink.opacity(0.55), radius: 9)
            .scaleEffect(pulses ? 1.035 : 0.97)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.72)
                        .repeatForever(autoreverses: true)
                ) {
                    pulses = true
                }
            }
            .accessibilityLabel(companionAccessibilityFormat(
                "gesture.hint.accessibility", "互动提示：%@", lesson.title
            ))
    }
}

private struct RelationshipStatusPill: View {
    @ObservedObject var viewModel: CompanionViewModel
    let showsChapter: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(
                systemName: viewModel.relationshipState.isSurpriseGuaranteed
                    ? "sparkles"
                    : "heart.fill"
            )
            .foregroundStyle(
                viewModel.relationshipState.isSurpriseGuaranteed
                    ? Color.yellow
                    : Color.pink
            )
            if showsChapter {
                Text(viewModel.relationshipChapterLabel)
            }
            Text("\(viewModel.relationshipState.bondMoments)")
                .monospacedDigit()
        }
        .font(
            .system(
                size: showsChapter ? 11.5 : 10,
                weight: .semibold,
                design: .rounded
            )
        )
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, showsChapter ? 9 : 6)
        .padding(.vertical, showsChapter ? 6 : 4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.pink.opacity(0.24), lineWidth: 1)
        )
        .fixedSize()
        .help(
            viewModel.relationshipState.isSurpriseGuaranteed
                ? "她准备了一个惊喜，试试双击"
                : "\(viewModel.relationshipChapterLabel) · \(viewModel.relationshipMomentsLabel)"
        )
        .accessibilityLabel(companionAccessibilityFormat(
            "accessibility.relationship.summary", "%@，%@",
            viewModel.relationshipChapterLabel, viewModel.relationshipMomentsLabel
        ))
    }
}

private struct WorkdayStatusPill: View {
    @ObservedObject var viewModel: CompanionViewModel
    let showsLabel: Bool
    @State private var showsDetails = false

    private var systemImage: String {
        switch viewModel.codexVisualState {
        case .working:
            "hourglass"
        case .completed, .awaitingReply:
            "checkmark.circle.fill"
        case .idle:
            viewModel.workdayState.completedCount > 0
                ? "checkmark.circle"
                : "circle.dotted"
        }
    }

    var body: some View {
        Button {
            showsDetails.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .symbolEffect(
                        .pulse,
                        options: .repeating,
                        isActive: viewModel.codexVisualState == .working
                    )
                if showsLabel {
                    Text(viewModel.workdayCompactLabel)
                } else {
                    Text("\(viewModel.workdayState.completedCount)")
                        .monospacedDigit()
                }
            }
            .font(
                .system(
                    size: showsLabel ? 11.5 : 10,
                    weight: .semibold,
                    design: .rounded
                )
            )
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, showsLabel ? 9 : 6)
            .padding(.vertical, showsLabel ? 6 : 4)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.cyan.opacity(0.24), lineWidth: 1)
            )
            .fixedSize()
        }
        .buttonStyle(.plain)
        .help(viewModel.workdaySummaryLabel)
        .accessibilityLabel(viewModel.workdaySummaryLabel)
        .popover(isPresented: $showsDetails, arrowEdge: .bottom) {
            WorkdayMemoryPopover(viewModel: viewModel)
        }
    }
}

private struct WorkdayMemoryPopover: View {
    @ObservedObject var viewModel: CompanionViewModel
    @State private var confirmsForget = false

    private var hasMemory: Bool {
        let state = viewModel.workdayState
        return state.startedCount > 0
            || state.responseReadyCount > 0
            || state.completedCount > 0
            || state.failedCount > 0
            || state.cancelledCount > 0
            || state.focusedDurationSeconds > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(CompanionCopy.workdayTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
                Text(viewModel.workdayState.dayIdentifier)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                metric(
                    CompanionCopy.workdayStarted,
                    value: viewModel.workdayState.startedCount
                )
                metric(
                    CompanionCopy.workdayCompleted,
                    value: viewModel.workdayState.completedCount
                )
                metric(
                    CompanionCopy.workdayResponses,
                    value: viewModel.workdayState.responseReadyCount
                )
                metric(
                    CompanionCopy.workdayChallenges,
                    value: viewModel.workdayState.failedCount
                )
                metric(
                    CompanionCopy.workdayRecoveries,
                    value: viewModel.workdayState.recoveredCompletionCount
                )
                metric(
                    CompanionCopy.workdayFocusMinutes,
                    value: viewModel.workdayState.focusedDurationSeconds / 60
                )
            }

            Label(CompanionCopy.workdayPrivacyNote, systemImage: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(role: .destructive) {
                confirmsForget = true
            } label: {
                Label(CompanionCopy.workdayForget, systemImage: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(!hasMemory)
        }
        .padding(18)
        .frame(width: 340)
        .confirmationDialog(
            CompanionCopy.workdayForgetConfirmation,
            isPresented: $confirmsForget,
            titleVisibility: .visible
        ) {
            Button(CompanionCopy.workdayForgetConfirmButton, role: .destructive) {
                viewModel.forgetTodayWorkday()
            }
            Button(CompanionCopy.cancel, role: .cancel) {}
        } message: {
            Text(CompanionCopy.workdayForgetExplanation)
        }
    }

    private func metric(_ label: String, value: UInt64) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PetResponsiveLayer<Content: View>: View {
    @ObservedObject var viewModel: CompanionViewModel
    let allowsWindowDrag: Bool
    private let content: Content

    init(
        viewModel: CompanionViewModel,
        allowsWindowDrag: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.viewModel = viewModel
        self.allowsWindowDrag = allowsWindowDrag
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
                .scaleEffect(viewModel.petPose.scale)
                .rotationEffect(.degrees(viewModel.petPose.rotation))
                .offset(
                    x: viewModel.petPose.x,
                    y: -viewModel.petPose.y
                )
                .animation(
                    .spring(response: 0.28, dampingFraction: 0.67),
                    value: viewModel.petPose
                )

            CodexPresenceHalo(state: viewModel.codexVisualState)
                .id(viewModel.codexVisualState)

            if viewModel.heartTraceGameActive {
                HeartTraceGuide(
                    points: viewModel.heartTraceGuidePoints,
                    progress: viewModel.heartTraceProgress
                )
                .transition(.opacity)
            }

            if viewModel.rhythmGameActive {
                RhythmPulseGuide(
                    pulse: viewModel.rhythmBeatPulse,
                    isReady: viewModel.rhythmBeatReady
                )
                .transition(.opacity)
            }

            if let effect = viewModel.petEffect,
               !viewModel.petGameActive,
               !viewModel.isPresentingMedia {
                Label(effect.text, systemImage: effect.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(color: .pink.opacity(0.42), radius: 10, y: 4)
                    .padding(10)
                    .transition(
                        .scale(scale: 0.72).combined(with: .opacity)
                    )
                    .id(effect.id)
                    .allowsHitTesting(false)
            }

            PetInteractionSurface(
                allowsWindowDrag: allowsWindowDrag
                    && !viewModel.petGameActive,
                delaysSingleClick: !viewModel.rhythmGameActive,
                onSingleClick: { viewModel.handlePetSingleClick() },
                onDoubleClick: { viewModel.handlePetDoubleClick() },
                onHover: { isInside, point in
                    viewModel.handlePetHover(
                        isInside: isInside,
                        normalizedPoint: point
                    )
                },
                onPointerMove: { viewModel.handlePetPointerMove($0) },
                onPressChanged: { viewModel.handlePetPressChanged($0) },
                onLongPressBegan: { viewModel.handlePetLongPressBegan() },
                onLongPressEnded: { viewModel.handlePetLongPressEnded() },
                onDragChanged: { translation, movingWindow, pointer in
                    viewModel.handlePetDragChanged(
                        translation: translation,
                        movingWindow: movingWindow,
                        normalizedPoint: pointer
                    )
                },
                onDragEnded: { translation, velocity, dockEdge in
                    viewModel.handlePetDragEnded(
                        translation: translation,
                        velocity: velocity,
                        dockEdge: dockEdge
                    )
                }
            )
            .allowsHitTesting(!viewModel.feedGameActive)
            .accessibilityLabel(companionAccessibilityText(
                "accessibility.pet.label", "澄音互动角色"
            ))
            .accessibilityHint(companionAccessibilityText(
                "accessibility.pet.hint", "单击、双击、长按或拖动来互动"
            ))
            .accessibilityIdentifier("chengyin.pet-interaction")

            if viewModel.feedGameActive {
                FeedGameGuide(
                    treat: viewModel.feedGameTreat,
                    round: viewModel.feedGameRound,
                    score: viewModel.feedGameScore,
                    onDrop: viewModel.registerFeedDrop
                )
                .id(viewModel.feedGameRound)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            if viewModel.petGameActive {
                Text(viewModel.activePetGameHUDText)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(.black.opacity(0.68), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.pink.opacity(0.55), lineWidth: 1)
                )
                .padding(8)
                .allowsHitTesting(false)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else if viewModel.codexVisualState != .idle {
                CodexPresenceGlyph(state: viewModel.codexVisualState)
                    .padding(9)
                    .transition(
                        .scale(scale: 0.65).combined(with: .opacity)
                    )
            }
        }
        .overlay(alignment: .top) {
            if let receipt = viewModel.relationshipReceipt {
                RelationshipReceiptToast(
                    receipt: receipt,
                    compact: viewModel.displayMode == .head
                )
                .padding(.top, viewModel.displayMode == .head ? 7 : 11)
                .transition(
                    .move(edge: .top)
                        .combined(with: .scale(scale: 0.82))
                        .combined(with: .opacity)
                )
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.completionReplyWindowActive {
                CompletionReplyCue()
                    .padding(12)
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.65).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: viewModel.petEffect)
        .animation(.spring(response: 0.3, dampingFraction: 0.74), value: viewModel.petGameActive)
        .animation(
            .spring(response: 0.32, dampingFraction: 0.72),
            value: viewModel.codexVisualState
        )
        .animation(
            .spring(response: 0.34, dampingFraction: 0.70),
            value: viewModel.relationshipReceipt
        )
        .animation(
            .spring(response: 0.3, dampingFraction: 0.74),
            value: viewModel.completionReplyWindowActive
        )
    }
}

private struct FeedGameGuide: View {
    let treat: CompanionTreat
    let round: Int
    let score: Int
    let onDrop: (Bool) -> Void

    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var targetIsHot = false

    var body: some View {
        GeometryReader { proxy in
            let target = CGPoint(
                x: proxy.size.width * 0.5,
                y: proxy.size.height * 0.43
            )
            let start = CGPoint(
                x: round.isMultiple(of: 2)
                    ? proxy.size.width - 58
                    : 58,
                y: proxy.size.height - 48
            )

            ZStack {
                Path { path in
                    path.move(to: start)
                    path.addQuadCurve(
                        to: target,
                        control: CGPoint(
                            x: proxy.size.width * (round.isMultiple(of: 2) ? 0.68 : 0.32),
                            y: proxy.size.height * 0.64
                        )
                    )
                }
                .stroke(
                    Color.white.opacity(0.24),
                    style: StrokeStyle(lineWidth: 2, dash: [5, 7])
                )

                ZStack {
                    Circle()
                        .fill(
                            targetIsHot
                                ? Color.pink.opacity(0.30)
                                : Color.black.opacity(0.28)
                        )
                    Circle()
                        .stroke(
                            targetIsHot ? Color.pink : Color.white.opacity(0.50),
                            style: StrokeStyle(
                                lineWidth: targetIsHot ? 4 : 2,
                                dash: targetIsHot ? [] : [6, 6]
                            )
                        )
                    VStack(spacing: 3) {
                        Image(systemName: targetIsHot ? "heart.fill" : "hand.raised.fill")
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(
                                targetIsHot ? Color.pink : Color.white.opacity(0.88)
                            )
                            .symbolEffect(.bounce, value: targetIsHot)
                        Text(targetIsHot ? "松手给我" : "递到这里")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                }
                .frame(
                    width: targetIsHot ? 104 : 90,
                    height: targetIsHot ? 104 : 90
                )
                .position(target)
                .shadow(
                    color: targetIsHot ? .pink.opacity(0.60) : .clear,
                    radius: 18
                )
                .animation(
                    .spring(response: 0.24, dampingFraction: 0.68),
                    value: targetIsHot
                )
                .allowsHitTesting(false)

                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.28),
                                    Color.pink.opacity(0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(treat.emoji)
                        .font(.system(size: 33))
                        .scaleEffect(isDragging ? 1.14 : 1)
                }
                .frame(width: 62, height: 62)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.62), lineWidth: 1.5)
                )
                .shadow(
                    color: targetIsHot ? .pink.opacity(0.72) : .black.opacity(0.48),
                    radius: isDragging ? 16 : 9,
                    y: isDragging ? 9 : 5
                )
                .position(start)
                .offset(dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .local)
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation
                            let current = CGPoint(
                                x: start.x + value.translation.width,
                                y: start.y + value.translation.height
                            )
                            targetIsHot = hypot(
                                current.x - target.x,
                                current.y - target.y
                            ) <= 68
                        }
                        .onEnded { value in
                            let current = CGPoint(
                                x: start.x + value.translation.width,
                                y: start.y + value.translation.height
                            )
                            let succeeded = hypot(
                                current.x - target.x,
                                current.y - target.y
                            ) <= 68
                            isDragging = false
                            targetIsHot = false
                            if succeeded {
                                onDrop(true)
                            } else {
                                withAnimation(
                                    .spring(response: 0.34, dampingFraction: 0.62)
                                ) {
                                    dragOffset = .zero
                                }
                                onDrop(false)
                            }
                        }
                )
                .help("把\(treat.label)拖到中间发光区域")

                Text(score == 0 ? "拖动点心" : "再喂我一口")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.52), in: Capsule())
                    .position(x: start.x, y: start.y - 45)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct RhythmPulseGuide: View {
    let pulse: Int
    let isReady: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.pink.opacity(0.32), lineWidth: 2)
                .padding(8)

            if isReady {
                RhythmPulseRing()
                    .id(pulse)
            }

            Image(systemName: isReady ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isReady ? Color.pink : Color.white.opacity(0.58))
                .symbolEffect(.bounce, value: pulse)
        }
        .padding(5)
        .allowsHitTesting(false)
    }
}

private struct RhythmPulseRing: View {
    @State private var expanded = false

    var body: some View {
        Circle()
            .stroke(Color.pink, lineWidth: expanded ? 2 : 6)
            .scaleEffect(expanded ? 1.24 : 0.55)
            .opacity(expanded ? 0.12 : 0.95)
            .onAppear {
                withAnimation(.easeOut(duration: 0.48)) {
                    expanded = true
                }
            }
    }
}

private struct HeartTraceGuide: View {
    let points: [CGPoint]
    let progress: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: canvasPoint(first, in: proxy.size))
                    for point in points.dropFirst() {
                        path.addLine(to: canvasPoint(point, in: proxy.size))
                    }
                }
                .stroke(
                    Color.pink.opacity(0.42),
                    style: StrokeStyle(
                        lineWidth: 3,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: [7, 8]
                    )
                )

                ForEach(points.indices, id: \.self) { index in
                    let isPassed = index < progress
                    let isNext = index == progress
                    Circle()
                        .fill(
                            isPassed
                                ? Color.pink
                                : (isNext ? Color.white : Color.pink.opacity(0.28))
                        )
                        .frame(
                            width: isNext ? 18 : 11,
                            height: isNext ? 18 : 11
                        )
                        .overlay {
                            if isNext {
                                Circle()
                                    .stroke(Color.pink, lineWidth: 3)
                                    .scaleEffect(1.5)
                            }
                        }
                        .position(canvasPoint(points[index], in: proxy.size))
                }
            }
        }
        .allowsHitTesting(false)
        .animation(
            .spring(response: 0.28, dampingFraction: 0.72),
            value: progress
        )
    }

    private func canvasPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: (point.x + 1) * 0.5 * size.width,
            y: (1 - point.y) * 0.5 * size.height
        )
    }
}


private struct DisplayModeButtons: View {
    @ObservedObject var viewModel: CompanionViewModel

    var body: some View {
        HStack(spacing: 9) {
            modeButton(.head, systemImage: "person.crop.circle")
            modeButton(.compact, systemImage: "person.crop.rectangle")
            modeButton(.full, systemImage: "rectangle.inset.filled")
        }
    }

    private func modeButton(
        _ mode: CompanionDisplayMode,
        systemImage: String
    ) -> some View {
        Button {
            viewModel.setDisplayMode(mode)
        } label: {
            Image(systemName: systemImage)
                .foregroundStyle(
                    viewModel.displayMode == mode
                        ? Color.white
                        : Color.white.opacity(0.48)
                )
        }
        .buttonStyle(.plain)
        .help(mode.label)
    }
}
