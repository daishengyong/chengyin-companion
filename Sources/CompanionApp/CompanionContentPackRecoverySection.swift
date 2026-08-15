import SwiftUI

struct CompanionContentPackRecoverySection: View {
    @ObservedObject var viewModel: CompanionViewModel
    @State private var pendingPurge: ContentPackRecoveryItem?

    var body: some View {
        Section(localized("pack.recovery.title", "本地恢复区")) {
            LabeledContent(
                localized("pack.recovery.count", "可管理条目"),
                value: "\(viewModel.contentPackRecoveryItems.count)"
            )
            if viewModel.contentPackRecoveryItems.isEmpty {
                Text(localized("pack.recovery.empty", "没有待恢复或待清理的内容包。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(viewModel.contentPackRecoveryItems) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.character ?? item.packID ?? localized(
                                "pack.recovery.unknown",
                                "待检查的恢复项"
                            ))
                            .font(.body.weight(.semibold))
                            if let version = item.version {
                                Text(version)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 12)
                        Text(stateLabel(item))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(
                                item.state == .recoverable ? Color.green : Color.orange
                            )
                    }
                    if let removedAt = item.removedAt {
                        Text(removedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let failureCode = item.failureCode {
                        Text(failureCode)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    HStack {
                        if item.state == .recoverable {
                            Button(localized("pack.recovery.restore", "恢复")) {
                                viewModel.restoreContentPackRecoveryItem(id: item.id)
                            }
                            .accessibilityIdentifier("contentPackRecovery.restore")
                        }
                        Spacer()
                        Button(
                            localized("pack.recovery.purge", "永久清理"),
                            role: .destructive
                        ) {
                            pendingPurge = item
                        }
                        .accessibilityIdentifier("contentPackRecovery.purge")
                    }
                    .disabled(viewModel.contentPackOperationInProgress)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .contain)
            }
            Text(localized(
                "pack.recovery.explanation",
                "移除后的内容包会跨重启保留。恢复会重新验证完整内容；永久清理只删除这一项且不可撤销。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .confirmationDialog(
            localized("pack.recovery.purge.confirmation", "永久清理这个恢复项？"),
            isPresented: Binding(
                get: { pendingPurge != nil },
                set: { if !$0 { pendingPurge = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let item = pendingPurge {
                Button(
                    localized("pack.recovery.purge.confirm", "永久清理"),
                    role: .destructive
                ) {
                    viewModel.purgeContentPackRecoveryItem(id: item.id)
                    pendingPurge = nil
                }
            }
            Button(CompanionCopy.cancel, role: .cancel) { pendingPurge = nil }
        } message: {
            Text(localized(
                "pack.recovery.purge.warning",
                "这只会删除选中的本地恢复项，但删除后无法撤销。"
            ))
        }
    }

    private func stateLabel(_ item: ContentPackRecoveryItem) -> String {
        item.state == .recoverable
            ? localized("pack.recovery.state.recoverable", "可恢复")
            : localized("pack.recovery.state.cleanup", "需要清理")
    }

    private func localized(_ key: String, _ fallback: String) -> String {
        CompanionLocalization.string(key: key, fallback: fallback)
    }
}
