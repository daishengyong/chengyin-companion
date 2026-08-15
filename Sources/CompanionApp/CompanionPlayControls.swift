import AppKit
import CompanionContracts
import SwiftUI

private func playControlText(_ key: String, _ fallback: String) -> String {
    CompanionLocalization.string(key: key, fallback: fallback)
}

struct PlaybackModeButton: View {
    @ObservedObject var viewModel: CompanionViewModel
    var showsTitle = false

    var body: some View {
        Menu {
            Button {
                viewModel.setPlaybackMode(.audioVisual)
            } label: {
                Label(
                    CompanionPlaybackMode.audioVisual.label,
                    systemImage: viewModel.playbackMode == .audioVisual
                        ? "checkmark.circle.fill"
                        : "play.rectangle.fill"
                )
            }
            Button {
                viewModel.setPlaybackMode(.audioOnly)
            } label: {
                Label(
                    CompanionPlaybackMode.audioOnly.label,
                    systemImage: viewModel.playbackMode == .audioOnly
                        ? "checkmark.circle.fill"
                        : "speaker.wave.2.fill"
                )
            }
        } label: {
            if showsTitle {
                Label(
                    viewModel.playbackMode.label,
                    systemImage: viewModel.playbackMode.systemImage
                )
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
            } else {
                Image(systemName: viewModel.playbackMode.systemImage)
                    .foregroundStyle(
                        viewModel.playbackMode == .audioVisual
                            ? Color.cyan.opacity(0.94)
                            : Color.white.opacity(0.88)
                    )
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(
            playControlText(
                "accessibility.playback.help",
                "点击选择音画模式"
            )
        )
        .accessibilityLabel(
            playControlText(
                "accessibility.playback.label",
                "播放模式"
            )
        )
        .accessibilityValue(viewModel.playbackMode.label)
        .accessibilityIdentifier("chengyin.playback-mode")
    }
}

private enum CompanionPlayPaletteCategory: String, CaseIterable {
    case games
    case miniScenes
    case fantasy
    case actions

    var label: String {
        switch self {
        case .games:
            playControlText("play.category.games", "小游戏")
        case .miniScenes:
            playControlText("play.category.miniScenes", "迷你生活")
        case .fantasy:
            playControlText("play.category.fantasy", "幻想场景")
        case .actions:
            playControlText("play.category.actions", "互动动作")
        }
    }

    var systemImage: String {
        switch self {
        case .games: "gamecontroller.fill"
        case .miniScenes: "house.and.flag.fill"
        case .fantasy: "sparkles.rectangle.stack.fill"
        case .actions: "figure.dance"
        }
    }
}

struct ActionPlayMenu: View {
    @ObservedObject var viewModel: CompanionViewModel
    var showsTitle = false

    var body: some View {
        Button {
            if !viewModel.playPalettePresented {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first { $0.title == "澄音" }?
                    .makeKeyAndOrderFront(nil)
            }
            viewModel.playPalettePresented.toggle()
            if !viewModel.playPalettePresented {
                NSApp.deactivate()
            }
        } label: {
            if showsTitle {
                Label(
                    playControlText("play.palette.title", "逗她玩"),
                    systemImage: "wand.and.stars"
                )
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
            } else {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(.white.opacity(0.88))
            }
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help(
            playControlText(
                "accessibility.playPalette.help",
                "向上打开逗玩面板"
            )
        )
        .accessibilityLabel(
            playControlText(
                "accessibility.playPalette.label",
                "逗她玩"
            )
        )
        .accessibilityValue(
            viewModel.playPalettePresented
                ? playControlText("accessibility.state.expanded", "已展开")
                : playControlText("accessibility.state.collapsed", "已收起")
        )
        .accessibilityHint(
            playControlText(
                "accessibility.playPalette.hint",
                "打开后可选择小游戏、生活场景和互动动作"
            )
        )
        .accessibilityIdentifier("chengyin.play-palette-toggle")
    }
}

struct CompanionPlayPaletteOverlay: View {
    @ObservedObject var viewModel: CompanionViewModel
    let layout: CompanionPlayPaletteLayoutPlan
    @State private var category = CompanionPlayPaletteCategory.games

    var body: some View {
        CompanionPlayPalette(
            viewModel: viewModel,
            category: $category,
            layout: layout,
            dismiss: {
                viewModel.playPalettePresented = false
                NSApp.deactivate()
            }
        )
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.44), radius: 24, y: 14)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            playControlText(
                "accessibility.playPalette.panel",
                "逗玩面板"
            )
        )
        .accessibilityIdentifier("chengyin.play-palette")
    }
}

