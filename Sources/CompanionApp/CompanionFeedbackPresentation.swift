import Foundation

private func feedbackText(_ key: String, _ fallback: String) -> String {
    CompanionLocalization.string(key: key, fallback: fallback)
}

private func feedbackFormat(
    _ key: String,
    _ fallback: String,
    _ arguments: CVarArg...
) -> String {
    String(
        format: feedbackText(key, fallback),
        locale: Locale.current,
        arguments: arguments
    )
}

/// Presentation-only state for the Codex work arc.
///
/// This is intentionally separate from `PetMood`: direct interaction can make the
/// character playful while Codex is still working, but the work indicator must
/// continue to tell the truth.
enum CompanionCodexVisualState: Equatable, Sendable {
    case idle
    case working
    case completed
    case awaitingReply
}

struct CompanionRelationshipFeedbackSnapshot: Equatable, Sendable {
    let bondMoments: UInt64
    let chemistryLevel: Int
    let mementoIDs: Set<String>
}

enum CompanionRelationshipReceiptKind: Equatable, Sendable {
    case moment(delta: UInt64)
    case chemistry(level: Int)
    case firstMemento
    case memento(count: Int)
    case chapter(label: String)

    var title: String {
        switch self {
        case let .moment(delta):
            feedbackFormat("feedback.moment.title", "共同瞬间 +%llu", delta)
        case let .chemistry(level):
            switch level {
            case 1:
                feedbackText("feedback.chemistry.one", "开始合拍了")
            case 2:
                feedbackText("feedback.chemistry.two", "越来越有默契")
            default:
                feedbackText("feedback.chemistry.three", "今晚特别合拍")
            }
        case .firstMemento:
            feedbackText("feedback.memento.first", "发现第一件纪念物")
        case let .memento(count):
            count == 1
                ? feedbackText("feedback.memento.one", "发现新纪念物")
                : feedbackFormat("feedback.memento.many", "发现 %d 件新纪念物", count)
        case .chapter:
            feedbackText("feedback.chapter.title", "我们的新章节")
        }
    }

    var compactTitle: String {
        switch self {
        case let .moment(delta):
            feedbackFormat("feedback.moment.compact", "瞬间 +%llu", delta)
        case .chemistry:
            feedbackText("feedback.chemistry.compact", "默契升温")
        case .firstMemento, .memento:
            feedbackText("feedback.memento.compact", "新纪念物")
        case .chapter:
            feedbackText("feedback.chapter.compact", "新章节")
        }
    }

    var detail: String? {
        switch self {
        case .moment, .firstMemento, .memento:
            nil
        case .chemistry:
            feedbackText("feedback.chemistry.detail", "接下来的回应会更懂你的节奏")
        case let .chapter(label):
            label
        }
    }

    var symbolName: String {
        switch self {
        case .moment:
            "heart.fill"
        case .chemistry:
            "sparkles"
        case .firstMemento, .memento:
            "gift.fill"
        case .chapter:
            "sparkles"
        }
    }

    var isMilestone: Bool {
        switch self {
        case .moment, .chemistry:
            false
        case .firstMemento, .memento, .chapter:
            true
        }
    }

    var displayDuration: TimeInterval {
        isMilestone ? 2.4 : 1.55
    }
}

struct CompanionRelationshipReceipt: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: CompanionRelationshipReceiptKind

    init(
        id: UUID = UUID(),
        kind: CompanionRelationshipReceiptKind
    ) {
        self.id = id
        self.kind = kind
    }
}

enum CompanionRelationshipFeedbackPolicy {
    static func chapterIndex(for bondMoments: UInt64) -> Int {
        switch bondMoments {
        case 0..<6:
            0
        case 6..<18:
            1
        case 18..<40:
            2
        case 40..<80:
            3
        default:
            4
        }
    }

    static func chapterLabel(for bondMoments: UInt64) -> String {
        switch chapterIndex(for: bondMoments) {
        case 0:
            feedbackText("relationship.chapter.zero", "初识")
        case 1:
            feedbackText("relationship.chapter.one", "渐有默契")
        case 2:
            feedbackText("relationship.chapter.two", "两人的小秘密")
        case 3:
            feedbackText("relationship.chapter.three", "熟悉陪伴")
        default:
            feedbackText("relationship.chapter.four", "两人的小世界")
        }
    }

    static func receipts(
        before: CompanionRelationshipFeedbackSnapshot,
        after: CompanionRelationshipFeedbackSnapshot
    ) -> [CompanionRelationshipReceiptKind] {
        var result: [CompanionRelationshipReceiptKind] = []

        if after.bondMoments > before.bondMoments {
            result.append(
                .moment(delta: after.bondMoments - before.bondMoments)
            )
        }

        if after.chemistryLevel > before.chemistryLevel {
            result.append(.chemistry(level: after.chemistryLevel))
        }

        let newlyUnlocked = after.mementoIDs.subtracting(before.mementoIDs)
        if !newlyUnlocked.isEmpty {
            result.append(
                before.mementoIDs.isEmpty
                    ? .firstMemento
                    : .memento(count: newlyUnlocked.count)
            )
        }

        let previousChapter = chapterIndex(for: before.bondMoments)
        let currentChapter = chapterIndex(for: after.bondMoments)
        if currentChapter > previousChapter {
            result.append(
                .chapter(label: chapterLabel(for: after.bondMoments))
            )
        }

        return result
    }
}
