import CompanionContracts
import SwiftUI

private func firstSessionText(_ key: String, _ fallback: String) -> String {
    CompanionLocalization.string(key: key, fallback: fallback)
}

struct CompanionFirstSessionCoachLayer: View {
    @ObservedObject var viewModel: CompanionViewModel

    var body: some View {
        if viewModel.firstSessionPresented {
            CompanionFirstSessionCoach(viewModel: viewModel)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .bottomLeading
                )
                .padding(10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(4)
                .animation(.easeInOut(duration: 0.22), value: viewModel.firstSessionStep)
        }
    }
}

extension CompanionFirstSessionPreference {
    var firstSessionLabel: String {
        switch self {
        case .workCompanion:
            firstSessionText("firstSession.preference.work", "陪我工作")
        case .playfulBreaks:
            firstSessionText("firstSession.preference.play", "偶尔逗玩")
        case .gentleCare:
            firstSessionText("firstSession.preference.care", "温柔提醒")
        }
    }

    var firstSessionIcon: String {
        switch self {
        case .workCompanion: "laptopcomputer"
        case .playfulBreaks: "sparkles"
        case .gentleCare: "cup.and.saucer.fill"
        }
    }

    var firstSessionAccessibilityIdentifier: String {
        switch self {
        case .workCompanion:
            "chengyin.first-session-preference-workCompanion"
        case .playfulBreaks:
            "chengyin.first-session-preference-playfulBreaks"
        case .gentleCare:
            "chengyin.first-session-preference-gentleCare"
        }
    }
}

struct CompanionFirstSessionCoach: View {
    @ObservedObject var viewModel: CompanionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: stepIcon)
                    .foregroundStyle(.cyan)
                Text(stepTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer(minLength: 8)
                Button {
                    viewModel.skipFirstSession()
                } label: {
                    Text(firstSessionText("firstSession.skip", "跳过"))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.66))
                .accessibilityIdentifier("chengyin.first-session-skip")
            }

            Text(stepDetail)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.firstSessionStep == .preference {
                HStack(spacing: 7) {
                    ForEach(CompanionFirstSessionPreference.allCases, id: \.rawValue) { preference in
                        Button {
                            viewModel.chooseFirstSessionPreference(preference)
                        } label: {
                            Label(
                                preference.firstSessionLabel,
                                systemImage: preference.firstSessionIcon
                            )
                            .font(.system(size: 11.5, weight: .semibold))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan.opacity(0.82))
                        .accessibilityIdentifier(
                            preference.firstSessionAccessibilityIdentifier
                        )
                    }
                }
            }
        }
        .padding(13)
        .frame(maxWidth: 510, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(stepTitle)
        .accessibilityValue(stepDetail)
        .accessibilityIdentifier("chengyin.first-session-coach")
    }

    private var stepIcon: String {
        switch viewModel.firstSessionStep {
        case .singleTap: "cursorarrow.click"
        case .doubleTap: "cursorarrow.click.2"
        case .preference: "slider.horizontal.3"
        case .workArc: "point.3.connected.trianglepath.dotted"
        case .dormant, .complete: "checkmark.circle.fill"
        }
    }

    private var stepTitle: String {
        switch viewModel.firstSessionStep {
        case .singleTap:
            firstSessionText("firstSession.singleTap.title", "先轻点澄音一下")
        case .doubleTap:
            firstSessionText("firstSession.doubleTap.title", "很好，再双击一次")
        case .preference:
            firstSessionText("firstSession.preference.title", "你更想要哪种陪伴？")
        case .workArc:
            firstSessionText("firstSession.workArc.title", "第一次共同工作正在演示")
        case .dormant, .complete:
            firstSessionText("firstSession.complete.title", "已经准备好了")
        }
    }

    private var stepDetail: String {
        switch viewModel.firstSessionStep {
        case .singleTap:
            firstSessionText(
                "firstSession.singleTap.detail",
                "点击人物，立即看看她的动作与声音反馈。"
            )
        case .doubleTap:
            firstSessionText(
                "firstSession.doubleTap.detail",
                "双击会挑选另一段互动；所有玩法之后仍永久免费可用。"
            )
        case .preference:
            firstSessionText(
                "firstSession.preference.detail",
                "只选这一项，用来调整本机提醒节奏；以后可在设置中更改。"
            )
        case .workArc:
            firstSessionText(
                "firstSession.workArc.detail",
                "澄音会从安静陪伴走到可信任务完成庆祝，不会把中间节点误报成完成。"
            )
        case .dormant, .complete:
            firstSessionText(
                "firstSession.complete.detail",
                "没有账户、时长限制或付费墙。"
            )
        }
    }
}
