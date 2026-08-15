import Foundation

public extension CompanionRelationshipTone {
    /// The highest session-only chemistry level permitted by the user's chosen tone.
    ///
    /// Chemistry is an interaction intensity, not affection. Permanent progress never
    /// depends on choosing a more romantic tone.
    var chemistryLevelCap: Int {
        switch self {
        case .calmPeer:
            1
        case .warmSupport:
            2
        case .playfulSpark, .romanceLite:
            3
        }
    }
}

public enum CompanionRelationshipStateValidationError: Error, Equatable, Sendable {
    case payloadTooLarge
    case unsupportedSchema
    case invalidChemistryLevel
    case invalidSurpriseProgress
    case tooManyMementos
    case tooManyRecentAssets
    case tooManyPlaybackRecords
    case invalidPersistentIdentifier
    case duplicatePersistentIdentifier
    case invalidPlaybackDate
}

/// Explicit user-facing deletion scopes. These are controls over local memory,
/// not relationship levels: clearing one scope never penalizes another.
public enum CompanionRelationshipMemoryScope: String, CaseIterable, Sendable {
    case sharedProgress
    case sessionChemistry
    case surpriseProgress
    case mementos
    case playbackHistory
}

extension CompanionRelationshipStateValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .payloadTooLarge:
            "The relationship state exceeds the 256 KiB limit."
        case .unsupportedSchema:
            "The relationship state schema is not supported."
        case .invalidChemistryLevel:
            "The session chemistry level is outside the selected tone cap."
        case .invalidSurpriseProgress:
            "The surprise progress is outside the supported range."
        case .tooManyMementos:
            "The relationship state contains too many mementos."
        case .tooManyRecentAssets:
            "The relationship state contains too many recent assets."
        case .tooManyPlaybackRecords:
            "The relationship state contains too many playback records."
        case .invalidPersistentIdentifier:
            "Relationship state identifiers must be opaque, bounded identifiers, not text or paths."
        case .duplicatePersistentIdentifier:
            "The relationship state contains duplicate identifiers."
        case .invalidPlaybackDate:
            "The relationship state contains an invalid playback date."
        }
    }
}

public struct CompanionRelationshipStateV1: Codable, Equatable, Sendable {
    public static let schemaVersion = 1
    public static let maximumChemistryLevel = 3
    public static let surpriseGuaranteeThreshold = 8
    public static let maximumMementoCount = 512
    public static let maximumRecentAssetCount = 12
    public static let maximumPlaybackRecordCount = 64
    public static let maximumIdentifierLength = 96

    public private(set) var schemaVersion: Int
    public private(set) var bondMoments: UInt64
    public private(set) var chemistryLevel: Int
    public private(set) var toneCap: CompanionRelationshipTone
    public private(set) var surpriseProgress: Int
    public private(set) var unlockedMementoIDs: [String]
    public private(set) var recentAssetIDs: [String]
    public private(set) var lastPlayedAtByAssetID: [String: Date]

    public init(
        schemaVersion: Int = CompanionRelationshipStateV1.schemaVersion,
        bondMoments: UInt64 = 0,
        chemistryLevel: Int = 0,
        toneCap: CompanionRelationshipTone = .warmSupport,
        surpriseProgress: Int = 0,
        unlockedMementoIDs: [String] = [],
        recentAssetIDs: [String] = [],
        lastPlayedAtByAssetID: [String: Date] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.bondMoments = bondMoments
        self.chemistryLevel = min(
            max(0, chemistryLevel),
            min(Self.maximumChemistryLevel, toneCap.chemistryLevelCap)
        )
        self.toneCap = toneCap
        self.surpriseProgress = min(
            max(0, surpriseProgress),
            Self.surpriseGuaranteeThreshold
        )
        self.unlockedMementoIDs = Self.normalizedIdentifiers(
            unlockedMementoIDs,
            limit: Self.maximumMementoCount
        )
        self.recentAssetIDs = Self.normalizedIdentifiers(
            recentAssetIDs,
            limit: Self.maximumRecentAssetCount
        )
        self.lastPlayedAtByAssetID = Self.normalizedPlaybackHistory(
            lastPlayedAtByAssetID,
            limit: Self.maximumPlaybackRecordCount
        )
    }

    /// Adds permanent progress. There is deliberately no decrement API.
    public mutating func recordPositiveMoment(_ amount: UInt64 = 1) {
        guard amount > 0 else {
            return
        }
        if UInt64.max - bondMoments < amount {
            bondMoments = UInt64.max
        } else {
            bondMoments += amount
        }
    }

