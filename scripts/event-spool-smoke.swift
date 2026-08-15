import Darwin
import Foundation

private struct EventSpoolSmokeFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private func require(
    _ condition: @autoclosure () throws -> Bool,
    _ message: String
) throws {
    guard try condition() else {
        throw EventSpoolSmokeFailure(message: message)
    }
}

@main
enum CompanionEventSpoolSmoke {
    static func main() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(
            "chengyin-event-spool-smoke-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let now = Date()
        try validAndUnchanged(root: directory("valid", under: temporaryRoot), now: now)
        try hostileEntries(root: directory("hostile", under: temporaryRoot), now: now)
        try stalePruning(root: directory("stale", under: temporaryRoot), now: now)
        try capacityPruning(root: directory("capacity", under: temporaryRoot), now: now)
        try directoryLimit(root: directory("limit", under: temporaryRoot), now: now)
        try rootHealth(under: temporaryRoot)

        print("Event spool smoke: PASS (valid + no-follow + retention + health matrix)")
    }

    private static func validAndUnchanged(root: URL, now: Date) throws {
        try prepare(root)
        let id = UUID().uuidString
        try writeEvent(id: id, to: root, occurredAt: now)
        var spool = CompanionEventSpool()
        let first = spool.scan(root: root, now: now)
        try require(first.status == .ready, "private event root was not ready")
        try require(first.entries.map(\.eventID) == [id], "valid event was not read")
        let event = try CompanionEventCodec.decode(first.entries[0].data, now: now)
        try require(event.eventId == id, "valid event content changed")
        let second = spool.scan(root: root, now: now)
        try require(second.entries.isEmpty, "unchanged event was delivered twice")
    }

    private static func hostileEntries(root: URL, now: Date) throws {
        try prepare(root)
        let outside = root.deletingLastPathComponent().appendingPathComponent("outside.json")
        let outsideID = UUID().uuidString
        try eventData(id: outsideID, occurredAt: now).write(to: outside, options: .atomic)
        try permissions(0o600, for: outside)

        let symlinkName = root.appendingPathComponent("\(UUID().uuidString).json")
        try FileManager.default.createSymbolicLink(at: symlinkName, withDestinationURL: outside)

        let hardlinkName = root.appendingPathComponent("\(UUID().uuidString).json")
        try require(Darwin.link(outside.path, hardlinkName.path) == 0, "hard-link fixture failed")

        let broadID = UUID().uuidString
        let broad = try writeEvent(id: broadID, to: root, occurredAt: now)
        try permissions(0o644, for: broad)

        let fifo = root.appendingPathComponent("\(UUID().uuidString).json")
        try require(Darwin.mkfifo(fifo.path, mode_t(0o600)) == 0, "FIFO fixture failed")

        let oversized = root.appendingPathComponent("\(UUID().uuidString).json")
        try Data(
            repeating: 0x20,
            count: CompanionEventCodec.maximumPayloadBytes + 1
        ).write(to: oversized)
        try permissions(0o600, for: oversized)

        var spool = CompanionEventSpool()
        let receipt = spool.scan(root: root, now: now)
        try require(receipt.status == .ready, "ignored entries disabled the safe inbox")
        try require(receipt.entries.isEmpty, "an unsafe event entry was read")
        try require(receipt.ignoredEntryCount == 5, "unsafe entry count changed")
        try require(FileManager.default.fileExists(atPath: symlinkName.path), "symlink was deleted")
        try require(FileManager.default.fileExists(atPath: hardlinkName.path), "hard link was deleted")
        try require(FileManager.default.fileExists(atPath: broad.path), "broad file was deleted")
        try require(FileManager.default.fileExists(atPath: fifo.path), "FIFO was deleted")
        try require(FileManager.default.fileExists(atPath: oversized.path), "oversized file was deleted")
        try require(try Data(contentsOf: outside) == eventData(id: outsideID, occurredAt: now), "linked target changed")
    }

