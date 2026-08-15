import Foundation

/// Owns only the private content-store directory topology and permissions.
/// It does not decode records, validate packs or acquire process locks.
struct ContentPackStoreLayout {
    let root: URL
    let fileManager: FileManager

    init(root: URL, fileManager: FileManager) {
        self.root = root.standardizedFileURL
        self.fileManager = fileManager
    }

    var packsRoot: URL {
        root.appendingPathComponent("packs", isDirectory: true)
    }

    var stagingRoot: URL {
        root.appendingPathComponent("staging", isDirectory: true)
    }

    var removedRoot: URL {
        root.appendingPathComponent("removed", isDirectory: true)
    }

    func packDirectory(for packID: String) -> URL {
        packsRoot.appendingPathComponent(packID, isDirectory: true)
    }

    func versionDirectory(packID: String, version: String) -> URL {
        packDirectory(for: packID)
            .appendingPathComponent("versions", isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
    }

    func prepareStore() throws {
        try createPrivateDirectory(root)
        try createPrivateDirectory(packsRoot)
        try createPrivateDirectory(stagingRoot)
        try createPrivateDirectory(removedRoot)
    }

    func createPrivateDirectory(_ directory: URL) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )
    }
}
