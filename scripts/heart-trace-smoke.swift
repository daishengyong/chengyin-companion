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
let keyCodeH: CGKeyCode = 4
let shouldStopEarly = CommandLine.arguments.dropFirst().first == "partial"
let guidePoints = [
    CGPoint(x: 0.00, y: -0.68),
    CGPoint(x: -0.48, y: -0.28),
    CGPoint(x: -0.72, y: 0.18),
    CGPoint(x: -0.46, y: 0.64),
    CGPoint(x: 0.00, y: 0.32),
    CGPoint(x: 0.46, y: 0.64),
    CGPoint(x: 0.72, y: 0.18),
    CGPoint(x: 0.48, y: -0.28),
    CGPoint(x: 0.00, y: -0.68)
]

func postShortcut() {
    for isDown in [true, false] {
        let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCodeH,
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
            width >= 500,
            height >= 500
        else { continue }
        return CGRect(x: x, y: y, width: width, height: height)
    }
    return nil
}

func anyCompanionWindowBounds() -> CGRect? {
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
        if let bounds = anyCompanionWindowBounds(), predicate(bounds) {
            return bounds
        }
        usleep(50_000)
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

let initialWindow = anyCompanionWindowBounds()
postShortcut()
usleep(900_000)

guard let window = companionWindowBounds() else {
    fputs("画心挑战开始后没有找到半身窗口。\n", stderr)
    exit(3)
}

let stage = CGRect(
    x: window.maxX - 540,
    y: window.maxY - 303.75,
    width: 540,
    height: 303.75
)
func screenPoint(_ point: CGPoint) -> CGPoint {
    CGPoint(
        x: stage.minX + (point.x + 1) * 0.5 * stage.width,
        y: stage.minY + (1 - point.y) * 0.5 * stage.height
    )
}

let start = screenPoint(guidePoints[0])
postMouse(.leftMouseDown, at: start)
usleep(45_000)

var previous = start
let testPoints = shouldStopEarly
    ? Array(guidePoints.prefix(3))
    : guidePoints
for targetPoint in testPoints {
    let target = screenPoint(targetPoint)
    for index in 1...14 {
        let progress = CGFloat(index) / 14
        let point = CGPoint(
            x: previous.x + (target.x - previous.x) * progress,
            y: previous.y + (target.y - previous.y) * progress
        )
        postMouse(.leftMouseDragged, at: point)
        usleep(11_000)
    }
    previous = target
}
postMouse(.leftMouseUp, at: previous)

if !shouldStopEarly {
    let visible = NSScreen.main?.visibleFrame
        ?? CGRect(x: 0, y: 0, width: 1_280, height: 641)
    guard let expanded = waitForWindow(timeout: 2.5, matching: {
        $0.width >= visible.width * 0.80
            && $0.height >= visible.height * 0.80
    }) else {
        fputs("画心轨迹没有触发大幅奖励画面。\n", stderr)
        exit(6)
    }
    guard let initialWindow,
          let restored = waitForWindow(timeout: 9, matching: {
              abs($0.width - initialWindow.width) <= 2
                  && abs($0.height - initialWindow.height) <= 2
          }) else {
        fputs("画心奖励播放后没有回到原来的窗口大小。\n", stderr)
        exit(7)
    }
    print(
        "heart-game reward expanded: "
            + "\(Int(expanded.width))x\(Int(expanded.height))"
    )
    print(
        "heart-game reward restored: "
            + "\(Int(restored.width))x\(Int(restored.height))"
    )
}

print(
    shouldStopEarly
        ? "heart-trace partial sequence completed"
        : "heart-trace sequence completed"
)
