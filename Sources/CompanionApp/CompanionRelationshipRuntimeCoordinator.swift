import Combine
import CompanionContracts
import Foundation

struct CompanionRelationshipPlaybackMemory: Equatable, Sendable {
    let recentAssetIDs: [String]
    let lastPlayedAtByAssetID: [String: Date]
}

/// Owns the local relationship-memory session outside the app composition root.
///
/// Persisted values remain limited to the Core relationship schema plus a bounded
/// list of opaque presentation keys. This coordinator does not know task text,
/// prompts, filesystem paths, windows, media URLs, speech or network services.
@MainActor
final class CompanionRelationshipRuntimeCoordinator: ObservableObject {
    @Published private(set) var state: CompanionRelationshipStateV1
    @Published private(set) var receipt: CompanionRelationshipReceipt?

    private let store: CompanionRelationshipStateStore
    private let defaults: UserDefaults
    private let chemistryDirector: CompanionChemistryInteractionDirector
    private let recentMomentKey: String
    private var receiptTask: Task<Void, Never>?
    private var pendingReceipts: [CompanionRelationshipReceipt] = []
    private var momentRecordedAt: [String: Date] = [:]
    private var recentMomentKeys: [String]
    private var lastReadyRecordedAtByAssetID: [String: Date] = [:]

    init(
        store: CompanionRelationshipStateStore = CompanionRelationshipStateStore(),
        defaults: UserDefaults = .standard,
        chemistryDirector: CompanionChemistryInteractionDirector =
            CompanionChemistryInteractionDirector(),
        recentMomentKey: String = CompanionDefaultsKeys.recentPetMomentKeys
    ) {
        self.store = store
        self.defaults = defaults
        self.chemistryDirector = chemistryDirector
        self.recentMomentKey = recentMomentKey
        state = store.load()
        recentMomentKeys = Array(
            (defaults.stringArray(forKey: recentMomentKey) ?? []).suffix(8)
        )
    }

    deinit {
        receiptTask?.cancel()
    }

    var pendingReceiptCount: Int { pendingReceipts.count }
    var recentMomentKeyCount: Int { recentMomentKeys.count }

    func update(
        _ transform: (inout CompanionRelationshipStateV1) throws -> Void
    ) throws {
        let before = feedbackSnapshot
        state = try store.update(transform)
        enqueue(
            CompanionRelationshipFeedbackPolicy.receipts(
                before: before,
                after: feedbackSnapshot
            )
        )
    }

    @discardableResult
    func forgetAllMemory() throws -> CompanionRelationshipStateV1 {
        state = try store.forgetAllMemory()
        momentRecordedAt.removeAll()
        resetPlaybackHistory()
        resetReceiptQueue()
        return state
    }

    @discardableResult
    func forgetMemory(
        _ scope: CompanionRelationshipMemoryScope
    ) throws -> CompanionRelationshipStateV1 {
        state = try store.forgetMemory([scope])
        switch scope {
        case .sharedProgress:
            momentRecordedAt.removeAll()
            resetReceiptQueue()
        case .playbackHistory:
            resetPlaybackHistory()
        case .sessionChemistry, .surpriseProgress, .mementos:
            break
        }
        return state
    }

    /// Records one positive interaction at most once per key/cooldown window.
    /// Returns false for a cooldown suppression without touching persistence.
    @discardableResult
    func recordMoment(
        _ key: String,
        bond: UInt64 = 1,
        chemistry: Int = 1,
        mementoID: String? = nil,
        advanceSurprise: Bool = true,
        cooldown: TimeInterval = 18,
        at date: Date = Date()
    ) throws -> Bool {
        if cooldown > 0,
           let previous = momentRecordedAt[key],
           date.timeIntervalSince(previous) < cooldown {
            return false
        }

        try update { state in
            state.recordPositiveMoment(bond)
            _ = state.increaseChemistry(by: chemistry)
            if advanceSurprise {
                _ = state.advanceSurprise()
            }
            if let mementoID {
                _ = try state.unlockMemento(mementoID)
            }
        }
        momentRecordedAt[key] = date
        return true
    }

    func unlockMemento(_ identifier: String) throws {
        try update { state in
            _ = try state.unlockMemento(identifier)
        }
    }

    var playbackMemory: CompanionRelationshipPlaybackMemory {
        CompanionRelationshipPlaybackMemory(
            recentAssetIDs: state.recentAssetIDs,
            lastPlayedAtByAssetID: state.lastPlayedAtByAssetID
        )
    }

    /// Commits an opaque playback identifier at most once in a short ready loop.
    @discardableResult
    func rememberPlayedAsset(
        _ identifier: String,
        at date: Date = Date()
    ) throws -> Bool {
        if let previous = lastReadyRecordedAtByAssetID[identifier],
           date.timeIntervalSince(previous) < 2 {
            return false
        }
        try update { state in
            try state.rememberAsset(identifier, at: date)
        }
        lastReadyRecordedAtByAssetID[identifier] = date
        return true
    }

    func selectPetMoment(
        for interaction: CompanionDirectedInteraction,
        at date: Date,
        mood: CompanionInteractionMood,
        currentMomentKeys: Set<String>
    ) -> PetMoment? {
        let context = CompanionChemistryInteractionContext(
            at: date,
            relationshipTone: state.toneCap,
            chemistryLevel: state.chemistryLevel,
            mood: mood,
            recentMomentKeys: recentMomentKeys + currentMomentKeys.sorted()
        )
        var randomNumberGenerator = SystemRandomNumberGenerator()
        guard let directed = chemistryDirector.select(
            for: interaction,
            context: context,
            using: &randomNumberGenerator
        )?.selected else {
            return nil
        }

        let selected = PetMoment(directed)
        recentMomentKeys.append(selected.key)
        recentMomentKeys = Array(recentMomentKeys.suffix(8))
        defaults.set(recentMomentKeys, forKey: recentMomentKey)
        return selected
    }

    func resetTransientFeedbackForTesting() {
        resetReceiptQueue()
    }

    private var feedbackSnapshot: CompanionRelationshipFeedbackSnapshot {
        CompanionRelationshipFeedbackSnapshot(
            bondMoments: state.bondMoments,
            chemistryLevel: state.chemistryLevel,
            mementoIDs: Set(state.unlockedMementoIDs)
        )
    }

    private func enqueue(_ kinds: [CompanionRelationshipReceiptKind]) {
        guard !kinds.isEmpty else { return }
        pendingReceipts.append(
            contentsOf: kinds.map {
                CompanionRelationshipReceipt(kind: $0)
            }
        )
        pendingReceipts = Array(pendingReceipts.prefix(6))
        presentNextReceiptIfNeeded()
    }

    private func presentNextReceiptIfNeeded() {
        guard receipt == nil, !pendingReceipts.isEmpty else { return }

        let nextReceipt = pendingReceipts.removeFirst()
        receipt = nextReceipt
        receiptTask?.cancel()
        receiptTask = Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(
                    nextReceipt.kind.displayDuration * 1_000_000_000
                )
            )
            guard !Task.isCancelled, let self else { return }
            receipt = nil
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            receiptTask = nil
            presentNextReceiptIfNeeded()
        }
    }

    private func resetReceiptQueue() {
        pendingReceipts.removeAll()
        receiptTask?.cancel()
        receiptTask = nil
        receipt = nil
    }

    private func resetPlaybackHistory() {
        recentMomentKeys.removeAll()
        lastReadyRecordedAtByAssetID.removeAll()
        defaults.removeObject(forKey: recentMomentKey)
    }
}
