import Foundation

public enum CompanionLifestyleMemoryValidationError: Error, Equatable, Sendable {
    case payloadTooLarge
    case unsupportedSchema
    case invalidDayIdentifier
    case invalidDate
    case invalidDailyCount
    case tooManyReminderKinds
}

extension CompanionLifestyleMemoryValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .payloadTooLarge:
            "The local care-rhythm memory exceeds the 64 KiB limit."
        case .unsupportedSchema:
            "The local care-rhythm memory schema is not supported."
        case .invalidDayIdentifier:
            "The local care-rhythm memory contains an invalid day identifier."
        case .invalidDate:
            "The local care-rhythm memory contains an invalid timestamp."
        case .invalidDailyCount:
            "The local care-rhythm memory contains an invalid daily count."
        case .tooManyReminderKinds:
            "The local care-rhythm memory contains unknown or excessive reminder state."
        }
    }
}

/// Where the current process recovered its privacy-minimal care rhythm.
///
/// The value is safe for diagnostics: it says nothing about reminder contents,
/// times, tasks, paths or user activity.
public enum CompanionLifestyleMemoryRecoverySource: String, Equatable, Sendable {
    case primary
    case backup
    case legacyProjection = "legacy-projection"
    case safeDefault = "safe-default"
}

public struct CompanionLifestyleMemoryLoadResult: Equatable, Sendable {
    public let state: CompanionLifestyleMemoryV1
    public let recoverySource: CompanionLifestyleMemoryRecoverySource

    public init(
        state: CompanionLifestyleMemoryV1,
        recoverySource: CompanionLifestyleMemoryRecoverySource
    ) {
        self.state = state
        self.recoverySource = recoverySource
    }
}

/// Restart-safe, privacy-minimal memory for proactive care scheduling.
///
/// This schema deliberately cannot store prompts, task titles, code, paths,
/// pointer coordinates or free-form user text. It remembers only bounded local
/// dates, reminder kinds and daily counts so hydration, movement, eye-rest and
/// encouragement do not reset or burst after every app restart.
public struct CompanionLifestyleMemoryV1: Codable, Equatable, Sendable {
    public static let schemaVersion = 1
    public static let maximumPayloadBytes = 64 * 1024
    public static let maximumDailyCount = 10_000
    public static let maximumPauseInterval: TimeInterval = 7 * 24 * 60 * 60

    public private(set) var schemaVersion: Int
    public private(set) var activityAnchor: Date
    public private(set) var lastReminder: CompanionLifestyleReminderOccurrence?
    public private(set) var lastReminderByKind: [CompanionLifestyleReminderKind: Date]
    public private(set) var dailyCounts: [CompanionLifestyleReminderKind: Int]
    public private(set) var dayIdentifier: String
    public private(set) var pausedUntil: Date?

    public init(
        schemaVersion: Int = CompanionLifestyleMemoryV1.schemaVersion,
        activityAnchor: Date = Date(),
        lastReminder: CompanionLifestyleReminderOccurrence? = nil,
        lastReminderByKind: [CompanionLifestyleReminderKind: Date] = [:],
        dailyCounts: [CompanionLifestyleReminderKind: Int] = [:],
        dayIdentifier: String = CompanionLifestyleMemoryV1.dayIdentifier(for: Date()),
        pausedUntil: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.activityAnchor = activityAnchor
        self.lastReminder = lastReminder
        self.lastReminderByKind = lastReminderByKind
        self.dailyCounts = dailyCounts
        self.dayIdentifier = dayIdentifier
        self.pausedUntil = pausedUntil
    }

    public static func dayIdentifier(
        for date: Date,
        calendar: Calendar = .current
    ) -> String {
        CompanionWorkdayStateV1.dayIdentifier(for: date, calendar: calendar)
    }

