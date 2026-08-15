import Foundation

func companionAccessibilityText(_ key: String, _ fallback: String) -> String {
    CompanionLocalization.string(key: key, fallback: fallback)
}

func companionAccessibilityFormat(
    _ key: String,
    _ fallback: String,
    _ arguments: CVarArg...
) -> String {
    String(
        format: companionAccessibilityText(key, fallback),
        locale: Locale.current,
        arguments: arguments
    )
}

func companionCodexAccessibilityLabel(
    _ state: CompanionCodexVisualState
) -> String {
    switch state {
    case .idle:
        companionAccessibilityText("accessibility.codex.idle", "Codex 空闲")
    case .working:
        companionAccessibilityText("accessibility.codex.working", "Codex 正在工作")
    case .completed:
        companionAccessibilityText("accessibility.codex.completed", "Codex 已完成")
    case .awaitingReply:
        companionAccessibilityText(
            "accessibility.codex.awaitingReply",
            "可以回应澄音"
        )
    }
}
