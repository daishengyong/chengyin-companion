import CompanionContracts
import SwiftUI

struct CompanionWindowSettingsSection: View {
    @ObservedObject var viewModel: CompanionViewModel
    @ObservedObject var displayCatalog: CompanionDisplayCatalog

    var body: some View {
        Section("互动与窗口") {
            Picker("显示方式", selection: $viewModel.displayMode) {
                Text("头像").tag(CompanionDisplayMode.head)
                Text("半身").tag(CompanionDisplayMode.compact)
                Text("舞台").tag(CompanionDisplayMode.full)
            }
            .pickerStyle(.segmented)
            Picker("舞台背景", selection: $viewModel.presentationAppearance) {
                ForEach(
                    CompanionPresentationAppearance.allCases,
                    id: \.rawValue
                ) { appearance in
                    Text(appearance.label).tag(appearance)
                }
            }
            .pickerStyle(.segmented)
            Text(viewModel.presentationAppearance.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("显示器", selection: $viewModel.displayTarget) {
                Text("跟随窗口所在屏幕")
                    .tag(CompanionDisplayTarget.followWindow)
                Text("始终使用主显示器")
                    .tag(CompanionDisplayTarget.main)
                ForEach(displayCatalog.options) { option in
                    Text(option.isMain ? "\(option.label) · 主显示器" : option.label)
                        .tag(CompanionDisplayTarget.specific(option.id))
                }
                if viewModel.displayTarget.mode == .specific,
                   displayCatalog.label(for: viewModel.displayTarget) == nil {
                    Text("已断开的显示器 · 自动回退")
                        .tag(viewModel.displayTarget)
                }
            }
            Text(displayTargetStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("只在本机保存技术显示器标识，不保存显示器名称；恢复到其他电脑时会安全回到当前或主显示器。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("鼠标互动", isOn: $viewModel.petInteractionsEnabled)
            LabeledContent("互动学习", value: viewModel.gestureDiscoveryProgressLabel)
            Button("重新显示互动提示") {
                viewModel.resetGestureDiscoveryTips()
            }
            Text("头像提示只记录四种手势是否学会，不保存鼠标位置、时间或互动历史；便携备份会保留这个进度。")
                .font(.caption)
                .foregroundStyle(.secondary)
            LabeledContent("当前状态", value: viewModel.petMood.label)
            gameButton(
                active: viewModel.catchGameActive,
                activeTitle: "结束“20 秒抓住我”",
                idleTitle: "开始“20 秒抓住我”",
                action: viewModel.toggleCatchGame
            )
            gameButton(
                active: viewModel.hideGameActive,
                activeTitle: "结束“边缘躲猫猫”",
                idleTitle: "开始“边缘躲猫猫”",
                action: viewModel.toggleHideGame
            )
            gameButton(
                active: viewModel.comboGameActive,
                activeTitle: "结束“动作连招”",
                idleTitle: "开始“动作连招”",
                action: viewModel.toggleComboGame
            )
            gameButton(
                active: viewModel.heartTraceGameActive,
                activeTitle: "结束“画心挑战”",
                idleTitle: "开始“画心挑战”",
                action: viewModel.toggleHeartTraceGame
            )
            gameButton(
                active: viewModel.rhythmGameActive,
                activeTitle: "结束“心跳节拍”",
                idleTitle: "开始“心跳节拍”",
                action: viewModel.toggleRhythmGame
            )
            gameButton(
                active: viewModel.feedGameActive,
                activeTitle: "结束“投喂时刻”",
                idleTitle: "开始“投喂时刻”",
                action: viewModel.toggleFeedGame
            )
            LabeledContent("抓住我最高记录", value: "\(viewModel.catchGameBestScore)/5")
            LabeledContent("躲猫猫最高记录", value: "\(viewModel.hideGameBestScore)/5")
            Text("支持鼠标跟随、单击、双击、长按抚摸、带声音的拖拽与甩动、动作连招、画心、心跳节拍，以及拖动物品投喂。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("随机切换三套造型", isOn: $viewModel.randomOutfitsEnabled)
            LabeledContent("当前造型", value: viewModel.outfit.label)
            Toggle(
                "登录时自动启动",
                isOn: Binding(
                    get: { viewModel.launchAtLoginEnabled },
                    set: { viewModel.setLaunchAtLogin($0) }
                )
            )
            if let message = viewModel.launchAtLoginMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func gameButton(
        active: Bool,
        activeTitle: LocalizedStringKey,
        idleTitle: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(active ? activeTitle : idleTitle, action: action)
            .disabled(viewModel.petGameActive && !active)
    }

    private var displayTargetStatus: String {
        switch displayCatalog.resolution(for: viewModel.displayTarget) {
        case .followedCurrent:
            return CompanionLocalization.string(
                key: "display.target.status.following",
                fallback: "窗口会留在当前屏幕，切换形态时不会跳回主屏。"
            )
        case .selectedMain:
            return CompanionLocalization.string(
                key: "display.target.status.main",
                fallback: "头像、半身和全屏舞台都会在主显示器显示。"
            )
        case .selectedSpecific:
            return CompanionLocalization.string(
                key: "display.target.status.specific",
                fallback: "三种展示形态都会迁移到所选显示器。"
            )
        case .recoveredToCurrent, .recoveredToMain, .recoveredToFirst, .usedFallback:
            return CompanionLocalization.string(
                key: "display.target.status.recovered",
                fallback: "所选显示器当前不可用，已安全回退，不会把窗口留在屏幕外。"
            )
        }
    }
}