    /// Applies restart and wall-clock recovery bounds without inventing history.
    public mutating func normalize(
        at now: Date,
        calendar: Calendar = .current
    ) {
        let currentDay = Self.dayIdentifier(for: now, calendar: calendar)
        let earliestAnchor = now.addingTimeInterval(-18 * 60 * 60)
        if !Self.isFinite(activityAnchor)
            || activityAnchor > now
            || activityAnchor < earliestAnchor {
            activityAnchor = now
        }

        let earliestGlobalReminder = now.addingTimeInterval(-36 * 60 * 60)
        if let occurrence = lastReminder,
           !Self.isFinite(occurrence.date)
            || occurrence.date > now
            || occurrence.date < earliestGlobalReminder {
            lastReminder = nil
        }

        let earliestKindReminder = now.addingTimeInterval(-7 * 24 * 60 * 60)
        lastReminderByKind = lastReminderByKind.filter { _, date in
            Self.isFinite(date) && date <= now && date >= earliestKindReminder
        }
        if let occurrence = lastReminder {
            let existing = lastReminderByKind[occurrence.kind]
            if existing == nil || occurrence.date > existing! {
                lastReminderByKind[occurrence.kind] = occurrence.date
            }
        }

        if dayIdentifier != currentDay {
            dayIdentifier = currentDay
            dailyCounts = [:]
        } else {
            dailyCounts = dailyCounts.mapValues {
                min(max(0, $0), Self.maximumDailyCount)
            }
        }

        if let pausedUntil,
           !Self.isFinite(pausedUntil)
            || pausedUntil <= now
            || pausedUntil > now.addingTimeInterval(Self.maximumPauseInterval) {
            self.pausedUntil = nil
        }
    }

    @discardableResult
    public mutating func rollForward(
        at now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let before = self
        normalize(at: now, calendar: calendar)
        return self != before
    }

    public mutating func recordReminder(
        _ kind: CompanionLifestyleReminderKind,
        at date: Date,
        calendar: Calendar = .current
    ) {
        normalize(at: date, calendar: calendar)
        lastReminder = CompanionLifestyleReminderOccurrence(kind: kind, date: date)
        lastReminderByKind[kind] = date
        let current = min(
            Self.maximumDailyCount,
            max(0, dailyCounts[kind, default: 0])
        )
        dailyCounts[kind] = current == Self.maximumDailyCount
            ? current
            : current + 1
    }

    public mutating func setPausedUntil(_ date: Date?, at now: Date) {
        guard let date,
              Self.isFinite(date),
              date > now,
              date <= now.addingTimeInterval(Self.maximumPauseInterval) else {
            pausedUntil = nil
            return
        }
        pausedUntil = date
    }

    public func randomSeed() -> UInt64 {
        let digits = dayIdentifier.filter(\.isNumber)
        return max(1, UInt64(digits) ?? 1)
    }

    private static func isFinite(_ date: Date) -> Bool {
        date.timeIntervalSinceReferenceDate.isFinite
    }
}

public enum CompanionLifestyleMemoryCodec {
    public static func encode(_ state: CompanionLifestyleMemoryV1) throws -> Data {
        try validate(state)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        guard data.count <= CompanionLifestyleMemoryV1.maximumPayloadBytes else {
            throw CompanionLifestyleMemoryValidationError.payloadTooLarge
        }
        return data
    }

    public static func decode(_ data: Data) throws -> CompanionLifestyleMemoryV1 {
        guard data.count <= CompanionLifestyleMemoryV1.maximumPayloadBytes else {
            throw CompanionLifestyleMemoryValidationError.payloadTooLarge
        }
        let decoder = JSONDecoder()
        let probe = try decoder.decode(SchemaProbe.self, from: data)
        guard probe.schemaVersion == CompanionLifestyleMemoryV1.schemaVersion else {
            throw CompanionLifestyleMemoryValidationError.unsupportedSchema
        }
        let state = try decoder.decode(CompanionLifestyleMemoryV1.self, from: data)
        try validate(state)
        return state
    }