    /// Raises session-only chemistry without exceeding 0...3 or the user's tone cap.
    @discardableResult
    public mutating func increaseChemistry(by amount: Int = 1) -> Int {
        guard amount > 0 else {
            return chemistryLevel
        }
        let raisedLevel: Int
        if Int.max - chemistryLevel < amount {
            raisedLevel = Int.max
        } else {
            raisedLevel = chemistryLevel + amount
        }
        chemistryLevel = min(
            raisedLevel,
            min(Self.maximumChemistryLevel, toneCap.chemistryLevelCap)
        )
        return chemistryLevel
    }

    public mutating func resetSessionChemistry() {
        chemistryLevel = 0
    }

    public mutating func setToneCap(_ tone: CompanionRelationshipTone) {
        toneCap = tone
        chemistryLevel = min(
            chemistryLevel,
            min(Self.maximumChemistryLevel, tone.chemistryLevelCap)
        )
    }

    /// Advances a deterministic, non-paid surprise guarantee.
    ///
    /// The caller explicitly consumes the progress only after a surprise is actually
    /// delivered, so media failures cannot silently lose progress.
    @discardableResult
    public mutating func advanceSurprise(by amount: Int = 1) -> Bool {
        guard amount > 0 else {
            return isSurpriseGuaranteed
        }
        let raisedProgress: Int
        if Int.max - surpriseProgress < amount {
            raisedProgress = Int.max
        } else {
            raisedProgress = surpriseProgress + amount
        }
        surpriseProgress = min(
            Self.surpriseGuaranteeThreshold,
            raisedProgress
        )
        return isSurpriseGuaranteed
    }

    public var isSurpriseGuaranteed: Bool {
        surpriseProgress >= Self.surpriseGuaranteeThreshold
    }

    public mutating func consumeDeliveredSurprise() {
        surpriseProgress = 0
    }

    /// Unlocks an opaque content identifier. Arbitrary copy, code and paths are rejected.
    @discardableResult
    public mutating func unlockMemento(_ id: String) throws -> Bool {
        guard Self.isValidPersistentIdentifier(id) else {
            throw CompanionRelationshipStateValidationError.invalidPersistentIdentifier
        }
        guard !unlockedMementoIDs.contains(id) else {
            return false
        }
        guard unlockedMementoIDs.count < Self.maximumMementoCount else {
            throw CompanionRelationshipStateValidationError.tooManyMementos
        }
        unlockedMementoIDs.append(id)
        return true
    }

    /// Records the most recently played opaque asset and its timestamp.
    ///
    /// The short anti-repeat list and the longer cooldown history are bounded
    /// independently. Both survive restarts; session chemistry does not.
    public mutating func rememberAsset(
        _ id: String,
        at date: Date = Date(),
        recentLimit: Int = CompanionRelationshipStateV1.maximumRecentAssetCount,
        historyLimit: Int = CompanionRelationshipStateV1.maximumPlaybackRecordCount
    ) throws {
        guard Self.isValidPersistentIdentifier(id) else {
            throw CompanionRelationshipStateValidationError.invalidPersistentIdentifier
        }
        guard date.timeIntervalSinceReferenceDate.isFinite else {
            throw CompanionRelationshipStateValidationError.invalidPlaybackDate
        }

        let safeRecentLimit = min(max(1, recentLimit), Self.maximumRecentAssetCount)
        let safeHistoryLimit = min(max(1, historyLimit), Self.maximumPlaybackRecordCount)

        recentAssetIDs.removeAll { $0 == id }
        recentAssetIDs.insert(id, at: 0)
        if recentAssetIDs.count > safeRecentLimit {
            recentAssetIDs.removeLast(recentAssetIDs.count - safeRecentLimit)
        }

        lastPlayedAtByAssetID[id] = date
        lastPlayedAtByAssetID = Self.normalizedPlaybackHistory(
            lastPlayedAtByAssetID,
            limit: safeHistoryLimit
        )
    }

    public func lastPlayedAt(forAssetID id: String) -> Date? {
        lastPlayedAtByAssetID[id]
    }

    public static func isValidPersistentIdentifier(_ value: String) -> Bool {
        guard
            !value.isEmpty,
            value.utf8.count <= maximumIdentifierLength,
            let first = value.unicodeScalars.first,
            isASCIIAlphaNumeric(first)
        else {
            return false
        }

        return value.unicodeScalars.allSatisfy { scalar in
            isASCIIAlphaNumeric(scalar)
                || scalar == "."
                || scalar == "-"
                || scalar == "_"
                || scalar == "@"
                || scalar == ":"
        }
    }

