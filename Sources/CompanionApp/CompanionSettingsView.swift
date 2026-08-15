import AppKit
import CompanionContracts
import Foundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: CompanionViewModel
    @ObservedObject var displayCatalog: CompanionDisplayCatalog
    @State private var isConfirmingRelationshipForget = false
    @State private var pendingRelationshipMemoryScope: CompanionRelationshipMemoryScope?
    @State private var isConfirmingCareRhythmForget = false
    @State private var pendingContentPackRemoval: CompanionContentPackSummary?

    var body: some View {
        Form {
            Section("声音") {
                Picker(
                    "提醒播放方式",
                    selection: Binding(
                        get: { viewModel.playbackMode },
                        set: { viewModel.setPlaybackMode($0) }
                    )
                ) {
                    ForEach(CompanionPlaybackMode.allCases, id: \.rawValue) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Toggle(
                    "低动态／低 GPU 模式",
                    isOn: Binding(
                        get: { viewModel.reducedDynamicEffectsEnabled },
                        set: { viewModel.setReducedDynamicEffectsEnabled($0) }
                    )
                )
                Toggle("偶尔使用亲昵称谓", isOn: $viewModel.usePetName)
                    .disabled(!viewModel.relationshipTone.allowsRomanticGestures)
                LabeledContent("声音", value: "火山 TTS 2.0 · 魅力女友")
                Text("没有录音和对话功能。仅声音模式读取预生成语音；互动与原生场景播放视频自带音轨。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("低动态模式停止循环视频与切换动画，使用轻量头像待机并强制仅声音；恢复音画同步会自动退出该模式。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("陪伴节奏") {
                Picker(
                    "关系语气",
                    selection: Binding(
                        get: { viewModel.relationshipTone },
                        set: { viewModel.setRelationshipTone($0) }
                    )
                ) {
                    ForEach(
                        CompanionRelationshipTone.allCases,
                        id: \.rawValue
                    ) { tone in
                        Text(tone.label).tag(tone)
                    }
                }
                Toggle("生活节奏关心", isOn: $viewModel.remindersEnabled)
                Picker("关心节奏", selection: $viewModel.careCadence) {
                    ForEach(CompanionCareCadence.allCases, id: \.rawValue) { cadence in
                        Text(cadence.label).tag(cadence)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!viewModel.remindersEnabled)
                Toggle(
                    "整点陪伴（每两小时）",
                    isOn: $viewModel.timeAnnouncementsEnabled
                )
                .disabled(!viewModel.remindersEnabled)
                Toggle(
                    "也在半点报时",
                    isOn: $viewModel.halfHourlyAnnouncementsEnabled
                )
                .disabled(
                    !viewModel.remindersEnabled
                        || !viewModel.timeAnnouncementsEnabled
                )
                Toggle("23:30–8:30 安静时段", isOn: $viewModel.quietHoursEnabled)
                    .disabled(!viewModel.remindersEnabled)
                Toggle("随机夸奖与轻调情", isOn: $viewModel.flirtyRemindersEnabled)
                    .disabled(
                        !viewModel.remindersEnabled
                            || !viewModel.relationshipTone.allowsFlirtyReminders
                    )
                Toggle(
                    "Codex 工作陪伴",
                    isOn: $viewModel.codexCompletionAnnouncementsEnabled
                )
                Menu("暂停主动关心") {
                    Button("暂停 30 分钟") {
                        viewModel.pauseCare(for: 30 * 60)
                    }
                    Button("暂停 1 小时") {
                        viewModel.pauseCare(for: 60 * 60)
                    }
                    Button("今天保持安静") {
                        viewModel.pauseCareForToday()
                    }
                    if viewModel.carePausedUntil != nil {
                        Divider()
                        Button("现在恢复") {
                            viewModel.resumeCare()
                        }
                    }
                }
                .disabled(!viewModel.remindersEnabled)
                Button("预览一次生活关心") {
                    viewModel.previewLifestyleCare()
                }
                Button("预览任务完成动画") {
                    viewModel.previewEvent(.taskComplete)
                }
                Button("体验完整 Codex 工作弧") {
                    viewModel.previewCodexWorkArc()
                }
                Text(viewModel.relationshipTone.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.careCadence.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.lifestyleRhythmStatus)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Button(role: .destructive) {
                    isConfirmingCareRhythmForget = true
                } label: {
                    Label(CompanionCopy.careForget, systemImage: "clock.arrow.circlepath")
                }
            }

            Section("共同回忆") {
                LabeledContent(
                    "关系章节",
                    value: viewModel.relationshipChapterLabel
                )
                LabeledContent(
                    "共同瞬间",
                    value: viewModel.relationshipMomentsLabel
                )
                LabeledContent(
                    "已发现",
                    value: viewModel.relationshipMementoLabel
                )
                LabeledContent(
                    "本次默契",
                    value: viewModel.sessionChemistryLabel
                )
                Text("进度只会增加，不会因为离开、任务失败或没有连续签到而下降。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Menu("分项管理本地记忆") {
                    ForEach(
                        CompanionRelationshipMemoryScope.allCases,
                        id: \.rawValue
                    ) { scope in
                        Button(role: .destructive) {
                            pendingRelationshipMemoryScope = scope
                        } label: {
                            Text(CompanionCopy.relationshipMemoryScopeLabel(scope))
                        }
                    }
                }
                Button(role: .destructive) {
                    isConfirmingRelationshipForget = true
                } label: {
                    Label(
                        CompanionCopy.relationshipForget,
                        systemImage: "heart.slash"
                    )
                }
            }

            CompanionWindowSettingsSection(
                viewModel: viewModel,
                displayCatalog: displayCatalog
            )

            Section("任务联动") {
                LabeledContent("监听方式", value: "本机 Codex 生命周期事件")
                LabeledContent("当前状态", value: viewModel.status)
                Text("只接收开始、进度、长任务、完成、失败等隐私最小事件，不读取任务标题、项目内容、代码或路径。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("本地内容包") {
                Toggle(
                    "启用本地内容包",
                    isOn: $viewModel.localContentPacksEnabled
                )
                LabeledContent(
                    "已安装",
                    value: "\(viewModel.contentPackSummaries.count) 个"
                )
                LabeledContent(
                    "已启用",
                    value: "\(viewModel.installedContentPackCount) 个"
                )
                LabeledContent("质量等级", value: viewModel.contentPackQualitySummary)
                LabeledContent("运行健康", value: viewModel.contentPackHealth)
                Button {
                    chooseContentPackSource()
                } label: {
                    Label("导入本地内容包…", systemImage: "shippingbox.and.arrow.backward")
                }
                .disabled(viewModel.contentPackOperationInProgress)

                if viewModel.contentPackOperationInProgress {
                    ProgressView()
                        .controlSize(.small)
                }

                if let operationMessage = viewModel.contentPackOperationMessage {
                    Text(operationMessage)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                if viewModel.contentPackUndoRemovalAvailable {
                    Button("撤销上次移除") {
                        viewModel.undoLastContentPackRemoval()
                    }
                    .disabled(viewModel.contentPackOperationInProgress)
                }

                ForEach(viewModel.contentPackSummaries) { pack in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pack.character)
                                    .font(.body.weight(.semibold))
                                Text("\(pack.packID) · \(pack.version)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            Spacer(minLength: 12)
                            Text(pack.qualityLabel)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.secondary.opacity(0.14), in: Capsule())
                        }
                        Text("\(pack.healthLabel) · \(pack.localeLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(pack.contributionLabel)
                            .font(.caption)
                            .foregroundStyle(
                                pack.contributionReady ? Color.green : Color.secondary
                            )
                        HStack {
                            if pack.canRollback {
                                Button("回滚上一版") {
                                    viewModel.rollbackContentPack(id: pack.packID)
                                }
                                .disabled(viewModel.contentPackOperationInProgress)
                            }
                            Spacer()
                            Button("移除", role: .destructive) {
                                pendingContentPackRemoval = pack
                            }
                            .disabled(viewModel.contentPackOperationInProgress)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .contain)
                }
                Text("Lab 是待首播或未完成健康验证的本地包；Stable 是已通过真实播放的本地包；Verified 还必须经过官方签名门。等级由 Core 推导，内容包不能自行声明。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(
                    CompanionLocalization.string(
                        key: "pack.contribution.explanation",
                        fallback: "“贡献证据完整”表示每项素材已声明权利、成年/虚构主体、逐语言无障碍文字和 Starter 回退；它不替代最终法律审核。"
                    )
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("导入只接受声明式素材目录，不执行脚本、不联网，也不会替换应用本体。安装失败时当前内容包保持不变。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("关闭后立即只使用内置 Starter，所有本地包仍原样保留，随时可以重新启用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            CompanionContentPackRecoverySection(viewModel: viewModel)

            Section("迁移与恢复") {
                Button {
                    chooseBackupDestination()
                } label: {
                    Label("导出便携备份…", systemImage: "externaldrive.badge.plus")
                }
                .disabled(viewModel.backupOperationInProgress)

                Button {
                    chooseBackupForRestore()
                } label: {
                    Label("检查并恢复备份…", systemImage: "arrow.counterclockwise.circle")
                }
                .disabled(viewModel.backupOperationInProgress)

                if viewModel.backupOperationInProgress {
                    ProgressView()
                        .controlSize(.small)
                }
                if let message = viewModel.backupOperationMessage {
                    Text(message)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Text("便携备份只包含当前偏好和已启用的本地内容包，不包含共同回忆、Codex 会话、任务、Prompt、代码、路径或事件记录。恢复前会先展示来源版本和内容包数量。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            CompanionRuntimeHealthSettingsSection(viewModel: viewModel)
            CompanionSupportDiagnosticsSettingsSection(viewModel: viewModel)

            Section("当前版本") {
                LabeledContent("澄音", value: appVersionLabel)
                Text("关系记忆、Codex 工作弧与任务完成后的手势回应已经启用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            CompanionCopy.relationshipForgetConfirmation,
            isPresented: $isConfirmingRelationshipForget,
            titleVisibility: .visible
        ) {
            Button(
                CompanionCopy.relationshipForgetConfirmButton,
                role: .destructive
            ) {
                viewModel.forgetRelationshipMemories()
            }
            Button(CompanionCopy.cancel, role: .cancel) {}
        } message: {
            Text(CompanionCopy.relationshipForgetExplanation)
        }
        .confirmationDialog(
            pendingRelationshipMemoryScope.map(
                CompanionCopy.relationshipForgetScopeConfirmation
            ) ?? CompanionLocalization.string(
                key: "relationship.scope.clear.fallback",
                fallback: "清除本地记忆？"
            ),
            isPresented: Binding(
                get: { pendingRelationshipMemoryScope != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingRelationshipMemoryScope = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let scope = pendingRelationshipMemoryScope {
                Button(
                    CompanionCopy.relationshipForgetScopeButton(scope),
                    role: .destructive
                ) {
                    viewModel.forgetRelationshipMemory(scope)
                    pendingRelationshipMemoryScope = nil
                }
            }
            Button(CompanionCopy.cancel, role: .cancel) {
                pendingRelationshipMemoryScope = nil
            }
        } message: {
            Text("只删除所选字段；其他共同回忆和陪伴语气保持不变。")
        }
        .confirmationDialog(
            CompanionCopy.careForgetConfirmation,
            isPresented: $isConfirmingCareRhythmForget,
            titleVisibility: .visible
        ) {
            Button(CompanionCopy.careForget, role: .destructive) {
                viewModel.forgetCareRhythmMemory()
            }
            Button(CompanionCopy.cancel, role: .cancel) {}
        } message: {
            Text(CompanionCopy.careForgetExplanation)
        }
        .confirmationDialog(
            "移除这个本地内容包？",
            isPresented: Binding(
                get: { pendingContentPackRemoval != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingContentPackRemoval = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let pack = pendingContentPackRemoval {
                Button(
                    CompanionLocalization.format(
                        key: "pack.remove.button",
                        fallback: "移除 %@",
                        pack.character
                    ),
                    role: .destructive
                ) {
                    viewModel.removeContentPack(id: pack.packID)
                    pendingContentPackRemoval = nil
                }
            }
            Button(CompanionCopy.cancel, role: .cancel) {
                pendingContentPackRemoval = nil
            }
        } message: {
            Text("素材会移到本机恢复区，不会立即永久删除；重启后仍可恢复。")
        }
        .confirmationDialog(
            "恢复这份便携备份？",
            isPresented: Binding(
                get: { viewModel.pendingBackupPreview != nil },
                set: { isPresented in
                    if !isPresented && !viewModel.backupOperationInProgress {
                        viewModel.cancelPortableBackupRestore()
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let preview = viewModel.pendingBackupPreview {
                Button(
                    CompanionLocalization.format(
                        key: "backup.restore.action",
                        fallback: "恢复设置与 %d 个内容包",
                        preview.packCount
                    )
                ) {
                    viewModel.restoreInspectedPortableBackup()
                }
            }
            Button(CompanionCopy.cancel, role: .cancel) {
                viewModel.cancelPortableBackupRestore()
            }
        } message: {
            if let preview = viewModel.pendingBackupPreview {
                Text(
                    CompanionLocalization.format(
                        key: "backup.restore.preview",
                        fallback: "备份来自澄音 %@，创建于 %@。当前关系记忆不会被覆盖。",
                        preview.appVersion,
                        preview.createdAt.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                )
            }
        }
    }

    private func chooseContentPackSource() {
        guard let source = CompanionContentPackImportPanel.choose() else { return }
        viewModel.importContentPack(from: source)
    }

    private func chooseBackupDestination() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Chengyin Backup \(Date().formatted(.iso8601.year().month().day()))"
        panel.prompt = CompanionLocalization.string(
            key: "backup.export.prompt",
            fallback: "导出备份"
        )
        panel.message = CompanionLocalization.string(
            key: "backup.export.message",
            fallback: "请选择一个尚不存在的新目录名称。"
        )
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        viewModel.exportPortableBackup(to: destination)
    }

    private func chooseBackupForRestore() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = CompanionLocalization.string(
            key: "backup.restore.prompt",
            fallback: "检查备份"
        )
        panel.message = CompanionLocalization.string(
            key: "backup.restore.message",
            fallback: "请选择包含 backup.json 的澄音便携备份目录。"
        )
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        viewModel.inspectPortableBackup(at: directory)
    }

    private var appVersionLabel: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? CompanionLocalization.string(
            key: "build.version.development",
            fallback: "开发版"
        )
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? CompanionLocalization.string(
            key: "build.version.local",
            fallback: "本地"
        )
        return "\(version) (\(build))"
    }
}
