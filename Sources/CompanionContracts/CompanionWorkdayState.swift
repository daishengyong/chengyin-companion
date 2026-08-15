import Foundation

public enum CompanionWorkdayStateValidationError: Error, Equatable, Sendable {
    case unsupportedSchema
    case payloadTooLarge
    case invalidDayIdentifier
    case invalidEventDate
}

public enum CompanionWorkdayStateRecoverySource: String, Codable, Equatable, Sendable {
    case primary
    case backup
    case safeDefault
}

public struct CompanionWorkdayStateLoadResult: Equatable, Sendable {
    public let state: CompanionWorkdayStateV1
    public let recoverySource: CompanionWorkdayStateRecoverySource

    public init(
        state: CompanionWorkdayStateV1,
        recoverySource: CompanionWorkdayStateRecoverySource
    ) {
        self.state = state
        self.recoverySource = recoverySource
    }
}

extension CompanionWorkdayStateValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema:
            "Unsupported companion workday state schema."
        case .payloadTooLarge:
            "Companion workday state exceeds the local payload limit."
        case .invalidDayIdentifier:
            "Companion workday state contains an invalid local day identifier."
        case .invalidEventDate:
            "Companion workday state contains an invalid event date."
        }
    }
}

/// A privacy-minimal record of one local workday.
///
/// The schema deliberately has no fields for task titles, prompts, code, repositories,
/// paths or user-authored text. It only retains counters, bounded durations and the
/// timestamp of the latest lifecycle event so the companion can preserve continuity
/// across app restarts without learning the contents of the user's work.
public struct CompanionWorkdayStateV1: Codable, Equatable, Sendable {
    public static let schemaVersion = 1
    public static let maximumPayloadBytes = 64 * 1024

    public private(set) var schemaVersion: Int
    public private(set) var dayIdentifier: String
    public private(set) var startedCount: UInt64
    public private(set) var responseReadyCount: UInt64
    public private(set) var completedCount: UInt64
    public private(set) var failedCount: UInt64
    public private(set) var cancelledCount: UInt64
    public private(set) var recoveredCompletionCount: UInt64
    public private(set) var longFocusCompletionCount: UInt64
    public private(set) var focusedDurationSeconds: UInt64
    public private(set) var lastEventAt: Date?
    public private(set) var lastFailureAt: Date?

    public init(
        schemaVersion: Int = CompanionWorkdayStateV1.schemaVersion,
        dayIdentifier: String = CompanionWorkdayStateV1.dayIdentifier(for: Date()),
        startedCount: UInt64 = 0,
        responseReadyCount: UInt64 = 0,
        completedCount: UInt64 = 0,
        failedCount: UInt64 = 0,
        cancelledCount: UInt64 = 0,
        recoveredCompletionCount: UInt64 = 0,
        longFocusCompletionCount: UInt64 = 0,
        focusedDurationSeconds: UInt64 = 0,
        lastEventAt: Date? = nil,
        lastFailureAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.dayIdentifier = dayIdentifier
        self.startedCount = startedCount
        self.responseReadyCount = responseReadyCount
        self.completedCount = completedCount
        self.failedCount = failedCount
        self.cancelledCount = cancelledCount
        self.recoveredCompletionCount = recoveredCompletionCount
        self.longFocusCompletionCount = longFocusCompletionCount
        self.focusedDurationSeconds = focusedDurationSeconds
        self.lastEventAt = lastEventAt
        self.lastFailureAt = lastFailureAt
    }

