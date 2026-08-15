import Foundation

/// Stable, privacy-minimal capabilities used by the progressive pet coach.
///
/// The persisted representation contains only these capability identifiers. It
/// never records pointer coordinates, timestamps, task data, or an interaction
/// history.
public enum CompanionGestureCapability: String, CaseIterable, Sendable {
    case singleTap
    case doubleTap
    case longPress
    case drag
}

public struct CompanionGestureLearningState: Equatable, Sendable {
    private var learned: Set<CompanionGestureCapability>

    public init(learnedIDs: [String] = []) {
        learned = Set(learnedIDs.compactMap(CompanionGestureCapability.init(rawValue:)))
    }

    public var completedCount: Int { learned.count }

    public var totalCount: Int { CompanionGestureCapability.allCases.count }

    public var isComplete: Bool { completedCount == totalCount }

    public var nextLesson: CompanionGestureCapability? {
        CompanionGestureCapability.allCases.first { !learned.contains($0) }
    }

    public var learnedIDs: [String] {
        CompanionGestureCapability.allCases
            .filter(learned.contains)
            .map(\.rawValue)
    }

    @discardableResult
    public mutating func markLearned(_ capability: CompanionGestureCapability) -> Bool {
        learned.insert(capability).inserted
    }

    public mutating func reset() {
        learned.removeAll()
    }
}
