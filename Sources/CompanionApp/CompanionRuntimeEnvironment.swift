import Foundation

/// Resolves the small set of writable roots used by the application runtime.
///
/// A normal build always uses the established local Chengyin directories. A
/// deliberately re-signed first-use audit bundle can opt into an isolated
/// temporary root through an Info.plist marker. The environment variable alone
/// is never enough to redirect a production bundle.
struct CompanionRuntimeEnvironment {
    static let firstUseAuditInfoKey = "ChengyinFirstUseAuditMode"
    static let firstUseAuditRootEnvironmentKey =
        "CHENGYIN_FIRST_USE_AUDIT_ROOT"
    static let auditReceiptName = "runtime-environment.json"

    let contentRoot: URL
    let eventRoot: URL
    let legacySessionRoot: URL
    let auditReceiptURL: URL?
    let isFirstUseAudit: Bool

    static func current(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        processIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier
    ) -> CompanionRuntimeEnvironment {
        let auditEnabled = bundle.object(
            forInfoDictionaryKey: firstUseAuditInfoKey
        ) as? Bool == true

        guard auditEnabled else {
            let sharedRoot = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
                .appendingPathComponent("Chengyin", isDirectory: true)
            return CompanionRuntimeEnvironment(
                contentRoot: sharedRoot.appendingPathComponent(
                    "content-store",
                    isDirectory: true
                ),
                eventRoot: sharedRoot.appendingPathComponent(
                    "events",
                    isDirectory: true
                ),
                legacySessionRoot: fileManager.homeDirectoryForCurrentUser
                    .appendingPathComponent(
                        ".codex/sessions",
                        isDirectory: true
                    ),
                auditReceiptURL: nil,
                isFirstUseAudit: false
            )
        }

        let temporaryRoot = fileManager.temporaryDirectory
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let requestedRoot = environment[firstUseAuditRootEnvironmentKey]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
        let fallbackRoot = temporaryRoot.appendingPathComponent(
            "chengyin-first-use-audit-\(processIdentifier)",
            isDirectory: true
        )
        let auditRoot = safeAuditRoot(
            requestedRoot,
            temporaryRoot: temporaryRoot
        ) ?? fallbackRoot

        return CompanionRuntimeEnvironment(
            contentRoot: auditRoot.appendingPathComponent(
                "content-store",
                isDirectory: true
            ),
            eventRoot: auditRoot.appendingPathComponent(
                "events",
                isDirectory: true
            ),
            legacySessionRoot: auditRoot.appendingPathComponent(
                "codex-sessions-empty",
                isDirectory: true
            ),
            auditReceiptURL: auditRoot.appendingPathComponent(
                auditReceiptName,
                isDirectory: false
            ),
            isFirstUseAudit: true
        )
    }

    @discardableResult
    func publishAuditReceipt(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) -> Bool {
        guard isFirstUseAudit, let auditReceiptURL else { return false }
        let root = auditReceiptURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(
                at: root,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let receipt: [String: Any] = [
                "schemaVersion": 1,
                "contract": "chengyin.first-use-runtime-environment/v1",
                "status": "PASS",
                "mode": "isolated-first-use-audit",
                "bundleIdentifier": bundle.bundleIdentifier ?? "unknown",
                "contentStore": "isolated-temporary-root",
                "eventInbox": "isolated-temporary-root",
                "legacyCodexSessions": "disabled-empty-root",
                "sharedUserContentAccess": false,
                "releaseState": "NOT_PUBLIC_RELEASE_READY"
            ]
            let data = try JSONSerialization.data(
                withJSONObject: receipt,
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: auditReceiptURL, options: .atomic)
            try fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: auditReceiptURL.path
            )
            return true
        } catch {
            return false
        }
    }

    private static func safeAuditRoot(
        _ candidate: URL?,
        temporaryRoot: URL
    ) -> URL? {
        guard let candidate, candidate.isFileURL else { return nil }
        let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
        let resolvedPath = canonicalTemporaryPath(resolved.path)
        let temporaryRootPath = canonicalTemporaryPath(temporaryRoot.path)
        let temporaryPrefix = temporaryRootPath.hasSuffix("/")
            ? temporaryRootPath
            : temporaryRootPath + "/"
        guard resolvedPath.hasPrefix(temporaryPrefix),
              resolvedPath != temporaryRootPath else {
            return nil
        }
        return resolved
    }

    /// APFS exposes `/tmp` and `/var` as firmlink aliases of their `/private`
    /// paths. Foundation does not resolve those aliases consistently for a
    /// non-existent leaf, so normalize both spellings before containment.
    private static func canonicalTemporaryPath(_ path: String) -> String {
        if path == "/tmp" || path.hasPrefix("/tmp/")
            || path == "/var" || path.hasPrefix("/var/") {
            return "/private" + path
        }
        return path
    }
}
