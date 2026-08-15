import Foundation

/// Stable transaction-facing facade over private layout, active-record truth
/// and lexical cross-process locking. It owns no install, rollback,
/// authorization or playback-health transition policy.
struct ContentPackStoreRepository {
    let root: URL
    let currentAppVersion: String
    let fileManager: FileManager
    let validator: ContentPackValidator

    private let layout: ContentPackStoreLayout
    private let activeRecords: ContentPackActiveRecordRepository
    private let lockCoordinator: ContentPackStoreLockCoordinator

    init(
        root: URL,
        currentAppVersion: String,
        fileManager: FileManager
    ) {
        let normalizedRoot = root.standardizedFileURL
        let validator = ContentPackValidator(fileManager: fileManager)
        let layout = ContentPackStoreLayout(
            root: normalizedRoot,
            fileManager: fileManager
        )
        self.root = normalizedRoot
        self.currentAppVersion = currentAppVersion
        self.fileManager = fileManager
        self.validator = validator
        self.layout = layout
        activeRecords = ContentPackActiveRecordRepository(
            layout: layout,
            currentAppVersion: currentAppVersion,
            validator: validator
        )
        lockCoordinator = ContentPackStoreLockCoordinator(root: normalizedRoot)
    }

    var packsRoot: URL { layout.packsRoot }
    var stagingRoot: URL { layout.stagingRoot }
    var removedRoot: URL { layout.removedRoot }

    var recoveryCatalog: ContentPackRecoveryCatalog {
        ContentPackRecoveryCatalog(
            removedRoot: removedRoot,
            currentAppVersion: currentAppVersion,
            fileManager: fileManager
        )
    }

    func packDirectory(for packID: String) -> URL {
        layout.packDirectory(for: packID)
    }

    func versionDirectory(packID: String, version: String) -> URL {
        layout.versionDirectory(packID: packID, version: version)
    }

    func prepareStore() throws {
        try layout.prepareStore()
    }

    func createPrivateDirectory(_ directory: URL) throws {
        try layout.createPrivateDirectory(directory)
    }

    func validateIdentifier(_ packID: String) throws {
        try activeRecords.validateIdentifier(packID)
    }

    func readActiveRecord(packID: String) throws -> ActiveContentPackRecord? {
        try activeRecords.read(packID: packID)
    }

    func writeActiveRecord(_ record: ActiveContentPackRecord) throws {
        try activeRecords.write(record)
    }

    func installedPack(for record: ActiveContentPackRecord) throws -> InstalledContentPack {
        try activeRecords.installedPack(for: record)
    }

    func acquireStoreLock() throws -> ContentPackStoreFileLock {
        try lockCoordinator.acquire()
    }

    /// Keeps cross-process locking lexically synchronous. Async media probing
    /// must happen outside this closure.
    func withStoreLock<Result>(
        _ operation: (ContentPackStoreLockScope) throws -> Result
    ) throws -> Result {
        try lockCoordinator.withLock(operation)
    }
}
