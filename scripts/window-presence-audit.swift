import AppKit
import CoreGraphics
import Foundation

struct WindowReceipt: Codable {
    struct Window: Codable {
        let width: Int
        let height: Int
        let layer: Int
        let alpha: Double
        let onScreen: Bool
    }

    let status: String
    let code: String?
    let processCount: Int
    let windowCount: Int
    let windows: [Window]
    let recoveryAction: String?
}

let rawWindows = CGWindowListCopyWindowInfo(
    [.optionAll, .excludeDesktopElements],
    CGWindowID(0)
) as? [[String: Any]] ?? []

let runningPIDs: Set<pid_t>
if ProcessInfo.processInfo.environment["CHENGYIN_WINDOW_AUDIT_TEST_NO_PROCESS"] == "1" {
    runningPIDs = []
} else {
    runningPIDs = Set(
        NSWorkspace.shared.runningApplications.compactMap { application -> pid_t? in
            if application.bundleIdentifier == "local.zidong.chengyin-companion"
                || application.executableURL?.lastPathComponent == "ChengyinCompanion" {
                return application.processIdentifier
            }
            return nil
        }
    )
}
let windows = rawWindows.compactMap { raw -> WindowReceipt.Window? in
    guard let ownerPID = raw[kCGWindowOwnerPID as String] as? NSNumber,
          runningPIDs.contains(pid_t(ownerPID.int32Value)),
          let bounds = raw[kCGWindowBounds as String] as? [String: Any]
    else {
        return nil
    }
    let width = (bounds["Width"] as? NSNumber)?.intValue ?? 0
    let height = (bounds["Height"] as? NSNumber)?.intValue ?? 0
    let layer = (raw[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
    let alpha = (raw[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0
    let onScreen = (raw[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
    guard width > 0, height > 0 else { return nil }
    return WindowReceipt.Window(
        width: width,
        height: height,
        layer: layer,
        alpha: alpha,
        onScreen: onScreen
    )
}

let visible = windows.filter { $0.alpha > 0 && $0.onScreen }
let receipt = WindowReceipt(
    status: visible.isEmpty ? "FAIL" : "PASS",
    code: runningPIDs.isEmpty
        ? "UI_PROCESS_NOT_DISCOVERABLE"
        : (visible.isEmpty ? "UI_WINDOW_NOT_ONSCREEN" : nil),
    processCount: runningPIDs.count,
    windowCount: visible.count,
    windows: windows,
    recoveryAction: visible.isEmpty
        ? "Quit and relaunch the installed app, then rerun the window audit."
        : nil
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
FileHandle.standardOutput.write(try encoder.encode(receipt))
FileHandle.standardOutput.write(Data("\n".utf8))
exit(visible.isEmpty ? 1 : 0)
