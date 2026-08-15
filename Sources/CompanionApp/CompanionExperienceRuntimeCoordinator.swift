import Combine
#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Foundation

struct CompanionExperiencePresentationToken: Equatable, Sendable {
    fileprivate let generation: UInt64
}
struct CompanionPendingExperience<Event: Hashable & Sendable>: Equatable, Sendable {
    let event: Event
    let completionContext: CompanionCompletionContext?
    let source: CompanionExperienceSource
    let coalescedCount: Int
}
enum CompanionExperienceEnqueueOutcome: String, Equatable, Sendable {
    case accepted
    case acceptedTrustedOverflow
    case replacedLowerPriority
    case coalescedTrustedTerminal
    case rejectedCapacity
}
struct CompanionExperienceEnqueueReceipt: Equatable, Sendable {
    let outcome: CompanionExperienceEnqueueOutcome
    let pendingCount: Int

    var retained: Bool { outcome != .rejectedCapacity }
}

/// Owns session-local attention arbitration and presentation lifetime.
///
/// No event payload is persisted. The coordinator knows no media, window,
/// speech, relationship, task identifier, prompt, path or user-authored text.
/// A generation token prevents an old timer from finishing a newer visual.
@MainActor
final class CompanionExperienceRuntimeCoordinator<
    Event: Hashable & Sendable
