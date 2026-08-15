import Foundation

@main
enum CompanionRuntimeRepairSmoke {
    static func main() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "chengyin-runtime-repair-smoke-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: root) }
        let repairer = CompanionEventBridgeRepairer(fileManager: fileManager)

        let missing = root.appendingPathComponent("missing", isDirectory: true)
        try require(
            repairer.inspect(root: missing).status == .needsRepair,
            "missing bridge was not reported as repairable"
        )
        try require(
            repairer.repair(root: missing).status == .repaired,
            "missing bridge was not created"
        )
        try require(privateDirectory(missing), "created bridge did not use 0700")

        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: missing.path
        )
        try require(
            repairer.inspect(root: missing).status == .needsRepair,
            "broad bridge permissions were accepted"
        )
        try require(
            repairer.repair(root: missing).status == .repaired
                && privateDirectory(missing),
            "broad bridge permissions were not narrowed"
        )
        try require(
            repairer.repair(root: missing).status == .ready,
            "idempotent repair changed an already ready bridge"
        )

        let occupied = root.appendingPathComponent("occupied")
        try Data("keep-me".utf8).write(to: occupied)
        let occupiedReceipt = repairer.repair(root: occupied)
        try require(
            occupiedReceipt.status == .refused
                && occupiedReceipt.code == "UI_RUNTIME_REPAIR_REFUSED",
            "regular-file occupation was not refused"
        )
        try require(
            try String(contentsOf: occupied, encoding: .utf8) == "keep-me",
            "refused repair changed the occupying file"
        )

        let target = root.appendingPathComponent("target", isDirectory: true)
        let symbolic = root.appendingPathComponent("symbolic")
        try fileManager.createDirectory(at: target, withIntermediateDirectories: false)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)
        try fileManager.createSymbolicLink(at: symbolic, withDestinationURL: target)
        let symbolicReceipt = repairer.repair(root: symbolic)
        try require(
            symbolicReceipt.status == .refused
                && symbolicReceipt.code == "UI_RUNTIME_REPAIR_REFUSED",
            "symbolic-link occupation was not refused"
        )
        try require(
            permissions(target) == 0o755,
            "refused repair followed the symbolic link"
        )

        let parentFile = root.appendingPathComponent("parent-file")
        try Data("parent".utf8).write(to: parentFile)
        let failedReceipt = repairer.repair(
            root: parentFile.appendingPathComponent("events", isDirectory: true)
        )
        try require(
            failedReceipt.status == .failed
                && failedReceipt.code == "UI_RUNTIME_REPAIR_FAILED",
            "filesystem failure lost its stable code"
        )

        for receipt in [occupiedReceipt, symbolicReceipt, failedReceipt] {
            try require(
                !(receipt.code ?? "").contains("/")
                    && !(receipt.code ?? "").contains(root.path),
                "repair receipt exposed a path"
            )
        }
        print("Runtime repair smoke: PASS (6/6)")
    }

    private static func privateDirectory(_ url: URL) -> Bool {
        permissions(url) == 0o700
    }

    private static func permissions(_ url: URL) -> Int? {
        let value = try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions]
        guard let number = value as? NSNumber else { return nil }
        return number.intValue & 0o777
    }

    private static func require(
        _ condition: @autoclosure () throws -> Bool,
        _ message: String
    ) throws {
        guard try condition() else {
            throw RuntimeRepairSmokeFailure(message: message)
        }
    }
}

private struct RuntimeRepairSmokeFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
