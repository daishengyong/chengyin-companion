import CoreGraphics
import Foundation

enum ClickMode: String {
    case single
    case double
}

guard CommandLine.arguments.count == 2,
      let mode = ClickMode(rawValue: CommandLine.arguments[1])
else {
    fputs("usage: swift scripts/pet-click-smoke.swift single|double\n", stderr)
    exit(2)
}

let windows = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly],
    kCGNullWindowID
) as? [[String: Any]] ?? []

func windowBounds(_ window: [String: Any]) -> CGRect? {
    guard let dictionary = window[kCGWindowBounds as String] as? [String: Any],
          let x = (dictionary["X"] as? NSNumber)?.doubleValue,
          let y = (dictionary["Y"] as? NSNumber)?.doubleValue,
          let width = (dictionary["Width"] as? NSNumber)?.doubleValue,
          let height = (dictionary["Height"] as? NSNumber)?.doubleValue
    else {
        return nil
    }
    return CGRect(x: x, y: y, width: width, height: height)
}

guard let window = windows.first(where: {
    guard $0[kCGWindowOwnerName as String] as? String == "澄音",
          let bounds = windowBounds($0)
    else {
        return false
    }
    return bounds.width <= 160 && bounds.height <= 200
}),
let bounds = windowBounds(window)
else {
    fputs("澄音当前不是头像窗口，停止点击。\n", stderr)
    exit(3)
}

let point = CGPoint(
    x: bounds.midX,
    y: bounds.minY + min(58, bounds.height / 2)
)
let source = CGEventSource(stateID: .hidSystemState)

func postClick(count: Int64) {
    let down = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseDown,
        mouseCursorPosition: point,
        mouseButton: .left
    )!
    down.setIntegerValueField(.mouseEventClickState, value: count)
    down.post(tap: .cghidEventTap)
    usleep(65_000)

    let up = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseUp,
        mouseCursorPosition: point,
        mouseButton: .left
    )!
    up.setIntegerValueField(.mouseEventClickState, value: count)
    up.post(tap: .cghidEventTap)
}

postClick(count: 1)
if mode == .double {
    usleep(120_000)
    postClick(count: 2)
}

print("\(mode.rawValue) click posted at \(Int(point.x)),\(Int(point.y))")
