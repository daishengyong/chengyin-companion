#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Combine
import Foundation

struct CompanionSharedDayCareFacts {
    let remindersEnabled: Bool
    let userRecentlyActive: Bool
    let quietHoursEnabled: Bool
    let timeAnnouncementsEnabled: Bool
    let halfHourlyAnnouncementsEnabled: Bool
    let cadence: CompanionCareCadencePreference
    let activityState: CompanionLifestyleActivityState
}

struct CompanionSharedDayCareReceipt {
    let lifestyle: CompanionLifestyleRuntimeReceipt
    let workdayPersistenceError: CompanionWorkdayAdapterError?
}

/// Owns the two cancellable clocks that make one local shared day: periodic
/// care evaluation and trusted Codex event polling. It receives only bounded
/// activity/preferences facts and returns semantic receipts; media, speech,
/// windows, relationship copy and private task content remain outside.
@MainActor
final class CompanionSharedDayRuntimeCoordinator: ObservableObject {
    let workday: CompanionWorkdayRuntimeCoordinator
    let lifestyle: CompanionLifestyleRuntimeCoordinator

    private var careTask: Task<Void, Never>?
    private var careGeneration: UInt64 = 0
    private var workdayObservation: AnyCancellable?

    init(
        workday: CompanionWorkdayRuntimeCoordinator,
        lifestyle: CompanionLifestyleRuntimeCoordinator
    ) {
        self.workday = workday
        self.lifestyle = lifestyle
        workdayObservation = workday.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    deinit {
        careTask?.cancel()
    }

    func evaluateCare(
        at now: Date,
        facts: CompanionSharedDayCareFacts,
        calendar: Calendar = .current
    ) -> CompanionSharedDayCareReceipt {
        let workdayError = workday.refreshDay(at: now)
        let lifestyleReceipt = lifestyle.evaluate(
            at: now,
            remindersEnabled: facts.remindersEnabled,
            userRecentlyActive: facts.userRecentlyActive,
            quietHoursEnabled: facts.quietHoursEnabled,
            timeAnnouncementsEnabled: facts.timeAnnouncementsEnabled,
            halfHourlyAnnouncementsEnabled: facts.halfHourlyAnnouncementsEnabled,
            cadence: facts.cadence,
            activityState: facts.activityState,
            calendar: calendar
        )
        return CompanionSharedDayCareReceipt(
            lifestyle: lifestyleReceipt,
            workdayPersistenceError: workdayError
        )
    }

    func start(
        careEvery intervalNanoseconds: UInt64 = 30_000_000_000,
        workEvery workIntervalNanoseconds: UInt64 = 5_000_000_000,
        careFacts: @escaping @MainActor () -> CompanionSharedDayCareFacts?,
        onCareReceipt: @escaping @MainActor (
            CompanionSharedDayCareReceipt,
            Date
        ) -> Void,
        announcementsEnabled: @escaping @MainActor () -> Bool,
        onWorkSignal: @escaping @MainActor (CodexTaskSignal) -> Void,
        onReadinessChanged: @escaping @MainActor () -> Void
    ) {
        startCareLoop(
            every: intervalNanoseconds,
            facts: careFacts,
            onReceipt: onCareReceipt
        )
        workday.startPolling(
            every: workIntervalNanoseconds,
            announcementsEnabled: announcementsEnabled,
            onSignal: onWorkSignal,
            onReadinessChanged: onReadinessChanged
        )
    }

    func stop() {
        stopCareLoop()
        workday.stopPolling()
    }

    func stopCareLoop() {
        careGeneration &+= 1
        careTask?.cancel()
        careTask = nil
    }

    private func startCareLoop(
        every intervalNanoseconds: UInt64,
        facts: @escaping @MainActor () -> CompanionSharedDayCareFacts?,
        onReceipt: @escaping @MainActor (
            CompanionSharedDayCareReceipt,
            Date
        ) -> Void
    ) {
        stopCareLoop()
        careGeneration &+= 1
        let generation = careGeneration
        let boundedInterval = max(1_000_000, intervalNanoseconds)

        careTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: boundedInterval)
                } catch {
                    return
                }
                guard let self,
                      isCurrentCareGeneration(generation),
                      let currentFacts = facts()
                else { return }
                let now = Date()
                let receipt = evaluateCare(at: now, facts: currentFacts)
                guard isCurrentCareGeneration(generation) else { return }
                onReceipt(receipt, now)
            }
        }
    }

    private func isCurrentCareGeneration(_ generation: UInt64) -> Bool {
        !Task.isCancelled && careGeneration == generation
    }
}