    private static func stalePruning(root: URL, now: Date) throws {
        try prepare(root)
        let stale = try writeEvent(id: UUID().uuidString, to: root, occurredAt: now)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-48 * 60 * 60)],
            ofItemAtPath: stale.path
        )
        var spool = CompanionEventSpool(maximumAge: 36 * 60 * 60)
        let receipt = spool.scan(root: root, now: now)
        try require(receipt.prunedEntryCount == 1, "stale safe event was not pruned")
        try require(!FileManager.default.fileExists(atPath: stale.path), "stale file remains")
    }

    private static func capacityPruning(root: URL, now: Date) throws {
        try prepare(root)
        var paths: [URL] = []
        for offset in [3.0, 2.0, 1.0] {
            let path = try writeEvent(id: UUID().uuidString, to: root, occurredAt: now)
            try FileManager.default.setAttributes(
                [.modificationDate: now.addingTimeInterval(-offset)],
                ofItemAtPath: path.path
            )
            paths.append(path)
        }
        var spool = CompanionEventSpool(maximumRetainedFiles: 2)
        let receipt = spool.scan(root: root, now: now)
        try require(receipt.entries.count == 2, "retained event count is not bounded")
        try require(receipt.prunedEntryCount == 1, "oldest excess event was not pruned")
        try require(!FileManager.default.fileExists(atPath: paths[0].path), "oldest event remains")
        try require(FileManager.default.fileExists(atPath: paths[1].path), "newer event was pruned")
        try require(FileManager.default.fileExists(atPath: paths[2].path), "newest event was pruned")
    }

    private static func directoryLimit(root: URL, now: Date) throws {
        try prepare(root)
        for index in 0..<3 {
            try Data("preserve-\(index)".utf8).write(
                to: root.appendingPathComponent("unexpected-\(index).txt")
            )
        }
        var spool = CompanionEventSpool(maximumDirectoryEntries: 2)
        let receipt = spool.scan(root: root, now: now)
        try require(receipt.status == .entryLimitExceeded, "entry overload was accepted")
        try require(
            receipt.companionErrorCode == "EVENT_SPOOL_ENTRY_LIMIT_EXCEEDED",
            "entry-limit code changed"
        )
        try require(
            try FileManager.default.contentsOfDirectory(atPath: root.path).count == 3,
            "overload handling deleted an unexpected entry"
        )
    }

    private static func rootHealth(under parent: URL) throws {
        let missing = parent.appendingPathComponent("missing")
        var spool = CompanionEventSpool()
        let missingReceipt = spool.scan(root: missing)
        try require(missingReceipt.status == .rootUnavailable, "missing root was accepted")
        try require(
            missingReceipt.companionErrorCode == "EVENT_SPOOL_ROOT_UNAVAILABLE",
            "missing-root code changed"
        )

        let target = directory("root-target", under: parent)
        try prepare(target)
        let symbolic = parent.appendingPathComponent("root-symbolic")
        try FileManager.default.createSymbolicLink(at: symbolic, withDestinationURL: target)
        let symbolicReceipt = spool.scan(root: symbolic)
        try require(symbolicReceipt.status == .rootUnsafe, "symbolic root was accepted")
        try require(
            symbolicReceipt.companionErrorCode == "EVENT_SPOOL_ROOT_UNSAFE",
            "unsafe-root code changed"
        )
        try require(privateDirectory(target), "root inspection changed the target")

        for receipt in [missingReceipt, symbolicReceipt] {
            let encoded = "\(receipt.companionErrorCode ?? "")"
            try require(!encoded.contains("/") && !encoded.contains(parent.path), "health receipt exposed a path")
        }
    }

    private static func directory(_ name: String, under parent: URL) -> URL {
        parent.appendingPathComponent(name, isDirectory: true)
    }

    private static func prepare(_ root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try permissions(0o700, for: root)
    }

    @discardableResult
    private static func writeEvent(
        id: String,
        to root: URL,
        occurredAt: Date
    ) throws -> URL {
        let destination = root.appendingPathComponent("\(id).json")
        try eventData(id: id, occurredAt: occurredAt).write(to: destination, options: .atomic)
        try permissions(0o600, for: destination)
        return destination
    }

    private static func eventData(id: String, occurredAt: Date) throws -> Data {
        try CompanionEventCodec.encode(
            CompanionEvent(
                eventId: id,
                source: "spool-smoke",
                type: .responseReady,
                occurredAt: occurredAt
            ),
            now: occurredAt
        )
    }

    private static func permissions(_ mode: Int, for url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: mode],
            ofItemAtPath: url.path
        )
    }

    private static func privateDirectory(_ url: URL) -> Bool {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.posixPermissions] as? NSNumber)?.intValue ?? 0 & 0o777 == 0o700
    }
}
