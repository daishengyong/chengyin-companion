import AppKit
import CoreGraphics
import Foundation

guard let app = NSRunningApplication.runningApplications(
    withBundleIdentifier: "local.zidong.chengyin-companion"
).first else {
    fputs("澄音没有运行。\n", stderr)
    exit(2)
}

let processIdentifier = app.processIdentifier
let source = CGEventSource(stateID: .hidSystemState)
let keyCodeB: CGKeyCode = 11
let requestedHits = Int(CommandLine.arguments.dropFirst().first ?? "8") ?? 8

func postShortcut() {
    for isDown in [true, false] {
        let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCodeB,
            keyDown: isDown
        )!
        event.flags = [.maskCommand, .maskShift]
        event.post(tap: .cghidEventTap)
    }
}

func openFiles() -> String {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    process.arguments = ["-p", String(processIdentifier)]
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

func waitUntil(
    timeout: TimeInterval,
    condition: () -> Bool
) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return true
        }
        usleep(25_000)
    }
    return false
}

func petBounds() -> CGRect? {
    let windows = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly],
        kCGNullWindowID
    ) as? [[String: Any]] ?? []
    for window in windows {
        guard
            window[kCGWindowOwnerName as String] as? String == "澄音",
            let value = window[kCGWindowBounds as String] as? [String: Any],
            let x = (value["X"] as? NSNumber)?.doubleValue,
            let y = (value["Y"] as? NSNumber)?.doubleValue,
            let width = (value["Width"] as? NSNumber)?.doubleValue,
            let height = (value["Height"] as? NSNumber)?.doubleValue,
            width <= 160,
            height <= 200
        else { continue }
        return CGRect(x: x, y: y, width: width, height: height)
    }
    return nil
}

func click(_ point: CGPoint) {
    let down = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseDown,
        mouseCursorPosition: point,
        mouseButton: .left
    )!
    down.post(tap: .cghidEventTap)
    usleep(20_000)
    let up = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseUp,
        mouseCursorPosition: point,
        mouseButton: .left
    )!
    up.post(tap: .cghidEventTap)
}

func waitForWindow(
    timeout: TimeInterval,
    matching predicate: (CGRect) -> Bool
) -> CGRect? {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []
        for window in windows {
            guard
                window[kCGWindowOwnerName as String] as? String == "澄音",
                let value = window[kCGWindowBounds as String] as? [String: Any],
                let x = (value["X"] as? NSNumber)?.doubleValue,
                let y = (value["Y"] as? NSNumber)?.doubleValue,
                let width = (value["Width"] as? NSNumber)?.doubleValue,
                let height = (value["Height"] as? NSNumber)?.doubleValue
            else { continue }
            let candidate = CGRect(x: x, y: y, width: width, height: height)
            if predicate(candidate) { return candidate }
        }
        usleep(90_000)
    } while Date() < deadline
    return nil
}

app.activate(options: [.activateAllWindows])
usleep(300_000)
postShortcut()

guard waitUntil(
    timeout: 4,
    condition: { openFiles().contains("pet_rhythm_start_") }
) else {
    fputs("没有检测到节拍开场语音。\n", stderr)
    exit(3)
}
guard waitUntil(
    timeout: 9,
    condition: { !openFiles().contains("pet_rhythm_start_") }
) else {
    fputs("节拍开场语音没有按时结束。\n", stderr)
    exit(4)
}

usleep(225_000)
guard let bounds = petBounds() else {
    fputs("节拍开始后没有找到迷你头像。\n", stderr)
    exit(5)
}
let target = CGPoint(
    x: bounds.midX,
    y: bounds.minY + min(58, bounds.height / 2)
)

for beat in 1...max(1, min(8, requestedHits)) {
    click(target)
    print("rhythm hit \(beat)")
    fflush(stdout)
    if beat < requestedHits {
        usleep(960_000)
    }
}

if requestedHits >= 8 {
    let visible = NSScreen.main?.visibleFrame
        ?? CGRect(x: 0, y: 0, width: 1_280, height: 641)
    guard let expanded = waitForWindow(timeout: 3.2, matching: {
        $0.width >= visible.width * 0.80
            && $0.height >= visible.height * 0.80
    }) else {
        fputs("八拍完成后没有出现接近全屏的奖励画面。\n", stderr)
        exit(6)
    }
    guard let restored = waitForWindow(timeout: 14, matching: {
        $0.width <= 160 && $0.height <= 200
    }) else {
        fputs("节拍奖励播放后没有回收到迷你头像。\n", stderr)
        exit(7)
    }
    print("rhythm-game reward expanded: \(Int(expanded.width))x\(Int(expanded.height))")
    print("rhythm-game reward restored: \(Int(restored.width))x\(Int(restored.height))")
}

print("rhythm-game sequence completed")
