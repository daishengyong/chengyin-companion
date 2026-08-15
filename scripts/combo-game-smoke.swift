import AppKit
import CoreGraphics
import Foundation

guard let app = NSRunningApplication.runningApplications(
    withBundleIdentifier: "local.zidong.chengyin-companion"
).first else {
    fputs("澄音没有运行。\n", stderr)
    exit(2)
}

app.activate(options: [.activateAllWindows])
usleep(350_000)

let source = CGEventSource(stateID: .hidSystemState)
let keyCodeJ: CGKeyCode = 38

func postShortcut() {
    let down = CGEvent(
        keyboardEventSource: source,
        virtualKey: keyCodeJ,
        keyDown: true
    )!
    down.flags = [.maskCommand, .maskShift]
    down.post(tap: .cghidEventTap)
    let up = CGEvent(
        keyboardEventSource: source,
        virtualKey: keyCodeJ,
        keyDown: false
    )!
    up.flags = [.maskCommand, .maskShift]
    up.post(tap: .cghidEventTap)
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

func postMouse(_ type: CGEventType, at point: CGPoint) {
    let event = CGEvent(
        mouseEventSource: source,
        mouseType: type,
        mouseCursorPosition: point,
        mouseButton: .left
    )!
    event.post(tap: .cghidEventTap)
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

postShortcut()
usleep(900_000)

guard let bounds = petBounds() else {
    fputs("连招开始后没有找到迷你头像。\n", stderr)
    exit(3)
}
let start = CGPoint(x: bounds.midX, y: bounds.midY)

postMouse(.leftMouseDown, at: start)
usleep(55_000)
postMouse(.leftMouseUp, at: start)
usleep(900_000)
print("combo step 1: tap")

postMouse(.leftMouseDown, at: start)
usleep(940_000)
postMouse(.leftMouseUp, at: start)
usleep(650_000)
print("combo step 2: hold")

let end = CGPoint(x: start.x + 92, y: max(30, start.y - 58))
postMouse(.leftMouseDown, at: start)
for index in 1...5 {
    let progress = CGFloat(index) / 5
    let point = CGPoint(
        x: start.x + (end.x - start.x) * progress,
        y: start.y + (end.y - start.y) * progress
    )
    postMouse(.leftMouseDragged, at: point)
    usleep(7_000)
}
postMouse(.leftMouseUp, at: end)
print("combo step 3: fling")

let visible = NSScreen.main?.visibleFrame
    ?? CGRect(x: 0, y: 0, width: 1_280, height: 641)
guard let expanded = waitForWindow(timeout: 3.2, matching: {
    $0.width >= visible.width * 0.80
        && $0.height >= visible.height * 0.80
}) else {
    fputs("连招完成后没有出现接近全屏的奖励画面。\n", stderr)
    exit(6)
}
guard let restored = waitForWindow(timeout: 14, matching: {
    $0.width <= 160 && $0.height <= 200
}) else {
    fputs("连招奖励播放后没有回收到迷你头像。\n", stderr)
    exit(7)
}
print("combo-game reward expanded: \(Int(expanded.width))x\(Int(expanded.height))")
print("combo-game reward restored: \(Int(restored.width))x\(Int(restored.height))")
print("combo-game sequence completed")
