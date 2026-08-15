import CoreGraphics
import Foundation

enum GestureMode: String {
    case hover
    case longPress = "long-press"
    case shortDrag = "short-drag"
    case longDrag = "long-drag"
    case dragLeft = "drag-left"
    case dockLeft = "dock-left"
    case flingUp = "fling-up"
}

guard CommandLine.arguments.count == 2,
      let mode = GestureMode(rawValue: CommandLine.arguments[1])
else {
    fputs(
        "usage: swift scripts/pet-gesture-smoke.swift hover|long-press|short-drag|long-drag|drag-left|dock-left|fling-up\n",
        stderr
    )
    exit(2)
}

let windows = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly],
    kCGNullWindowID
) as? [[String: Any]] ?? []

func windowBounds(_ window: [String: Any]) -> CGRect? {
    guard
        let value = window[kCGWindowBounds as String] as? [String: Any],
        let x = (value["X"] as? NSNumber)?.doubleValue,
        let y = (value["Y"] as? NSNumber)?.doubleValue,
        let width = (value["Width"] as? NSNumber)?.doubleValue,
        let height = (value["Height"] as? NSNumber)?.doubleValue
    else { return nil }
    return CGRect(x: x, y: y, width: width, height: height)
}

guard
    let window = windows.first(where: {
        guard $0[kCGWindowOwnerName as String] as? String == "澄音",
              let bounds = windowBounds($0)
        else { return false }
        return bounds.width <= 160 && bounds.height <= 200
    }),
    let bounds = windowBounds(window)
else {
    fputs("澄音当前不是头像窗口，停止手势测试。\n", stderr)
    exit(3)
}

let start = CGPoint(
    x: bounds.midX,
    y: bounds.minY + min(58, bounds.height / 2)
)
let source = CGEventSource(stateID: .hidSystemState)

func post(_ type: CGEventType, at point: CGPoint) {
    let event = CGEvent(
        mouseEventSource: source,
        mouseType: type,
        mouseCursorPosition: point,
        mouseButton: .left
    )!
    event.post(tap: .cghidEventTap)
}

func drag(to end: CGPoint, steps: Int, pause: useconds_t) {
    post(.leftMouseDown, at: start)
    for index in 1...steps {
        let progress = CGFloat(index) / CGFloat(steps)
        let point = CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
        post(.leftMouseDragged, at: point)
        usleep(pause)
    }
    post(.leftMouseUp, at: end)
}

switch mode {
case .hover:
    post(.mouseMoved, at: start)
    usleep(900_000)
case .longPress:
    post(.leftMouseDown, at: start)
    usleep(940_000)
    post(.leftMouseUp, at: start)
case .shortDrag:
    drag(
        to: CGPoint(x: start.x + 15, y: start.y + 4),
        steps: 8,
        pause: 24_000
    )
case .longDrag:
    drag(
        to: CGPoint(x: start.x - 120, y: start.y + 36),
        steps: 28,
        pause: 24_000
    )
case .dragLeft:
    drag(
        to: CGPoint(x: 22, y: start.y),
        steps: 24,
        pause: 18_000
    )
case .dockLeft:
    drag(
        to: CGPoint(x: 22, y: start.y),
        steps: 48,
        pause: 42_000
    )
case .flingUp:
    drag(
        to: CGPoint(x: start.x + 36, y: max(24, start.y - 230)),
        steps: 5,
        pause: 8_000
    )
}

print("\(mode.rawValue) posted from \(Int(start.x)),\(Int(start.y))")
