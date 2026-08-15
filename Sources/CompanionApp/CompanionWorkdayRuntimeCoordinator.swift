#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Combine
import Foundation

struct CompanionWorkdayRuntimeReceipt {
    let decision: CompanionWorkDecision
    let presentation: CompanionWorkdayPresentationPlan
    let persistenceError: CompanionWorkdayAdapterError?
}

struct CompanionCompletionReplyToken: Equatable, Sendable {
    fileprivate let generation: UInt64
}

/// Owns the local shared-workday runtime without owning any presentation media,
/// windows, speech, relationship text or private task content. The view model
/// contributes only bounded attention facts and applies the returned semantic
/// presentation plan.
@MainActor
final class CompanionWorkdayRuntimeCoordinator: ObservableObject {
    @Published private(set) var state: CompanionWorkdayStateV1
    @Published private(set) var completionReplyWindowActive = false
    @Published private(set) var eventBridgeReady = false
    @Published private(set) var eventBridgeCode: String?

    private let adapter: CompanionWorkdayAdapter
    private let watcher: CodexCompletionWatcher
    private var pollingTask: Task<Void, Never>?
    private var replyTask: Task<Void, Never>?
    private var pollingGeneration: UInt64 = 0
    private var replyGeneration: UInt64 = 0
    private var completionReplyDeadline: Date?

    init(
        adapter: CompanionWorkdayAdapter,
        watcher: CodexCompletionWatcher = CodexCompletionWatcher()
    ) {
        self.adapter = adapter
        self.watcher = watcher
        state = adapter.state
    }

    convenience init(
        now: Date = Date(),
        watcher: CodexCompletionWatcher = CodexCompletionWatcher()
    ) {
        self.init(
            adapter: CompanionWorkdayAdapter(now: now),
            watcher: watcher
        )
    }

    deinit {
        pollingTask?.cancel()
        replyTask?.cancel()
    }

    var hasActiveWork: Bool {
        adapter.hasActiveWork
    }

    var recoverySource: CompanionWorkdayStateRecoverySource {
        adapter.recoverySource
    }

    @discardableResult
    func refreshDay(at now: Date) -> CompanionWorkdayAdapterError? {
        let error = adapter.refresh(at: now)
        state = adapter.state
        return error
    }

    func resetDay(at now: Date, calendar: Calendar = .current) throws {
        try adapter.reset(at: now, calendar: calendar)
        state = adapter.state
        closeCompletionReplyWindow()
    }

    func consume(
        _ signal: CodexTaskSignal,
        allowsPassivePresenceUpdate: Bool
    ) -> CompanionWorkdayRuntimeReceipt {
        let mutation = adapter.consume(
            type: signal.effectiveWorkdayEventType,
            eventID: signal.id,
            taskRef: signal.taskRef,
            duration: signal.duration,
            occurredAt: signal.occurredAt
        )
        state = adapter.state
        let presentation = CompanionWorkdayExperiencePolicy.plan(
            for: mutation.decision,
            context: CompanionWorkdayPresentationContext(
                allowsPassivePresenceUpdate: allowsPassivePresenceUpdate,
                hasActiveWork: adapter.hasActiveWork,
                completionReplyWindowActive: completionReplyWindowActive
            )
        )
        return CompanionWorkdayRuntimeReceipt(
            decision: mutation.decision,
            presentation: presentation,
            persistenceError: mutation.persistenceError
        )
    }