    fileprivate mutating func preservePositiveProgress(
        from previous: CompanionRelationshipStateV1
    ) {
        bondMoments = max(bondMoments, previous.bondMoments)
        for id in previous.unlockedMementoIDs where !unlockedMementoIDs.contains(id) {
            if unlockedMementoIDs.count < Self.maximumMementoCount {
                unlockedMementoIDs.append(id)
            }
        }
    }

    fileprivate static func migrated(
        bondMoments: UInt64,
        chemistryLevel: Int,
        toneCap: CompanionRelationshipTone,
        surpriseProgress: Int,
        unlockedMementoIDs: [String],
        recentAssetIDs: [String],
        lastPlayedAtByAssetID: [String: Date]
    ) -> CompanionRelationshipStateV1 {
        CompanionRelationshipStateV1(
            bondMoments: bondMoments,
            chemistryLevel: chemistryLevel,
            toneCap: toneCap,
            surpriseProgress: surpriseProgress,
            unlockedMementoIDs: unlockedMementoIDs,
            recentAssetIDs: recentAssetIDs,
            lastPlayedAtByAssetID: lastPlayedAtByAssetID
        )
    }

    private static func normalizedIdentifiers(_ values: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            guard
                seen.insert(value).inserted,
                isValidPersistentIdentifier(value)
            else {
                return nil
            }
            return value
        }
        .prefix(limit)
        .map { $0 }
    }

    private static func normalizedPlaybackHistory(
        _ values: [String: Date],
        limit: Int
    ) -> [String: Date] {
        let sorted = values
            .filter {
                isValidPersistentIdentifier($0.key)
                    && $0.value.timeIntervalSinceReferenceDate.isFinite
            }
            .sorted {
                if $0.value == $1.value {
                    return $0.key < $1.key
                }
                return $0.value > $1.value
            }
            .prefix(limit)
            .map { ($0.key, $0.value) }
        return Dictionary(uniqueKeysWithValues: sorted)
    }

    private static func isASCIIAlphaNumeric(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 48...57, 65...90, 97...122:
            true
        default:
            false
        }
    }
}

public enum CompanionRelationshipStateCodec {
    public static let maximumPayloadBytes = 256 * 1024

    public static func encode(_ state: CompanionRelationshipStateV1) throws -> Data {
        try validate(state)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        guard data.count <= maximumPayloadBytes else {
            throw CompanionRelationshipStateValidationError.payloadTooLarge
        }
        return data
    }