    public static func validate(_ state: CompanionLifestyleMemoryV1) throws {
        guard state.schemaVersion == CompanionLifestyleMemoryV1.schemaVersion else {
            throw CompanionLifestyleMemoryValidationError.unsupportedSchema
        }
        guard CompanionWorkdayStateV1.isValidDayIdentifier(state.dayIdentifier) else {
            throw CompanionLifestyleMemoryValidationError.invalidDayIdentifier
        }
        let allDates = [
            state.activityAnchor,
            state.lastReminder?.date,
            state.pausedUntil
        ].compactMap { $0 } + Array(state.lastReminderByKind.values)
        guard allDates.allSatisfy({ $0.timeIntervalSinceReferenceDate.isFinite }) else {
            throw CompanionLifestyleMemoryValidationError.invalidDate
        }
        let maximumKinds = CompanionLifestyleReminderKind.allCases.count
        guard state.lastReminderByKind.count <= maximumKinds,
              state.dailyCounts.count <= maximumKinds else {
            throw CompanionLifestyleMemoryValidationError.tooManyReminderKinds
        }
        guard state.dailyCounts.values.allSatisfy({
            (0...CompanionLifestyleMemoryV1.maximumDailyCount).contains($0)
        }) else {
            throw CompanionLifestyleMemoryValidationError.invalidDailyCount
        }
    }

    private struct SchemaProbe: Decodable {
        let schemaVersion: Int?
    }
}

/// UserDefaults persistence with one-level rollback and a compatible projection
/// to the pre-v1 individual keys. New builds get a single validated payload;
/// older local builds can still read the projected fields after a downgrade.
public final class CompanionLifestyleMemoryStore: @unchecked Sendable {
    public static let defaultStorageKey = "cc.chengyin.lifestyle-memory.v1"
    public static let defaultBackupKey = "cc.chengyin.lifestyle-memory.v1.backup"

    public enum LegacyKey {
        public static let activityAnchor = "chengyin.reminders.activity-anchor"
        public static let lastReminderAt = "chengyin.reminders.last-at"
        public static let lastReminderKind = "chengyin.reminders.last-kind"
        public static let lastReminderByKind = "chengyin.reminders.last-by-kind"
        public static let dailyCounts = "chengyin.reminders.daily-counts"
        public static let dailyDay = "chengyin.reminders.daily-day"
        public static let pausedUntil = "chengyin.reminders.paused-until"

