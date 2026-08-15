#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Foundation

enum CompanionLifestyleMemoryAdapterError: Error, CompanionErrorCoding {
    case persistenceFailed
    case resetFailed

    var companionErrorCode: String {
        switch self {
        case .persistenceFailed:
            "CARE_MEMORY_PERSISTENCE_FAILED"
        case .resetFailed:
            "CARE_MEMORY_RESET_FAILED"
        }
    }
}

/// Main-actor bridge between the pure/versioned care-memory contract and App
/// orchestration. The view model reads one coherent snapshot rather than owning
/// seven UserDefaults fields and their legacy migration rules.
@MainActor
final class CompanionLifestyleMemoryAdapter {
    private let store: CompanionLifestyleMemoryStore

    private(set) var state: CompanionLifestyleMemoryV1
    private(set) var recoverySource: CompanionLifestyleMemoryRecoverySource

    init(
        store: CompanionLifestyleMemoryStore = CompanionLifestyleMemoryStore(),
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.store = store
        let result = store.load(at: now, calendar: calendar)
        state = result.state
        recoverySource = result.recoverySource
    }

    func refresh(
        at now: Date,
        calendar: Calendar = .current
    ) throws {
        var candidate = state
        guard candidate.rollForward(at: now, calendar: calendar) else { return }
        do {
            state = try store.save(candidate, at: now, calendar: calendar)
        } catch {
            throw CompanionLifestyleMemoryAdapterError.persistenceFailed
        }
    }

    func update(
        at now: Date,
        calendar: Calendar = .current,
        _ transform: (inout CompanionLifestyleMemoryV1) throws -> Void
    ) throws {
        do {
            state = try store.update(
                at: now,
                calendar: calendar,
                transform
            )
        } catch {
            throw CompanionLifestyleMemoryAdapterError.persistenceFailed
        }
    }

    func reset(
        at now: Date,
        calendar: Calendar = .current
    ) throws {
        do {
            state = try store.reset(at: now, calendar: calendar)
            recoverySource = .primary
        } catch {
            throw CompanionLifestyleMemoryAdapterError.resetFailed
        }
    }
}
