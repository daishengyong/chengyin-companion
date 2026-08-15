import Foundation

private var passed = 0
private var failed = 0

private func check(_ condition: @autoclosure () -> Bool, _ label: String) {
    if condition() {
        passed += 1
        print("PASS  \(label)")
    } else {
        failed += 1
        fputs("FAIL  \(label)\n", stderr)
    }
}

private func makeBundle(
    root: URL,
    name: String,
    identifier: String,
    auditMode: Bool
) throws -> Bundle {
    let bundleRoot = root.appendingPathComponent("\(name).bundle", isDirectory: true)
    let contents = bundleRoot.appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(
        at: contents,
        withIntermediateDirectories: true
    )
    let info: [String: Any] = [
        "CFBundleIdentifier": identifier,
        "CFBundleName": name,
        "CFBundlePackageType": "BNDL",
        "CFBundleShortVersionString": "1.0.0",
        "CFBundleVersion": "1",
        CompanionRuntimeEnvironment.firstUseAuditInfoKey: auditMode
    ]
    let data = try PropertyListSerialization.data(
        fromPropertyList: info,
        format: .xml,
        options: 0
    )
    try data.write(
        to: contents.appendingPathComponent("Info.plist"),
        options: .atomic
    )
    guard let bundle = Bundle(url: bundleRoot) else {
        throw NSError(domain: "runtime-environment-smoke", code: 1)
    }
    return bundle
}

let fileManager = FileManager.default
let root = fileManager.temporaryDirectory.appendingPathComponent(
    "chengyin-runtime-environment-smoke-\(UUID().uuidString)",
    isDirectory: true
)
try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: root) }

let normalBundle = try makeBundle(
    root: root,
    name: "Normal",
    identifier: "local.chengyin.runtime.normal",
    auditMode: false
)
let auditBundle = try makeBundle(
    root: root,
    name: "Audit",
    identifier: "local.chengyin.runtime.audit",
    auditMode: true
)
let requestedRoot = root.appendingPathComponent("isolated", isDirectory: true)
let resolvedRequestedRoot = requestedRoot
    .resolvingSymlinksInPath()
    .standardizedFileURL

let normal = CompanionRuntimeEnvironment.current(
    bundle: normalBundle,
    fileManager: fileManager,
    environment: [
        CompanionRuntimeEnvironment.firstUseAuditRootEnvironmentKey:
            requestedRoot.path
    ],
    processIdentifier: 101
)
check(!normal.isFirstUseAudit, "environment variable alone cannot redirect production")
check(
    normal.contentRoot.path.contains("/Chengyin/content-store"),
    "normal runtime preserves the established content root"
)
check(normal.auditReceiptURL == nil, "normal runtime never publishes an audit marker")

let isolated = CompanionRuntimeEnvironment.current(
    bundle: auditBundle,
    fileManager: fileManager,
    environment: [
        CompanionRuntimeEnvironment.firstUseAuditRootEnvironmentKey:
            requestedRoot.path
    ],
    processIdentifier: 102
)
check(isolated.isFirstUseAudit, "marked audit bundle enters isolated mode")
check(
    isolated.contentRoot.deletingLastPathComponent()
        .resolvingSymlinksInPath().standardizedFileURL.path
        == resolvedRequestedRoot.path,
    "marked audit bundle uses the requested temporary root"
)
check(
    isolated.eventRoot.deletingLastPathComponent()
        .resolvingSymlinksInPath().standardizedFileURL.path
        == resolvedRequestedRoot.path
        && isolated.legacySessionRoot.deletingLastPathComponent()
            .resolvingSymlinksInPath().standardizedFileURL.path
            == resolvedRequestedRoot.path,
    "content, events and legacy sessions share one isolated audit boundary"
)
check(
    isolated.publishAuditReceipt(bundle: auditBundle, fileManager: fileManager),
    "isolated runtime publishes its machine receipt"
)
if let receiptURL = isolated.auditReceiptURL,
   let data = try? Data(contentsOf: receiptURL),
   let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    let encoded = String(decoding: data, as: UTF8.self)
    check(
        value["status"] as? String == "PASS"
            && value["sharedUserContentAccess"] as? Bool == false,
        "audit receipt proves shared user content is disabled"
    )
    check(
        !encoded.contains("/Users/") && !encoded.contains("/Volumes/"),
        "audit receipt is path-safe"
    )
} else {
    check(false, "audit receipt proves shared user content is disabled")
    check(false, "audit receipt is path-safe")
}

let unsafe = CompanionRuntimeEnvironment.current(
    bundle: auditBundle,
    fileManager: fileManager,
    environment: [
        CompanionRuntimeEnvironment.firstUseAuditRootEnvironmentKey:
            fileManager.homeDirectoryForCurrentUser.path
    ],
    processIdentifier: 103
)
check(
    !unsafe.contentRoot.path.hasPrefix(fileManager.homeDirectoryForCurrentUser.path),
    "audit mode rejects a home-directory root"
)
check(
    unsafe.contentRoot.path.contains("chengyin-first-use-audit-103"),
    "unsafe audit roots fall back to a bounded temporary directory"
)

let link = root.appendingPathComponent("escape", isDirectory: true)
try fileManager.createSymbolicLink(
    at: link,
    withDestinationURL: fileManager.homeDirectoryForCurrentUser
)
let linked = CompanionRuntimeEnvironment.current(
    bundle: auditBundle,
    fileManager: fileManager,
    environment: [
        CompanionRuntimeEnvironment.firstUseAuditRootEnvironmentKey: link.path
    ],
    processIdentifier: 104
)
check(
    !linked.contentRoot.path.hasPrefix(fileManager.homeDirectoryForCurrentUser.path),
    "audit mode rejects a symbolic-link escape"
)

if failed == 0 {
    print("Runtime environment smoke: PASS (12/12)")
    exit(0)
}
fputs("Runtime environment smoke: FAIL (\(failed) failed, \(passed) passed)\n", stderr)
exit(1)