        fileprivate static let all = [
            activityAnchor,
            lastReminderAt,
            lastReminderKind,
            lastReminderByKind,
            dailyCounts,
            dailyDay,
            pausedUntil
        ]
    }

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let backupKey: String
    private let lock = NSLock()
    private var cachedResult: CompanionLifestyleMemoryLoadResult?

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = CompanionLifestyleMemoryStore.defaultStorageKey,
        backupKey: String = CompanionLifestyleMemoryStore.defaultBackupKey
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.backupKey = backupKey
    }

    public func load(
        at now: Date = Date(),
        calendar: Calendar = .current
    ) -> CompanionLifestyleMemoryLoadResult {
        withLock {
            if var cachedResult {
                var state = cachedResult.state
                if state.rollForward(at: now, calendar: calendar) {
                    try? persistUnlocked(state, backupCurrentPrimary: false)
                }
                cachedResult = CompanionLifestyleMemoryLoadResult(
                    state: state,
                    recoverySource: cachedResult.recoverySource
                )
                self.cachedResult = cachedResult
                return cachedResult
            }

            let result = recoverUnlocked(at: now, calendar: calendar)
            cachedResult = result
            try? persistUnlocked(result.state, backupCurrentPrimary: false)
            return result
        }
    }

    @discardableResult
    public func save(
        _ state: CompanionLifestyleMemoryV1,
        at now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> CompanionLifestyleMemoryV1 {
        try withLock {
            var normalized = state
            normalized.normalize(at: now, calendar: calendar)
            try CompanionLifestyleMemoryCodec.validate(normalized)
            try persistUnlocked(normalized)
            cachedResult = CompanionLifestyleMemoryLoadResult(
                state: normalized,
                recoverySource: cachedResult?.recoverySource ?? .primary
            )
            return normalized
        }
    }

    @discardableResult
    public func update(
        at now: Date = Date(),
        calendar: Calendar = .current,
        _ transform: (inout CompanionLifestyleMemoryV1) throws -> Void
    ) throws -> CompanionLifestyleMemoryV1 {
        try withLock {
            let current = cachedResult
                ?? recoverUnlocked(at: now, calendar: calendar)
            var state = current.state
            try transform(&state)
            state.normalize(at: now, calendar: calendar)
            try CompanionLifestyleMemoryCodec.validate(state)
            try persistUnlocked(state)
            cachedResult = CompanionLifestyleMemoryLoadResult(
                state: state,
                recoverySource: current.recoverySource
            )
            return state
        }
    }

    /// Explicit deletion clears the rollback record before publishing the empty
    /// state, so later corruption cannot resurrect care timing the user erased.
    @discardableResult
    public func reset(
        at now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> CompanionLifestyleMemoryV1 {
        try withLock {
            var state = CompanionLifestyleMemoryV1(
                activityAnchor: now,
                dayIdentifier: CompanionLifestyleMemoryV1.dayIdentifier(
                    for: now,
                    calendar: calendar
                )
            )
            state.normalize(at: now, calendar: calendar)
            let encoded = try CompanionLifestyleMemoryCodec.encode(state)
            userDefaults.removeObject(forKey: backupKey)
            userDefaults.set(encoded, forKey: storageKey)
            writeLegacyProjectionUnlocked(state)
            cachedResult = CompanionLifestyleMemoryLoadResult(
                state: state,
                recoverySource: .primary
            )
            return state
        }
    }

    private func recoverUnlocked(
        at now: Date,
        calendar: Calendar
    ) -> CompanionLifestyleMemoryLoadResult {
        if let primary = decodedState(forKey: storageKey) {
            var state = primary
            state.normalize(at: now, calendar: calendar)
            return CompanionLifestyleMemoryLoadResult(
                state: state,
                recoverySource: .primary
            )
        }
        if let backup = decodedState(forKey: backupKey) {
            var state = backup
            state.normalize(at: now, calendar: calendar)
            return CompanionLifestyleMemoryLoadResult(
                state: state,
                recoverySource: .backup
            )
        }
        if let legacy = legacyState(at: now, calendar: calendar) {
            return CompanionLifestyleMemoryLoadResult(
                state: legacy,
                recoverySource: .legacyProjection
            )
        }
        return CompanionLifestyleMemoryLoadResult(
            state: CompanionLifestyleMemoryV1(
                activityAnchor: now,
                dayIdentifier: CompanionLifestyleMemoryV1.dayIdentifier(
                    for: now,
                    calendar: calendar
                )
            ),
            recoverySource: .safeDefault
        )
    }

    private func decodedState(forKey key: String) -> CompanionLifestyleMemoryV1? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? CompanionLifestyleMemoryCodec.decode(data)
    }

    private func legacyState(
        at now: Date,
        calendar: Calendar
    ) -> CompanionLifestyleMemoryV1? {
        guard LegacyKey.all.contains(where: {
            userDefaults.object(forKey: $0) != nil
        }) else {
            return nil
        }

        let storedAnchor = userDefaults.object(forKey: LegacyKey.activityAnchor) as? Date
        let anchor = storedAnchor ?? now
        let lastDate = userDefaults.object(forKey: LegacyKey.lastReminderAt) as? Date
        let lastKind = userDefaults.string(forKey: LegacyKey.lastReminderKind)
            .flatMap(CompanionLifestyleReminderKind.init(rawValue:))
        let occurrence = lastDate.flatMap { date in
            lastKind.map { CompanionLifestyleReminderOccurrence(kind: $0, date: date) }
        }
        let byKind = decodeLegacyDates(
            userDefaults.dictionary(forKey: LegacyKey.lastReminderByKind) ?? [:]
        )
        let counts = decodeLegacyCounts(
            userDefaults.dictionary(forKey: LegacyKey.dailyCounts) ?? [:]
        )
        let day = userDefaults.string(forKey: LegacyKey.dailyDay)
            ?? CompanionLifestyleMemoryV1.dayIdentifier(for: now, calendar: calendar)
        var state = CompanionLifestyleMemoryV1(
            activityAnchor: anchor,
            lastReminder: occurrence,
            lastReminderByKind: byKind,
            dailyCounts: counts,
            dayIdentifier: day,
            pausedUntil: userDefaults.object(forKey: LegacyKey.pausedUntil) as? Date
        )
        state.normalize(at: now, calendar: calendar)
        return state
    }

    private func decodeLegacyDates(
        _ values: [String: Any]
    ) -> [CompanionLifestyleReminderKind: Date] {
        Dictionary(uniqueKeysWithValues: values.compactMap { rawKind, value in
            guard let kind = CompanionLifestyleReminderKind(rawValue: rawKind),
                  let seconds = (value as? NSNumber)?.doubleValue,
                  seconds.isFinite else {
                return nil
            }
            return (kind, Date(timeIntervalSince1970: seconds))
        })
    }

    private func decodeLegacyCounts(
        _ values: [String: Any]
    ) -> [CompanionLifestyleReminderKind: Int] {
        Dictionary(uniqueKeysWithValues: values.compactMap { rawKind, value in
            guard let kind = CompanionLifestyleReminderKind(rawValue: rawKind),
                  let count = (value as? NSNumber)?.intValue else {
                return nil
            }
            return (
                kind,
                min(max(0, count), CompanionLifestyleMemoryV1.maximumDailyCount)
            )
        })
    }

    private func persistUnlocked(
        _ state: CompanionLifestyleMemoryV1,
        backupCurrentPrimary: Bool = true
    ) throws {
        let encoded = try CompanionLifestyleMemoryCodec.encode(state)
        if backupCurrentPrimary,
           let current = userDefaults.data(forKey: storageKey),
           (try? CompanionLifestyleMemoryCodec.decode(current)) != nil,
           current != encoded {
            userDefaults.set(current, forKey: backupKey)
        }
        userDefaults.set(encoded, forKey: storageKey)
        writeLegacyProjectionUnlocked(state)
    }

    private func writeLegacyProjectionUnlocked(_ state: CompanionLifestyleMemoryV1) {
        LegacyKey.all.forEach(userDefaults.removeObject(forKey:))
        userDefaults.set(state.activityAnchor, forKey: LegacyKey.activityAnchor)
        if let occurrence = state.lastReminder {
            userDefaults.set(occurrence.date, forKey: LegacyKey.lastReminderAt)
            userDefaults.set(occurrence.kind.rawValue, forKey: LegacyKey.lastReminderKind)
        }
        userDefaults.set(
            Dictionary(uniqueKeysWithValues: state.lastReminderByKind.map {
                ($0.key.rawValue, $0.value.timeIntervalSince1970)
            }),
            forKey: LegacyKey.lastReminderByKind
        )
        userDefaults.set(
            Dictionary(uniqueKeysWithValues: state.dailyCounts.map {
                ($0.key.rawValue, $0.value)
            }),
            forKey: LegacyKey.dailyCounts
        )
        userDefaults.set(state.dayIdentifier, forKey: LegacyKey.dailyDay)
        if let pausedUntil = state.pausedUntil {
            userDefaults.set(pausedUntil, forKey: LegacyKey.pausedUntil)
        }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}