    public static func decode(_ data: Data) throws -> CompanionRelationshipStateV1 {
        guard data.count <= maximumPayloadBytes else {
            throw CompanionRelationshipStateValidationError.payloadTooLarge
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let probe = try decoder.decode(SchemaProbe.self, from: data)

        let state: CompanionRelationshipStateV1
        switch probe.schemaVersion ?? 0 {
        case 0:
            state = try migrateV0(decoder.decode(LegacyStateV0.self, from: data))
        case CompanionRelationshipStateV1.schemaVersion:
            state = try decoder.decode(CompanionRelationshipStateV1.self, from: data)
        default:
            throw CompanionRelationshipStateValidationError.unsupportedSchema
        }

        try validate(state)
        return state
    }

    public static func validate(_ state: CompanionRelationshipStateV1) throws {
        guard state.schemaVersion == CompanionRelationshipStateV1.schemaVersion else {
            throw CompanionRelationshipStateValidationError.unsupportedSchema
        }
        guard
            (0...CompanionRelationshipStateV1.maximumChemistryLevel).contains(state.chemistryLevel),
            state.chemistryLevel <= state.toneCap.chemistryLevelCap
        else {
            throw CompanionRelationshipStateValidationError.invalidChemistryLevel
        }
        guard
            (0...CompanionRelationshipStateV1.surpriseGuaranteeThreshold)
                .contains(state.surpriseProgress)
        else {
            throw CompanionRelationshipStateValidationError.invalidSurpriseProgress
        }
        guard state.unlockedMementoIDs.count <= CompanionRelationshipStateV1.maximumMementoCount else {
            throw CompanionRelationshipStateValidationError.tooManyMementos
        }
        guard state.recentAssetIDs.count <= CompanionRelationshipStateV1.maximumRecentAssetCount else {
            throw CompanionRelationshipStateValidationError.tooManyRecentAssets
        }
        guard
            state.lastPlayedAtByAssetID.count
                <= CompanionRelationshipStateV1.maximumPlaybackRecordCount
        else {
            throw CompanionRelationshipStateValidationError.tooManyPlaybackRecords
        }

        try validateIdentifiers(state.unlockedMementoIDs)
        try validateIdentifiers(state.recentAssetIDs)
        try validateIdentifiers(Array(state.lastPlayedAtByAssetID.keys))
        guard state.lastPlayedAtByAssetID.values.allSatisfy({
            $0.timeIntervalSinceReferenceDate.isFinite
        }) else {
            throw CompanionRelationshipStateValidationError.invalidPlaybackDate
        }
    }

    private static func validateIdentifiers(_ values: [String]) throws {
        guard values.allSatisfy(CompanionRelationshipStateV1.isValidPersistentIdentifier) else {
            throw CompanionRelationshipStateValidationError.invalidPersistentIdentifier
        }
        guard Set(values).count == values.count else {
            throw CompanionRelationshipStateValidationError.duplicatePersistentIdentifier
        }
    }

    private static func migrateV0(_ legacy: LegacyStateV0) throws
        -> CompanionRelationshipStateV1
    {
        CompanionRelationshipStateV1.migrated(
            bondMoments: legacy.bondMoments ?? legacy.moments ?? 0,
            chemistryLevel: legacy.chemistryLevel ?? legacy.chemistry ?? 0,
            toneCap: legacy.toneCap ?? legacy.relationshipTone ?? legacy.tone ?? .warmSupport,
            surpriseProgress: legacy.surpriseProgress ?? 0,
            unlockedMementoIDs: legacy.unlockedMementoIDs ?? legacy.mementos ?? [],
            recentAssetIDs: legacy.recentAssetIDs ?? legacy.recentAssets ?? [],
            lastPlayedAtByAssetID: legacy.lastPlayedAtByAssetID ?? [:]
        )
    }

    private struct SchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private struct LegacyStateV0: Decodable {
        let bondMoments: UInt64?
        let moments: UInt64?
        let chemistryLevel: Int?
        let chemistry: Int?
        let toneCap: CompanionRelationshipTone?
        let relationshipTone: CompanionRelationshipTone?
        let tone: CompanionRelationshipTone?
        let surpriseProgress: Int?
        let unlockedMementoIDs: [String]?
        let mementos: [String]?
        let recentAssetIDs: [String]?
        let recentAssets: [String]?
        let lastPlayedAtByAssetID: [String: Date]?
    }
}

/// UserDefaults-backed persistence with bounded state, one-level rollback and
/// session-only chemistry.
///
/// Only opaque content identifiers, counters, tone and playback timestamps are
/// represented by the schema. Prompts, code, paths and task titles have nowhere to
/// enter the persisted payload.
public final class CompanionRelationshipStateStore: @unchecked Sendable {
    public static let defaultStorageKey = "cc.chengyin.relationship-state"
    public static let defaultBackupKey = "cc.chengyin.relationship-state.backup"

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let backupKey: String
    private let lock = NSLock()
    private var cachedState: CompanionRelationshipStateV1?

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = CompanionRelationshipStateStore.defaultStorageKey,
        backupKey: String = CompanionRelationshipStateStore.defaultBackupKey
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.backupKey = backupKey
    }

    /// Loads current state, then the last valid backup, then a safe default.
    ///
    /// Chemistry is reset exactly once for each store instance, making it a session
    /// value while every other field remains restart-safe.
    public func load() -> CompanionRelationshipStateV1 {
        withLock {
            loadUnlocked()
        }
    }

    /// Saves state while preserving permanent positive progress already on disk.
    public func save(_ newState: CompanionRelationshipStateV1) throws {
        try withLock {
            var state = newState
            let previous = cachedState ?? recoverUnlocked()
            state.preservePositiveProgress(from: previous)
            try CompanionRelationshipStateCodec.validate(state)
            cachedState = state
            try persistUnlocked(state)
        }
    }

    @discardableResult
    public func update(
        _ transform: (inout CompanionRelationshipStateV1) throws -> Void
    ) throws -> CompanionRelationshipStateV1 {
        try withLock {
            var state = loadUnlocked()
            let previous = state
            try transform(&state)
            state.preservePositiveProgress(from: previous)
            try CompanionRelationshipStateCodec.validate(state)
            cachedState = state
            try persistUnlocked(state)
            return state
        }
    }

    @discardableResult
    public func resetSessionChemistry() throws -> CompanionRelationshipStateV1 {
        try update { state in
            state.resetSessionChemistry()
        }
    }