private struct CompanionPlayPalette: View {
    @ObservedObject var viewModel: CompanionViewModel
    @Binding var category: CompanionPlayPaletteCategory
    let layout: CompanionPlayPaletteLayoutPlan
    let dismiss: () -> Void

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(minimum: layout.minimumButtonWidth),
                spacing: 8
            ),
            count: layout.columnCount
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.isCompact ? 8 : 12) {
            HStack(spacing: 10) {
                Label(
                    playControlText("play.palette.title", "逗她玩"),
                    systemImage: "wand.and.stars"
                )
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                if layout.showsReturnHint {
                    Text(
                        playControlText(
                            "play.palette.returnHint",
                            "选择后自动展开，播放完回到原来的大小"
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if viewModel.playbackMode == .audioOnly {
                    Button {
                        viewModel.setPlaybackMode(.audioVisual)
                    } label: {
                        Label(
                            playControlText(
                                "play.palette.restoreVideo.short",
                                "恢复画面"
                            ),
                            systemImage: "play.rectangle.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.cyan)
                    .fixedSize()
                    .help(
                        playControlText(
                            "play.palette.restoreVideo",
                            "当前是仅声音模式，点这里恢复动作画面"
                        )
                    )
                    .accessibilityLabel(
                        playControlText(
                            "play.palette.restoreVideo",
                            "当前是仅声音模式，点这里恢复动作画面"
                        )
                    )
                    .accessibilityIdentifier(
                        "chengyin.play-palette-restore-video"
                    )
                }
                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(
                    playControlText(
                        "play.palette.close",
                        "收起逗玩面板"
                    )
                )
                .accessibilityLabel(
                    playControlText(
                        "play.palette.close",
                        "收起逗玩面板"
                    )
                )
                .accessibilityIdentifier("chengyin.play-palette-close")
            }

            Picker(
                playControlText("play.palette.category", "玩法类别"),
                selection: $category
            ) {
                ForEach(CompanionPlayPaletteCategory.allCases, id: \.rawValue) { item in
                    categoryPickerLabel(item)
                        .tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel(
                playControlText("play.palette.category", "玩法类别")
            )
            .accessibilityIdentifier("chengyin.play-palette-category")

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                categoryButtons
            }
            .frame(minHeight: 86, alignment: .top)

            Divider()

            HStack(spacing: 8) {
                paletteButton(
                    title: playControlText(
                        "play.preview.taskComplete",
                        "庆祝任务完成"
                    ),
                    systemImage: "party.popper.fill",
                    iconOnly: layout.usesCompactFooter
                ) {
                    viewModel.previewEvent(.taskComplete)
                }
                paletteButton(
                    title: playControlText(
                        "play.preview.firstSession",
                        "快速上手与工作弧"
                    ),
                    systemImage: "figure.wave.circle.fill",
                    iconOnly: layout.usesCompactFooter
                ) {
                    viewModel.replayFirstSession()
                }
            }
        }
        .padding(layout.isCompact ? 10 : 16)
        .frame(
            maxWidth: layout.maximumPaletteWidth,
            maxHeight: layout.contentSize.height - 20,
            alignment: .top
        )
    }

    @ViewBuilder
    private func categoryPickerLabel(
        _ item: CompanionPlayPaletteCategory
    ) -> some View {
        if layout.isCompact {
            Image(systemName: item.systemImage)
                .accessibilityLabel(item.label)
        } else {
            Label(item.label, systemImage: item.systemImage)
        }
    }

    @ViewBuilder
    private var categoryButtons: some View {
        switch category {
        case .games:
            gameButton(
                title: viewModel.catchGameActive
                    ? playControlText("game.catch.stop", "结束抓住我")
                    : playControlText("game.catch.start", "20 秒抓住我"),
                systemImage: viewModel.catchGameActive
                    ? "stop.circle.fill"
                    : "hand.tap.fill",
                isActive: viewModel.catchGameActive
            ) { viewModel.toggleCatchGame() }
            gameButton(
                title: viewModel.hideGameActive
                    ? playControlText("game.hide.stop", "结束躲猫猫")
                    : playControlText("game.hide.start", "边缘躲猫猫"),
                systemImage: viewModel.hideGameActive
                    ? "stop.circle.fill"
                    : "eye.fill",
                isActive: viewModel.hideGameActive
            ) { viewModel.toggleHideGame() }
            gameButton(
                title: viewModel.comboGameActive
                    ? playControlText("game.combo.stop", "结束动作连招")
                    : playControlText("game.combo.start", "动作连招"),
                systemImage: viewModel.comboGameActive
                    ? "stop.circle.fill"
                    : "hand.point.up.braille.fill",
                isActive: viewModel.comboGameActive
            ) { viewModel.toggleComboGame() }
            gameButton(
                title: viewModel.heartTraceGameActive
                    ? playControlText("game.heartTrace.stop", "结束画心挑战")
                    : playControlText("game.heartTrace.start", "画心挑战"),
                systemImage: viewModel.heartTraceGameActive
                    ? "stop.circle.fill"
                    : "heart.circle.fill",
                isActive: viewModel.heartTraceGameActive
            ) { viewModel.toggleHeartTraceGame() }
            gameButton(
                title: viewModel.rhythmGameActive
                    ? playControlText("game.rhythm.stop", "结束心跳节拍")
                    : playControlText("game.rhythm.start", "心跳节拍"),
                systemImage: viewModel.rhythmGameActive
                    ? "stop.circle.fill"
                    : "waveform.path.ecg",
                isActive: viewModel.rhythmGameActive
            ) { viewModel.toggleRhythmGame() }
            gameButton(
                title: viewModel.feedGameActive
                    ? playControlText("game.feed.stop", "结束投喂时刻")
                    : playControlText("game.feed.start", "投喂时刻"),
                systemImage: viewModel.feedGameActive
                    ? "stop.circle.fill"
                    : "takeoutbag.and.cup.and.straw.fill",
                isActive: viewModel.feedGameActive
            ) { viewModel.toggleFeedGame() }

        case .miniScenes:
            ForEach(CompanionMiniScene.allCases, id: \.rawValue) { scene in
                paletteButton(title: scene.label, systemImage: scene.systemImage) {
                    viewModel.playMiniScene(scene)
                }
            }

        case .fantasy:
            ForEach(CompanionScene.allCases, id: \.rawValue) { scene in
                paletteButton(title: scene.label, systemImage: scene.systemImage) {
                    viewModel.playScene(scene)
                }
            }

        case .actions:
            ForEach(CompanionAction.allCases, id: \.rawValue) { action in
                paletteButton(title: action.label, systemImage: action.systemImage) {
                    viewModel.playAction(action)
                }
            }
        }
    }

    private func gameButton(
        title: String,
        systemImage: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        paletteButton(title: title, systemImage: systemImage, action: action)
            .disabled(viewModel.petGameActive && !isActive)
    }

    private func paletteButton(
        title: String,
        systemImage: String,
        iconOnly: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            viewModel.noteUserInitiatedExperience()
            action()
            // Start the requested presentation before collapsing the head-mode
            // palette. This avoids a transient pet-size window configure racing
            // the audiovisual stage transition on a rapid selection.
            dismiss()
        } label: {
            if iconOnly {
                Image(systemName: systemImage)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .accessibilityLabel(title)
            } else {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 3)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}
