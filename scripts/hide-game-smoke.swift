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
let requested = CommandLine.arguments.dropFirst().first ?? "5"
let shouldOnlyToggle = requested == "toggle"
let finds = Int(requested) ?? 5
let keyCodeK: CGKeyCode = 40

func postShortcut() {
    let down = CGEvent(
        keyboardEventSource: source,
        virtualKey: keyCodeK,
        keyDown: true
    )!
    down.flags = [.maskCommand, .maskShift]
    down.post(tap: .cghidEventTap)
    let up = CGEvent(
        keyboardEventSource: source,
        virtualKey: keyCodeK,
        keyDown: false
    )!
    up.flags = [.maskCommand, .maskShift]
    up.post(tap: .cghidEventTap)
}

postShortcut()
usleep(1_000_000)

if shouldOnlyToggle {
    print("hide-game toggled")
    exit(0)
}

func visibleScreenBounds() -> CGRect {
    guard let screen = NSScreen.main else {
        return CGDisplayBounds(CGMainDisplayID())
    }
    let frame = screen.frame
    let visible = screen.visibleFrame
    return CGRect(
        x: visible.minX,
        y: frame.maxY - visible.maxY,
        width: visible.width,
        height: visible.height
    )
}

func visiblePetBounds() -> CGRect? {
    let windows = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly],
        kCGNullWindowID
    ) as? [[String: Any]] ?? []
    let visibleScreen = visibleScreenBounds()

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
        let windowBounds = CGRect(x: x, y: y, width: width, height: height)
        let visiblePart = windowBounds.intersection(visibleScreen)
        if !visiblePart.isNull, visiblePart.width >= 24, visiblePart.height >= 24 {
            return visiblePart
        }
    }
    return nil
}

func anyPetBounds() -> CGRect? {
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
            let bounds = CGRect(x: x, y: y, width: width, height: height)
            if predicate(bounds) { return bounds }
        }
        usleep(90_000)
    } while Date() < deadline
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
    usleep(55_000)
    let up = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseUp,
        mouseCursorPosition: point,
        mouseButton: .left
    )!
    up.post(tap: .cghidEventTap)
}

for round in 1...max(1, finds) {
    guard let bounds = visiblePetBounds() else {
        fputs("第 \(round) 次没有找到露出的头像。\n", stderr)
        exit(3)
    }
    let target = CGPoint(x: bounds.midX, y: bounds.midY)
    click(target)
    print(
        "found \(round) at \(Int(target.x)),\(Int(target.y)) "
            + "visible=\(Int(bounds.width))x\(Int(bounds.height))"
    )
    fflush(stdout)
    usleep(950_000)
}

if finds >= 5 {
    let visible = NSScreen.main?.visibleFrame
        ?? CGRect(x: 0, y: 0, width: 1_280, height: 641)
    guard let expanded = waitForWindow(timeout: 3.2, matching: {
        $0.width >= visible.width * 0.80
            && $0.height >= visible.height * 0.80
    }) else {
        fputs("五次找到后没有出现接近全屏的奖励画面。\n", stderr)
        exit(6)
    }
    guard let restored = waitForWindow(timeout: 14, matching: {
        $0.width <= 160 && $0.height <= 200
    }) ?? anyPetBounds() else {
        fputs("躲猫猫奖励播放后没有回收到迷你头像。\n", stderr)
        exit(7)
    }
    print("hide-game reward expanded: \(Int(expanded.width))x\(Int(expanded.height))")
    print("hide-game reward restored: \(Int(restored.width))x\(Int(restored.height))")
}

print("hide-game sequence completed")
