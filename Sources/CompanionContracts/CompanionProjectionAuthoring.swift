import Foundation

public enum CompanionProjectionAuthoringError: Error, Equatable, Sendable {
    case unsupportedSchema
    case invalidIdentity
    case emptyProjection
    case unsupportedMode(String)
    case invalidTrack(String)
    case invalidSafeArea(String)
    case safeAreaWithoutTrack(String)
    case safeAreaNotVisible(String)
}

extension CompanionProjectionAuthoringError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema:
            "The projection authoring receipt schema is unsupported."
        case .invalidIdentity:
            "The projection authoring receipt has an invalid pack or asset identity."
        case .emptyProjection:
            "The projection authoring receipt does not contain a focal track."
        case let .unsupportedMode(mode):
            "The projection mode is unsupported: \(mode)."
        case let .invalidTrack(mode):
            "The focal track is invalid for \(mode)."
        case let .invalidSafeArea(mode):
            "The safe area is invalid for \(mode)."
        case let .safeAreaWithoutTrack(mode):
            "The safe area has no matching focal track for \(mode)."
        case let .safeAreaNotVisible(mode):
            "The safe area leaves the visible crop for \(mode)."
        }
    }
}

/// A portable, data-only handoff from the offline projection editor to a pack
/// authoring workflow. It contains no media path, provider credential, user
/// path or executable instruction and is not itself an approval or signature.
public struct CompanionProjectionAuthoringReceipt: Codable, Equatable, Sendable {
    public static let currentSchemaVersion =
        "chengyin.projection-authoring-receipt/v1"
    public static let allowedModes = Set(["pet", "stage", "fullscreen"])

    public let schemaVersion: String
    public let packID: String
    public let assetID: String
    public let generatedForAppVersion: String
    public let focalTracks: [String: [CompanionMediaFocalKeyframe]]
    public let safeAreas: [String: CompanionMediaSafeArea]

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        packID: String,
        assetID: String,
        generatedForAppVersion: String,
        focalTracks: [String: [CompanionMediaFocalKeyframe]],
        safeAreas: [String: CompanionMediaSafeArea]
    ) {
        self.schemaVersion = schemaVersion
        self.packID = packID
        self.assetID = assetID
        self.generatedForAppVersion = generatedForAppVersion
        self.focalTracks = focalTracks
        self.safeAreas = safeAreas
    }

    public func validate(durationMs: Int? = nil) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw CompanionProjectionAuthoringError.unsupportedSchema
        }
        guard Self.isSafeIdentity(packID), Self.isSafeIdentity(assetID),
              Self.isSemanticVersion(generatedForAppVersion) else {
            throw CompanionProjectionAuthoringError.invalidIdentity
        }
        guard !focalTracks.isEmpty else {
            throw CompanionProjectionAuthoringError.emptyProjection
        }
        for mode in focalTracks.keys.sorted() {
            guard Self.allowedModes.contains(mode) else {
                throw CompanionProjectionAuthoringError.unsupportedMode(mode)
            }
            let track = CompanionMediaFocalTrack(
                keyframes: focalTracks[mode] ?? []
            )
            guard track.isValid(durationMs: durationMs) else {
                throw CompanionProjectionAuthoringError.invalidTrack(mode)
            }
        }
        for mode in safeAreas.keys.sorted() {
            guard Self.allowedModes.contains(mode) else {
                throw CompanionProjectionAuthoringError.unsupportedMode(mode)
            }
            guard let safeArea = safeAreas[mode], safeArea.isValid else {
                throw CompanionProjectionAuthoringError.invalidSafeArea(mode)
            }
            guard let keyframes = focalTracks[mode] else {
                throw CompanionProjectionAuthoringError.safeAreaWithoutTrack(mode)
            }
            guard keyframes.allSatisfy({ safeArea.isVisible(through: $0.anchor) }) else {
                throw CompanionProjectionAuthoringError.safeAreaNotVisible(mode)
            }
        }
    }

    private static func isSafeIdentity(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        func isASCIIAlphanumeric(_ byte: UInt8) -> Bool {
            (48...57).contains(byte)
                || (65...90).contains(byte)
                || (97...122).contains(byte)
        }
        guard !bytes.isEmpty, bytes.count <= 160,
              isASCIIAlphanumeric(bytes[0]) else {
            return false
        }
        return bytes.allSatisfy { byte in
            isASCIIAlphanumeric(byte) || byte == 46 || byte == 45 || byte == 95
        }
    }

    private static func isSemanticVersion(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.utf8.allSatisfy { (48...57).contains($0) }
        }
    }
}