    public static func dayIdentifier(
        for date: Date,
        calendar: Calendar = .current
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    public mutating func rollForward(to newDayIdentifier: String) {
        guard newDayIdentifier != dayIdentifier else { return }
        self = CompanionWorkdayStateV1(dayIdentifier: newDayIdentifier)
    }

    public mutating func recordStarted(at date: Date) {
        startedCount = Self.addingOne(startedCount)
        recordEvent(at: date)
    }

    public mutating func recordResponseReady(at date: Date) {
        responseReadyCount = Self.addingOne(responseReadyCount)
        recordEvent(at: date)
    }

    public mutating func recordCompletion(
        duration: TimeInterval,
        recoveredAfterFailure: Bool,
        at date: Date
    ) {
        completedCount = Self.addingOne(completedCount)
        if recoveredAfterFailure {
            recoveredCompletionCount = Self.addingOne(recoveredCompletionCount)
            lastFailureAt = nil
        }
        if duration.isFinite, duration >= 10 * 60 {
            longFocusCompletionCount = Self.addingOne(longFocusCompletionCount)
        }
        addFocusedDuration(duration)
        recordEvent(at: date)
    }

    public mutating func recordFailure(duration: TimeInterval, at date: Date) {
        failedCount = Self.addingOne(failedCount)
        lastFailureAt = date
        addFocusedDuration(duration)
        recordEvent(at: date)
    }

    public mutating func recordCancellation(duration: TimeInterval, at date: Date) {
        cancelledCount = Self.addingOne(cancelledCount)
        addFocusedDuration(duration)
        recordEvent(at: date)
    }

    public mutating func clearFailureMemory() {
        lastFailureAt = nil
    }

    public mutating func preserveMonotonicProgress(
        from previous: CompanionWorkdayStateV1
    ) {
        guard dayIdentifier == previous.dayIdentifier else { return }
        startedCount = max(startedCount, previous.startedCount)
        responseReadyCount = max(responseReadyCount, previous.responseReadyCount)
        completedCount = max(completedCount, previous.completedCount)
        failedCount = max(failedCount, previous.failedCount)
        cancelledCount = max(cancelledCount, previous.cancelledCount)
        recoveredCompletionCount = max(
            recoveredCompletionCount,
            previous.recoveredCompletionCount
        )
        longFocusCompletionCount = max(
            longFocusCompletionCount,
            previous.longFocusCompletionCount
        )
        focusedDurationSeconds = max(
            focusedDurationSeconds,
            previous.focusedDurationSeconds
        )
        if let previousDate = previous.lastEventAt,
           lastEventAt == nil || previousDate > lastEventAt! {
            lastEventAt = previousDate
        }
    }

    public static func isValidDayIdentifier(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard bytes.count == 10, bytes[4] == 45, bytes[7] == 45 else {
            return false
        }
        return bytes.enumerated().allSatisfy { index, byte in
            index == 4 || index == 7 || (48...57).contains(byte)
        }
    }

    private mutating func addFocusedDuration(_ duration: TimeInterval) {
        guard duration.isFinite, duration > 0 else { return }
        let bounded = min(duration.rounded(), TimeInterval(UInt64.max))
        let seconds = UInt64(max(0, bounded))
        if UInt64.max - focusedDurationSeconds < seconds {
            focusedDurationSeconds = UInt64.max
        } else {
            focusedDurationSeconds += seconds
        }
    }

    private mutating func recordEvent(at date: Date) {
        guard date.timeIntervalSinceReferenceDate.isFinite else { return }
        if lastEventAt == nil || date > lastEventAt! {
            lastEventAt = date
        }
    }

    private static func addingOne(_ value: UInt64) -> UInt64 {
        value == UInt64.max ? UInt64.max : value + 1
    }
}

public enum CompanionWorkdayStateCodec {
    public static func encode(_ state: CompanionWorkdayStateV1) throws -> Data {
        try validate(state)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        guard data.count <= CompanionWorkdayStateV1.maximumPayloadBytes else {
            throw CompanionWorkdayStateValidationError.payloadTooLarge
        }
        return data
    }

    public static func decode(_ data: Data) throws -> CompanionWorkdayStateV1 {
        guard data.count <= CompanionWorkdayStateV1.maximumPayloadBytes else {
            throw CompanionWorkdayStateValidationError.payloadTooLarge
        }
        let decoder = JSONDecoder()
        let probe = try decoder.decode(SchemaProbe.self, from: data)
        guard probe.schemaVersion == CompanionWorkdayStateV1.schemaVersion else {
            throw CompanionWorkdayStateValidationError.unsupportedSchema
        }
        let state = try decoder.decode(CompanionWorkdayStateV1.self, from: data)
        try validate(state)
        return state
    }

    public static func validate(_ state: CompanionWorkdayStateV1) throws {
        guard state.schemaVersion == CompanionWorkdayStateV1.schemaVersion else {
            throw CompanionWorkdayStateValidationError.unsupportedSchema
        }
        guard CompanionWorkdayStateV1.isValidDayIdentifier(state.dayIdentifier) else {
            throw CompanionWorkdayStateValidationError.invalidDayIdentifier
        }
        for date in [state.lastEventAt, state.lastFailureAt].compactMap({ $0 }) {
            guard date.timeIntervalSinceReferenceDate.isFinite else {
                throw CompanionWorkdayStateValidationError.invalidEventDate
            }
        }
    }