>: ObservableObject {
    @Published private(set) var isPresentationActive = false
    @Published private(set) var pendingCount = 0

    private let normalCapacity: Int
    private let trustedCapacity: Int
    private var director: CompanionExperienceDirector
    private var pending: [CompanionPendingExperience<Event>] = []
    private var generation: UInt64 = 0
    private var activeToken: CompanionExperiencePresentationToken?
    private var presentationTask: Task<Void, Never>?
    private var replayTask: Task<Void, Never>?
    private var handoffTask: Task<Void, Never>?
    init(
        normalCapacity: Int = 4,
        trustedCapacity: Int = 32,
        attentionPolicy: CompanionAttentionPolicy = CompanionAttentionPolicy()
    ) {
        self.normalCapacity = max(1, normalCapacity)
        self.trustedCapacity = max(normalCapacity, trustedCapacity, 1)
        director = CompanionExperienceDirector(attentionPolicy: attentionPolicy)
    }

    deinit {
        presentationTask?.cancel()
        replayTask?.cancel()
        handoffTask?.cancel()
    }

    func decide(
        for source: CompanionExperienceSource,
        context: CompanionExperienceContext
    ) -> CompanionExperienceDecision {
        director.decide(for: source, context: context)
    }

    /// Starts a bounded attention grace period after explicit local play. The
    /// director stores only the timestamp and attention class; no gesture,
    /// selected scene, task text or user-authored payload enters this runtime.
    func noteUserInitiated(at date: Date = Date()) {
        _ = director.decide(
            for: .userInitiated,
            context: CompanionExperienceContext(
                now: date,
                isDirectInteractionActive: false,
                isGameplayActive: false,
                isMediaPlaybackActive: false,
                isSpeaking: false,
                isQuietHours: false
            )
        )
    }

    @discardableResult
    func enqueue(
        event: Event,
        completionContext: CompanionCompletionContext?,
        source: CompanionExperienceSource
    ) -> CompanionExperienceEnqueueReceipt {
        let item = CompanionPendingExperience(
            event: event,
            completionContext: completionContext,
            source: source,
            coalescedCount: 1
        )
        let outcome: CompanionExperienceEnqueueOutcome

        if pending.count < normalCapacity {
            pending.append(item)
            outcome = .accepted
        } else if source == .trustedTaskTerminal {
            if let lowerPriority = pending.firstIndex(where: {
                $0.source != .trustedTaskTerminal
            }) {
                pending.remove(at: lowerPriority)
                pending.append(item)
                outcome = .replacedLowerPriority
            } else if pending.count < trustedCapacity {
                pending.append(item)
                outcome = .acceptedTrustedOverflow
            } else {
                let mergeIndex = pending.lastIndex(where: {
                    $0.source == .trustedTaskTerminal && $0.event == event
                }) ?? (pending.count - 1)
                let previous = pending[mergeIndex]
                pending[mergeIndex] = CompanionPendingExperience(
                    event: event,
                    completionContext: completionContext,
                    source: source,
                    coalescedCount: min(previous.coalescedCount + 1, Int.max)
                )
                outcome = .coalescedTrustedTerminal
            }
        } else {
            outcome = .rejectedCapacity
        }

        pendingCount = pending.count
        return CompanionExperienceEnqueueReceipt(
            outcome: outcome,
            pendingCount: pendingCount
        )
    }

    func dequeue() -> CompanionPendingExperience<Event>? {
        guard !pending.isEmpty else { return nil }
        let next = pending.removeFirst()
        pendingCount = pending.count
        return next
    }

    @discardableResult func discardPending(source: CompanionExperienceSource) -> Int {
        let previousCount = pending.count
        pending.removeAll { $0.source == source }
        pendingCount = pending.count
        return previousCount - pending.count
    }
    @discardableResult
    func beginPresentation() -> CompanionExperiencePresentationToken {
        presentationTask?.cancel()
        presentationTask = nil
        handoffTask?.cancel()
        handoffTask = nil
        generation &+= 1
        if generation == 0 {
            generation = 1
        }
        let token = CompanionExperiencePresentationToken(generation: generation)
        activeToken = token
        isPresentationActive = true
        return token
    }

    @discardableResult
    func scheduleFinish(
        for token: CompanionExperiencePresentationToken,
        after duration: TimeInterval,
        onFinish: @escaping @MainActor (
            CompanionExperiencePresentationToken
        ) -> Void
    ) -> Bool {
        guard activeToken == token else { return false }
        presentationTask?.cancel()
        let boundedDuration = duration.isFinite
            ? min(max(0, duration), 600)
            : 600
        presentationTask = Task { [weak self] in
            if boundedDuration > 0 {
                try? await Task.sleep(
                    nanoseconds: UInt64(boundedDuration * 1_000_000_000)
                )
            }
            guard !Task.isCancelled,
                  let self,
                  self.activeToken == token
            else { return }
            self.presentationTask = nil
            self.activeToken = nil
            self.isPresentationActive = false
            onFinish(token)
        }
        return true
    }

    func cancelPresentation() {
        presentationTask?.cancel()
        presentationTask = nil
        handoffTask?.cancel()
        handoffTask = nil
        activeToken = nil
        isPresentationActive = false
    }

    func completePresentation(
        token: CompanionExperiencePresentationToken? = nil
    ) -> Bool {
        if let token, activeToken != token {
            return false
        }
        let hadPresentation = activeToken != nil || presentationTask != nil
        cancelPresentation()
        return hadPresentation
    }

    func schedulePendingDelivery(
        after delay: TimeInterval,
        isReady: @escaping @MainActor () -> Bool,
        onReady: @escaping @MainActor (
            CompanionPendingExperience<Event>
        ) -> Void
    ) {
        guard replayTask == nil, !pending.isEmpty else { return }
        let boundedDelay = delay.isFinite
            ? min(max(0, delay), 60)
            : 60
        replayTask = Task { [weak self] in
            if boundedDelay > 0 {
                try? await Task.sleep(
                    nanoseconds: UInt64(boundedDelay * 1_000_000_000)
                )
            }
            guard !Task.isCancelled, let self else { return }
            self.replayTask = nil
            guard !self.isPresentationActive,
                  isReady(),
                  let next = self.dequeue()
            else { return }
            onReady(next)
        }
    }

    /// Schedules a local fallback handoff that is cancelled by any newer
    /// presentation. This prevents a stale failed clip from replacing a fresh
    /// user-initiated action during the short transition delay.
    func scheduleHandoff(
        after delay: TimeInterval,
        isValid: @escaping @MainActor () -> Bool,
        onReady: @escaping @MainActor () -> Void
    ) {
        handoffTask?.cancel()
        let boundedDelay = delay.isFinite
            ? min(max(0, delay), 5)
            : 5
        handoffTask = Task { [weak self] in
            if boundedDelay > 0 {
                try? await Task.sleep(
                    nanoseconds: UInt64(boundedDelay * 1_000_000_000)
                )
            }
            guard !Task.isCancelled,
                  let self,
                  !self.isPresentationActive,
                  isValid()
            else { return }
            self.handoffTask = nil
            onReady()
        }
    }
}