    func startPolling(
        every intervalNanoseconds: UInt64 = 5_000_000_000,
        announcementsEnabled: @escaping @MainActor () -> Bool,
        onSignal: @escaping @MainActor (CodexTaskSignal) -> Void,
        onReadinessChanged: @escaping @MainActor () -> Void
    ) {
        stopPolling()
        pollingGeneration &+= 1
        let generation = pollingGeneration
        let boundedInterval = max(1_000_000, intervalNanoseconds)

        pollingTask = Task { [weak self] in
            guard let self else { return }
            await watcher.prime()
            guard isCurrentPollingGeneration(generation) else { return }
            let initialHealth = await watcher.protocolBridgeHealth()
            applyEventBridgeHealth(initialHealth)
            guard isCurrentPollingGeneration(generation) else { return }
            onReadinessChanged()

            while isCurrentPollingGeneration(generation) {
                do {
                    try await Task.sleep(nanoseconds: boundedInterval)
                } catch {
                    return
                }
                guard isCurrentPollingGeneration(generation) else { return }
                let receipt = await watcher.pollWithHealth()
                guard isCurrentPollingGeneration(generation) else { return }
                let previousReady = eventBridgeReady
                let healthChanged = applyEventBridgeHealth(receipt.eventBridgeHealth)
                if healthChanged {
                    onReadinessChanged()
                }
                guard announcementsEnabled() else { continue }
                if healthChanged {
                    onSignal(
                        CodexTaskSignal(
                            id: UUID().uuidString,
                            type: previousReady && !eventBridgeReady
                                ? .integrationDisconnected
                                : .integrationHealth,
                            origin: .runtimeHealth
                        )
                    )
                }
                for signal in receipt.signals {
                    guard isCurrentPollingGeneration(generation) else { return }
                    onSignal(signal)
                }
            }
        }
    }

    func stopPolling() {
        pollingGeneration &+= 1
        pollingTask?.cancel()
        pollingTask = nil
    }

    @discardableResult
    func refreshEventBridgeReadiness() async -> Bool {
        let health = await watcher.protocolBridgeHealth()
        applyEventBridgeHealth(health)
        return health.isReady
    }

    func repairEventBridge() async -> CompanionEventBridgeRepairReceipt {
        let receipt = await watcher.repairProtocolBridge()
        eventBridgeReady = receipt.isReady
        eventBridgeCode = receipt.isReady ? nil : receipt.code
        return receipt
    }

    @discardableResult
    func openCompletionReplyWindow(
        for duration: TimeInterval,
        onExpired: @escaping @MainActor () -> Void
    ) -> CompanionCompletionReplyToken {
        closeCompletionReplyWindow()
        replyGeneration &+= 1
        let generation = replyGeneration
        let boundedDuration = duration.isFinite
            ? min(max(duration, 0.001), 5 * 60)
            : 0.001
        completionReplyDeadline = Date().addingTimeInterval(boundedDuration)
        completionReplyWindowActive = true

        replyTask = Task { [weak self] in
            do {
                try await Task.sleep(
                    nanoseconds: UInt64(boundedDuration * 1_000_000_000)
                )
            } catch {
                return
            }
            guard let self,
                  isCurrentReplyGeneration(generation)
            else { return }
            replyTask = nil
            completionReplyDeadline = nil
            completionReplyWindowActive = false
            onExpired()
        }
        return CompanionCompletionReplyToken(generation: generation)
    }

    @discardableResult
    func closeCompletionReplyWindow() -> Bool {
        let wasActive = completionReplyWindowActive
        replyGeneration &+= 1
        replyTask?.cancel()
        replyTask = nil
        completionReplyDeadline = nil
        completionReplyWindowActive = false
        return wasActive
    }

    func isCompletionReplyWindowOpen(at date: Date = Date()) -> Bool {
        guard completionReplyWindowActive,
              let completionReplyDeadline
        else { return false }
        return date < completionReplyDeadline
    }

    private func isCurrentPollingGeneration(_ generation: UInt64) -> Bool {
        !Task.isCancelled && pollingGeneration == generation
    }

    @discardableResult
    private func applyEventBridgeHealth(_ health: CodexEventBridgeHealth) -> Bool {
        let changed = eventBridgeReady != health.isReady
            || eventBridgeCode != health.code
        eventBridgeReady = health.isReady
        eventBridgeCode = health.code
        return changed
    }

    private func isCurrentReplyGeneration(_ generation: UInt64) -> Bool {
        !Task.isCancelled && replyGeneration == generation
    }
}