    /// Permanently removes relationship memory while preserving the user's tone
    /// preference. This is intentionally separate from `save` and `update`, whose
    /// positive-only merge rules prevent accidental progress loss.
    ///
    /// The rollback snapshot is deleted before the empty canonical payload is
    /// installed, so a later primary-file corruption cannot resurrect memory that
    /// the user explicitly chose to forget.
    @discardableResult
    public func forgetAllMemory(
        preservingTone: Bool = true
    ) throws -> CompanionRelationshipStateV1 {
        try withLock {
            let previous = cachedState ?? recoverUnlocked()
            let reset = CompanionRelationshipStateV1(
                toneCap: preservingTone ? previous.toneCap : .warmSupport
            )
            let encoded = try CompanionRelationshipStateCodec.encode(reset)
            userDefaults.removeObject(forKey: backupKey)
            userDefaults.set(encoded, forKey: storageKey)
            cachedState = reset
            return reset
        }
    }

    /// Permanently removes only the selected local-memory fields.
    ///
    /// This deliberately bypasses positive-only saves and clears the rollback
    /// snapshot before installing the replacement, so explicit deletion cannot
    /// be undone by later primary-record corruption.
    @discardableResult
    public func forgetMemory(
        _ scopes: Set<CompanionRelationshipMemoryScope>
    ) throws -> CompanionRelationshipStateV1 {
        try withLock {
            let previous = cachedState ?? recoverUnlocked()
            guard !scopes.isEmpty else { return previous }
            let replacement = CompanionRelationshipStateV1(
                bondMoments: scopes.contains(.sharedProgress)
                    ? 0
                    : previous.bondMoments,
                chemistryLevel: scopes.contains(.sessionChemistry)
                    ? 0
                    : previous.chemistryLevel,
                toneCap: previous.toneCap,
                surpriseProgress: scopes.contains(.surpriseProgress)
                    ? 0
                    : previous.surpriseProgress,
                unlockedMementoIDs: scopes.contains(.mementos)
                    ? []
                    : previous.unlockedMementoIDs,
                recentAssetIDs: scopes.contains(.playbackHistory)
                    ? []
                    : previous.recentAssetIDs,
                lastPlayedAtByAssetID: scopes.contains(.playbackHistory)
                    ? [:]
                    : previous.lastPlayedAtByAssetID
            )
            let encoded = try CompanionRelationshipStateCodec.encode(replacement)
            userDefaults.removeObject(forKey: backupKey)
            userDefaults.set(encoded, forKey: storageKey)
            cachedState = replacement
            return replacement
        }
    }

    private func loadUnlocked() -> CompanionRelationshipStateV1 {
        if let cachedState {
            return cachedState
        }

        let originalPrimaryData = userDefaults.data(forKey: storageKey)
        var state = recoverUnlocked()
        state.resetSessionChemistry()
        cachedState = state

        // Rewrite a migrated or recovered payload in the current canonical schema.
        // A valid pre-migration payload is retained before replacement.
        if let encoded = try? CompanionRelationshipStateCodec.encode(state) {
            if let originalPrimaryData,
               originalPrimaryData != encoded,
               (try? CompanionRelationshipStateCodec.decode(originalPrimaryData)) != nil {
                userDefaults.set(originalPrimaryData, forKey: backupKey)
            }
            userDefaults.set(encoded, forKey: storageKey)
        }
        return state
    }

    private func recoverUnlocked() -> CompanionRelationshipStateV1 {
        if let primaryData = userDefaults.data(forKey: storageKey),
           let state = try? CompanionRelationshipStateCodec.decode(primaryData) {
            return state
        }

        if let backupData = userDefaults.data(forKey: backupKey),
           let state = try? CompanionRelationshipStateCodec.decode(backupData) {
            var persistentState = state
            persistentState.resetSessionChemistry()
            if let encoded = try? CompanionRelationshipStateCodec.encode(persistentState) {
                userDefaults.set(encoded, forKey: storageKey)
            }
            return state
        }

        return CompanionRelationshipStateV1()
    }

    private func persistUnlocked(
        _ state: CompanionRelationshipStateV1,
        backupCurrentPrimary: Bool = true
    ) throws {
        var persistentState = state
        persistentState.resetSessionChemistry()
        let encoded = try CompanionRelationshipStateCodec.encode(persistentState)

        if backupCurrentPrimary,
           let currentData = userDefaults.data(forKey: storageKey),
           (try? CompanionRelationshipStateCodec.decode(currentData)) != nil {
            userDefaults.set(currentData, forKey: backupKey)
        }
        userDefaults.set(encoded, forKey: storageKey)
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}