    private struct SchemaProbe: Decodable {
        let schemaVersion: Int?
    }
}

/// UserDefaults persistence with one-level rollback. It never stores task refs or
/// user-authored text, and rolls into a clean record when the injected local day changes.
public final class CompanionWorkdayStateStore: @unchecked Sendable {
    public static let defaultStorageKey = "cc.chengyin.workday-state"
    public static let defaultBackupKey = "cc.chengyin.workday-state.backup"

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let backupKey: String
    private let lock = NSLock()
    private var cachedState: CompanionWorkdayStateV1?

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = CompanionWorkdayStateStore.defaultStorageKey,
        backupKey: String = CompanionWorkdayStateStore.defaultBackupKey
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.backupKey = backupKey
    }

    public func load(dayIdentifier: String) -> CompanionWorkdayStateV1 {
        loadWithRecovery(dayIdentifier: dayIdentifier).state
    }

    public func loadWithRecovery(
        dayIdentifier: String
    ) -> CompanionWorkdayStateLoadResult {
        withLock {
            let recovered = cachedState.map {
                CompanionWorkdayStateLoadResult(
                    state: $0,
                    recoverySource: .primary
                )
            } ?? recoverUnlocked(dayIdentifier: dayIdentifier)
            var state = recovered.state
            state.rollForward(to: dayIdentifier)
            cachedState = state
            if let encoded = try? CompanionWorkdayStateCodec.encode(state) {
                userDefaults.set(encoded, forKey: storageKey)
            }
            return CompanionWorkdayStateLoadResult(
                state: state,
                recoverySource: recovered.recoverySource
            )
        }
    }

    public func save(_ newState: CompanionWorkdayStateV1) throws {
        try withLock {
            var state = newState
            let previous = cachedState ?? recoverUnlocked(
                dayIdentifier: newState.dayIdentifier
            ).state
            state.preserveMonotonicProgress(from: previous)
            try CompanionWorkdayStateCodec.validate(state)
            try persistUnlocked(state)
            cachedState = state
        }
    }

    /// Explicit user-controlled forgetting. Both the primary and rollback snapshot
    /// are replaced so a later recovery cannot resurrect a record the user deleted.
    @discardableResult
    public func reset(dayIdentifier: String) throws -> CompanionWorkdayStateV1 {
        try withLock {
            let state = CompanionWorkdayStateV1(dayIdentifier: dayIdentifier)
            let encoded = try CompanionWorkdayStateCodec.encode(state)
            userDefaults.removeObject(forKey: backupKey)
            userDefaults.set(encoded, forKey: storageKey)
            cachedState = state
            return state
        }
    }

    private func recoverUnlocked(
        dayIdentifier: String
    ) -> CompanionWorkdayStateLoadResult {
        if let primary = userDefaults.data(forKey: storageKey),
           var state = try? CompanionWorkdayStateCodec.decode(primary) {
            state.rollForward(to: dayIdentifier)
            return CompanionWorkdayStateLoadResult(
                state: state,
                recoverySource: .primary
            )
        }
        if let backup = userDefaults.data(forKey: backupKey),
           var state = try? CompanionWorkdayStateCodec.decode(backup) {
            state.rollForward(to: dayIdentifier)
            if let encoded = try? CompanionWorkdayStateCodec.encode(state) {
                userDefaults.set(encoded, forKey: storageKey)
            }
            return CompanionWorkdayStateLoadResult(
                state: state,
                recoverySource: .backup
            )
        }
        return CompanionWorkdayStateLoadResult(
            state: CompanionWorkdayStateV1(dayIdentifier: dayIdentifier),
            recoverySource: .safeDefault
        )
    }

    private func persistUnlocked(_ state: CompanionWorkdayStateV1) throws {
        let encoded = try CompanionWorkdayStateCodec.encode(state)
        if let current = userDefaults.data(forKey: storageKey),
           (try? CompanionWorkdayStateCodec.decode(current)) != nil {
            userDefaults.set(current, forKey: backupKey)
        }
        userDefaults.set(encoded, forKey: storageKey)
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}
