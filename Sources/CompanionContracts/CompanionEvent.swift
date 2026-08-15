import Foundation

public enum CompanionEventType: String, Codable, CaseIterable, Sendable {
    case responseReady = "response.ready"
    case taskStarted = "task.started"
    case taskProgress = "task.progress"
    case taskCompleted = "task.completed"
    case taskFailed = "task.failed"
    case taskCancelled = "task.cancelled"
    case taskLongRunning = "task.long_running"
    case integrationHealth = "integration.health"
    case integrationDisconnected = "integration.disconnected"
}

public enum CompanionEventOutcome: String, Codable, Sendable {
    case success
    case failure
    case cancelled
    case unknown
}

public struct CompanionEventPrivacy: Codable, Equatable, Sendable {
    public var containsTaskTitle: Bool
    public var containsPath: Bool
    public var containsCode: Bool
    public var containsPrompt: Bool
    public var containsPersonalData: Bool

    public init(
        containsTaskTitle: Bool = false,
        containsPath: Bool = false,
        containsCode: Bool = false,
        containsPrompt: Bool = false,
        containsPersonalData: Bool = false
    ) {
        self.containsTaskTitle = containsTaskTitle
        self.containsPath = containsPath
        self.containsCode = containsCode
        self.containsPrompt = containsPrompt
        self.containsPersonalData = containsPersonalData
    }

    public var hasPrivatePayload: Bool {
        containsTaskTitle
            || containsPath
            || containsCode
            || containsPrompt
            || containsPersonalData
    }
}

public struct CompanionEvent: Codable, Equatable, Sendable {
    public static let currentProtocolVersion = "1.0"

    public var protocolVersion: String
    public var eventId: String
    public var source: String
    public var sourceVersion: String?
    public var type: CompanionEventType
    public var taskRef: String?
    public var occurredAt: Date
    public var durationMs: Int64?
    public var outcome: CompanionEventOutcome?
    public var privacy: CompanionEventPrivacy
    public var metadata: [String: String]

    public init(
        protocolVersion: String = CompanionEvent.currentProtocolVersion,
        eventId: String = UUID().uuidString,
        source: String,
        sourceVersion: String? = nil,
        type: CompanionEventType,
        taskRef: String? = nil,
        occurredAt: Date = Date(),
        durationMs: Int64? = nil,
        outcome: CompanionEventOutcome? = nil,
        privacy: CompanionEventPrivacy = CompanionEventPrivacy(),
        metadata: [String: String] = [:]
    ) {
        self.protocolVersion = protocolVersion
        self.eventId = eventId
        self.source = source
        self.sourceVersion = sourceVersion
        self.type = type
        self.taskRef = taskRef
        self.occurredAt = occurredAt
        self.durationMs = durationMs
        self.outcome = outcome
        self.privacy = privacy
        self.metadata = metadata
    }
}

public enum CompanionEventValidationError: Error, Equatable, Sendable {
    case payloadTooLarge
    case unsupportedProtocolVersion
    case invalidEventId
    case invalidSource
    case invalidSourceVersion
    case invalidTaskReference
    case invalidDuration
    case eventTooFarInFuture
    case privatePayloadNotAllowed
    case tooManyMetadataEntries
    case invalidMetadata
}

extension CompanionEventValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .payloadTooLarge:
            "The event exceeds the 64 KiB protocol limit."
        case .unsupportedProtocolVersion:
            "The event protocol version is not supported."
        case .invalidEventId:
            "The event ID must be a UUID."
        case .invalidSource:
            "The event source is missing or contains unsupported characters."
        case .invalidSourceVersion:
            "The source version is too long."
        case .invalidTaskReference:
            "The opaque task reference is invalid."
        case .invalidDuration:
            "The task duration cannot be negative."
        case .eventTooFarInFuture:
            "The event time is too far in the future."
        case .privatePayloadNotAllowed:
            "Companion events must not include task titles, code, prompts, paths, or personal data."
        case .tooManyMetadataEntries:
            "The event has too many metadata entries."
        case .invalidMetadata:
            "A metadata key or value is invalid."
        }
    }
}

public enum CompanionEventCodec {
    public static let maximumPayloadBytes = 64 * 1024
    public static let maximumMetadataEntries = 16

    public static func encode(
        _ event: CompanionEvent,
        now: Date = Date()
    ) throws -> Data {
        try validate(event, now: now)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(event)

        guard data.count <= maximumPayloadBytes else {
            throw CompanionEventValidationError.payloadTooLarge
        }
        return data
    }

    public static func decode(
        _ data: Data,
        now: Date = Date()
    ) throws -> CompanionEvent {
        guard data.count <= maximumPayloadBytes else {
            throw CompanionEventValidationError.payloadTooLarge
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(CompanionEvent.self, from: data)
        try validate(event, now: now)
        return event
    }

    public static func validate(
        _ event: CompanionEvent,
        now: Date = Date()
    ) throws {
        let versionParts = event.protocolVersion.split(separator: ".", omittingEmptySubsequences: false)
        guard
            versionParts.count == 2,
            versionParts[0] == "1",
            Int(versionParts[1]) != nil
        else {
            throw CompanionEventValidationError.unsupportedProtocolVersion
        }

        guard UUID(uuidString: event.eventId) != nil else {
            throw CompanionEventValidationError.invalidEventId
        }

        guard
            !event.source.isEmpty,
            event.source.count <= 64,
            event.source.unicodeScalars.allSatisfy(Self.isAllowedIdentifierScalar)
        else {
            throw CompanionEventValidationError.invalidSource
        }

        if let sourceVersion = event.sourceVersion, sourceVersion.count > 64 {
            throw CompanionEventValidationError.invalidSourceVersion
        }

        if let taskRef = event.taskRef {
            guard !taskRef.isEmpty, taskRef.count <= 256 else {
                throw CompanionEventValidationError.invalidTaskReference
            }
        }

        if let durationMs = event.durationMs, durationMs < 0 {
            throw CompanionEventValidationError.invalidDuration
        }

        if event.occurredAt > now.addingTimeInterval(5 * 60) {
            throw CompanionEventValidationError.eventTooFarInFuture
        }

        guard !event.privacy.hasPrivatePayload else {
            throw CompanionEventValidationError.privatePayloadNotAllowed
        }

        guard event.metadata.count <= maximumMetadataEntries else {
            throw CompanionEventValidationError.tooManyMetadataEntries
        }

        for (key, value) in event.metadata {
            guard
                !key.isEmpty,
                key.count <= 64,
                value.count <= 256,
                key.unicodeScalars.allSatisfy(Self.isAllowedIdentifierScalar)
            else {
                throw CompanionEventValidationError.invalidMetadata
            }
        }
    }

    private static func isAllowedIdentifierScalar(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet.alphanumerics.contains(scalar)
            || scalar == "-"
            || scalar == "_"
            || scalar == "."
    }
}

public actor CompanionEventDeduplicator {
    private let capacity: Int
    private var orderedEventIds: [String] = []
    private var eventIds: Set<String> = []

    public init(capacity: Int = 512) {
        self.capacity = max(1, capacity)
    }

    public func insertIfNew(_ eventId: String) -> Bool {
        guard !eventIds.contains(eventId) else {
            return false
        }

        eventIds.insert(eventId)
        orderedEventIds.append(eventId)

        if orderedEventIds.count > capacity {
            let removed = orderedEventIds.removeFirst()
            eventIds.remove(removed)
        }
        return true
    }

    public func removeAll() {
        orderedEventIds.removeAll(keepingCapacity: true)
        eventIds.removeAll(keepingCapacity: true)
    }
}
