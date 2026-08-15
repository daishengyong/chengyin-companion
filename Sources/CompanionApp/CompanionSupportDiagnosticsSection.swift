import CompanionContracts
import SwiftUI

struct CompanionRuntimeHealthSettingsSection: View {
    @ObservedObject var viewModel: CompanionViewModel

    var body: some View {
        Section("本机健康") {
            LabeledContent("总体状态", value: viewModel.runtimeReadinessSummary)
            ForEach(viewModel.runtimeReadinessChecks, id: \.component) { check in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: symbol(for: check.level))
                        .foregroundStyle(color(for: check.level))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.runtimeReadinessTitle(for: check.component))
                            .font(.body.weight(.medium))
                        Text(viewModel.runtimeReadinessDetail(for: check))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            if viewModel.runtimeSafeRepairAvailable {
                Button {
                    viewModel.repairRuntimeReadiness()
                } label: {
                    Label(
                        "安全修复可恢复项目",
                        systemImage: "wrench.and.screwdriver.fill"
                    )
                }
                .disabled(viewModel.runtimeRepairInProgress)
            }
            Button("重新检查本机状态") {
                viewModel.refreshRuntimeReadiness()
            }
            .disabled(viewModel.runtimeRepairInProgress)

            if viewModel.runtimeRepairInProgress {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(
                        CompanionLocalization.string(
                            key: "accessibility.runtimeRepair.progress",
                            fallback: "正在执行本机安全修复"
                        )
                    )
                    .accessibilityIdentifier(
                        "chengyin.runtime-repair-progress"
                    )
            }
            if let message = viewModel.runtimeRepairMessage {
                Text(message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Text("只修复事件桥权限和中断内容包事务；不会替换应用、删除素材、改变偏好或联网。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func symbol(for level: CompanionRuntimeReadinessLevel) -> String {
        switch level {
        case .attention: "exclamationmark.triangle.fill"
        case .paused: "pause.circle.fill"
        case .ready: "checkmark.circle.fill"
        }
    }

    private func color(for level: CompanionRuntimeReadinessLevel) -> Color {
        switch level {
        case .attention: .orange
        case .paused: .secondary
        case .ready: .green
        }
    }
}

struct CompanionSupportDiagnosticsSettingsSection: View {
    @ObservedObject var viewModel: CompanionViewModel

    private var playbackHealth: CompanionPlaybackHealthSnapshot {
        CompanionPlaybackHealthMonitor.shared.snapshot
    }

    var body: some View {
        Section("支持与诊断") {
            LabeledContent("播放健康", value: firstFrameSummary)
            LabeledContent("播放尝试", value: attemptSummary)
            Button {
                viewModel.copyPrivacyMinimalDiagnosticReport()
            } label: {
                Label("复制隐私最小诊断", systemImage: "doc.on.clipboard")
            }
            if let message = viewModel.diagnosticOperationMessage {
                Text(message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text("报告只列出版本、系统、功能开关、素材数量和健康等级；不会包含用户名、路径、任务文字、Prompt、代码、事件历史、共同回忆、内容包标识或密钥，也不会自动上传。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var firstFrameSummary: String {
        guard let milliseconds = playbackHealth.firstFrameP95Milliseconds else {
            return CompanionLocalization.string(
                key: "readiness.playback.unavailable",
                fallback: "暂无可见首帧样本"
            )
        }
        return String(
            format: CompanionLocalization.string(
                key: "readiness.playback.firstFrame",
                fallback: "%d ms P95 · 目标 %d ms"
            ),
            locale: Locale.current,
            milliseconds,
            playbackHealth.firstFrameTargetMilliseconds
        )
    }

    private var attemptSummary: String {
        String(
            format: CompanionLocalization.string(
                key: "readiness.playback.attempts",
                fallback: "%d 就绪 · %d 失败 · 峰值 %d"
            ),
            locale: Locale.current,
            playbackHealth.readyCount,
            playbackHealth.failureCount,
            playbackHealth.peakActiveAttemptCount
        )
    }
}
