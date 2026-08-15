import Foundation

/// Capability proving that a synchronous store operation is executing while
/// the cross-process lock is held. Only this file can create a scope.
struct ContentPackStoreLockScope {
    fileprivate init() {}
}

/// Owns lexical acquisition and release of the single store lock. It has no
/// layout, record, pack-validation or transaction policy.
struct ContentPackStoreLockCoordinator {
    let root: URL

    func acquire() throws -> ContentPackStoreFileLock {
        try ContentPackStoreFileLock.acquire(
            at: root.appendingPathComponent(".pack-store.lock")
        )
    }

    /// Async media probing must happen outside this closure so actor
    /// reentrancy cannot block the original operation behind a second waiter.
    func withLock<Result>(
        _ operation: (ContentPackStoreLockScope) throws -> Result
    ) throws -> Result {
        let storeLock = try acquire()
        defer { storeLock.release() }
        return try operation(ContentPackStoreLockScope())
    }
}
