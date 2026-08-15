import AppKit
import CoreGraphics
import Foundation

guard let app = NSRunningApplication.runningApplications(
    withBundleIdentifier: "local.zidong.chengyin-companion"
).first else {
    fputs("澄音没有运行。\n", stderr)
    exit(2)
}

let source = CGEventSource(stateID: .hidSystemState)
let keyCodeF: CGKeyCode = 3
let processIdentifier = app.processIdentifier

func postShortcut() {
    for isDown in [true, false] {
        let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCodeF,
            keyDown: isDown
        )!
        event.flags = [.maskCommand, .maskShift]
        event.post(tap: .cghidEventTap)
    }
}

func companionWindowBounds() -> CGRect? {
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
            width >= 540,
            height >= 500
        else { continue }
        return CGRect(x: x, y: y, width: width, height: height)
    }
    return nil
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

func postMouse(_ type: CGEventType, at point: CGPoint) {
    let event = CGEvent(
        mouseEventSource: source,
        mouseType: type,
        mouseCursorPosition: point,
        mouseButton: .left
    )!
    event.post(tap: .cghidEventTap)
}

func drag(from start: CGPoint, to target: CGPoint) {
    postMouse(.leftMouseDown, at: start)
    usleep(60_000)
    for index in 1...18 {
        let progress = CGFloat(index) / 18
        postMouse(
            .leftMouseDragged,
            at: CGPoint(
                x: start.x + (target.x - start.x) * progress,
                y: start.y + (target.y - start.y) * progress
            )
        )
        usleep(16_000)
    }
    postMouse(.leftMouseUp, at: target)
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

app.activate(options: [.activateAllWindows])
usleep(300_000)
if !CommandLine.arguments.dropFirst().contains("continue") {
    postShortcut()
}
usleep(800_000)

guard let window = companionWindowBounds() else {
    fputs("投喂开始后没有找到半身窗口。\n", stderr)
    exit(3)
}

let stage = CGRect(
    x: window.minX + 20,
    y: window.minY + 136,
    width: 520,
    height: 292.5
)
let target = CGPoint(
    x: stage.midX,
    y: stage.minY + stage.height * 0.43
)

let starts = [
    CGPoint(x: stage.minX + 58, y: stage.minY + stage.height - 48),
    CGPoint(x: stage.maxX - 58, y: stage.minY + stage.height - 48)
]

if CommandLine.arguments.dropFirst().contains("miss") {
    for (index, start) in starts.enumerated() {
        drag(
            from: start,
            to: CGPoint(x: start.x, y: start.y - 58)
        )
        usleep(420_000)
        if openFiles().contains("pet_feed_miss_") {
            print("feed miss detected after side \(index + 1)")
            exit(0)
        }
    }
    fputs("没有检测到投喂偏离语音。\n", stderr)
    exit(5)
}

for attempt in 1...6 {
    drag(from: starts[(attempt - 1) % starts.count], to: target)
    usleep(520_000)
    if openFiles().contains("companion-head-scene-kitchen.mov") {
        let visible = NSScreen.main?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1_280, height: 641)
        guard let expanded = waitForWindow(timeout: 3.2, matching: {
            $0.width >= visible.width * 0.80
                && $0.height >= visible.height * 0.80
        }) else {
            fputs("投喂完成后没有出现接近全屏的奖励画面。\n", stderr)
            exit(6)
        }
        guard let restored = waitForWindow(timeout: 14, matching: {
            $0.width <= 160 && $0.height <= 200
        }) else {
            fputs("投喂奖励播放后没有回收到迷你头像。\n", stderr)
            exit(7)
        }
        print("feed reward detected after attempt \(attempt)")
        print("feed-game reward expanded: \(Int(expanded.width))x\(Int(expanded.height))")
        print("feed-game reward restored: \(Int(restored.width))x\(Int(restored.height))")
        exit(0)
    }
}

fputs("六次拖动后没有检测到厨房奖励视频。\n", stderr)
exit(4)
