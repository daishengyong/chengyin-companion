import AppKit
import CoreGraphics
import Foundation

private struct WindowSize: Encodable {
    let width: Int
    let height: Int

    init(_ rect: CGRect) {
        width = Int(rect.width.rounded())
        height = Int(rect.height.rounded())
    }
}

private struct DirectPlayWindowReceipt: Encodable {
    let schemaVersion = 1
    let contract = "chengyin.direct-play-window/v1"
    let status: String
    let code: String?
    let message: String
    let recoveryAction: String?
    let initialPet: WindowSize?
    let singleClickExpanded: WindowSize?
    let singleClickRestored: WindowSize?
    let palette: WindowSize?
    let paletteFullyVisible: Bool
    let actionExpanded: WindowSize?
    let actionRestored: WindowSize?
}

private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
}()

private func publish(_ receipt: DirectPlayWindowReceipt, exitCode: Int32) -> Never {
    FileHandle.standardOutput.write((try? encoder.encode(receipt)) ?? Data("{}".utf8))
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(exitCode)
}

private func windowBounds() -> CGRect? {
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
            width > 0,
            height > 0
        else { continue }
        return CGRect(x: x, y: y, width: width, height: height)
    }
    return nil
}

private func waitForWindow(
    timeout: TimeInterval,
    matching predicate: (CGRect) -> Bool
) -> CGRect? {
    let deadline = Date().addingTimeInterval(timeout)
    var previous: CGRect?
    var stableSampleCount = 0
    repeat {
        if let bounds = windowBounds(), predicate(bounds) {
            if let previous,
               abs(previous.width - bounds.width) <= 1,
               abs(previous.height - bounds.height) <= 1,
               abs(previous.minX - bounds.minX) <= 1,
               abs(previous.minY - bounds.minY) <= 1 {
                stableSampleCount += 1
            } else {
                stableSampleCount = 1
            }
            previous = bounds
            if stableSampleCount >= 3 {
                return bounds
            }
        } else {
            previous = nil
            stableSampleCount = 0
        }
        usleep(80_000)
    } while Date() < deadline
    return nil
}

private func isPet(_ bounds: CGRect) -> Bool {
    bounds.width <= 160 && bounds.height <= 200
}

private func isStage(_ bounds: CGRect) -> Bool {
    bounds.width >= 500 && bounds.height >= 300
        && !isPalette(bounds)
}

private func isPalette(_ bounds: CGRect) -> Bool {
    // The palette is intentionally one 420-point upward-opening canvas. Keep
    // the live verifier synchronized with the shared layout policy so a valid
    // no-scroll panel is not misreported as a click failure.
    (590...610).contains(bounds.width) && (410...430).contains(bounds.height)
}

private let eventSource = CGEventSource(stateID: .hidSystemState)

private func movePointer(_ point: CGPoint) {
    let move = CGEvent(
        mouseEventSource: eventSource,
        mouseType: .mouseMoved,
        mouseCursorPosition: point,
        mouseButton: .left
    )!
    move.post(tap: .cghidEventTap)
}

private func click(_ point: CGPoint) {
    movePointer(point)
    usleep(80_000)
    for type in [CGEventType.leftMouseDown, .leftMouseUp] {
        let event = CGEvent(
            mouseEventSource: eventSource,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: .left
        )!
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.post(tap: .cghidEventTap)
        usleep(45_000)
    }
}

private func postHeadShortcut() {
    // Cmd-Shift-1 is the documented head-mode shortcut.
    let keyCodeOne: CGKeyCode = 18
    for isDown in [true, false] {
        let event = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: keyCodeOne,
            keyDown: isDown
        )!
        event.flags = [.maskCommand, .maskShift]
        event.post(tap: .cghidEventTap)
    }
}

private func activeDisplayBounds() -> [CGRect] {
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
        return []
    }
    var displays = Array(repeating: CGDirectDisplayID(), count: Int(count))
    guard CGGetActiveDisplayList(count, &displays, &count) == .success else {
        return []
    }
    return displays.prefix(Int(count)).map(CGDisplayBounds)
}

private func isFullyVisible(_ bounds: CGRect) -> Bool {
    activeDisplayBounds().contains { display in
        display.insetBy(dx: -1, dy: -1).contains(bounds)
    }
}

private func currentSessionIsLocked() -> Bool {
    guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else {
        return false
    }
    return (session["CGSSessionScreenIsLocked"] as? NSNumber)?.boolValue
        ?? (session["CGSSessionScreenIsLocked"] as? Bool)
        ?? false
}

private func cleanupToPet() {
    if let bounds = windowBounds(), isPalette(bounds) {
        // The in-window close control is near the palette's top-right corner.
        click(CGPoint(x: bounds.maxX - 34, y: bounds.minY + 36))
        usleep(250_000)
    }
    postHeadShortcut()
    usleep(350_000)
}

private func fail(
    code: String,
    message: String,
    recoveryAction: String,
    initialPet: CGRect? = nil,
    singleExpanded: CGRect? = nil,
    singleRestored: CGRect? = nil,
    palette: CGRect? = nil,
    paletteFullyVisible: Bool = false,
    actionExpanded: CGRect? = nil,
    actionRestored: CGRect? = nil
) -> Never {
    cleanupToPet()
    publish(
        DirectPlayWindowReceipt(
            status: "FAIL",
            code: code,
            message: message,
            recoveryAction: recoveryAction,
            initialPet: initialPet.map(WindowSize.init),
            singleClickExpanded: singleExpanded.map(WindowSize.init),
            singleClickRestored: singleRestored.map(WindowSize.init),
            palette: palette.map(WindowSize.init),
            paletteFullyVisible: paletteFullyVisible,
            actionExpanded: actionExpanded.map(WindowSize.init),
            actionRestored: actionRestored.map(WindowSize.init)
        ),
        exitCode: 1
    )
}

if currentSessionIsLocked() {
    publish(
        DirectPlayWindowReceipt(
            status: "PENDING",
            code: "UI_DIRECT_PLAY_GUI_SESSION_LOCKED",
            message: "The local GUI session is locked, so pointer input cannot prove direct interaction.",
            recoveryAction: "Unlock the current Mac session, leave one verified companion preview running, and retry.",
            initialPet: nil,
            singleClickExpanded: nil,
            singleClickRestored: nil,
            palette: nil,
            paletteFullyVisible: false,
            actionExpanded: nil,
            actionRestored: nil
        ),
        exitCode: 2
    )
}

guard let app = NSRunningApplication.runningApplications(
    withBundleIdentifier: "local.zidong.chengyin-companion"
).first else {
    fail(
        code: "UI_DIRECT_PLAY_RUNTIME_UNAVAILABLE",
        message: "No Chengyin Companion process is available for direct-play audit.",
        recoveryAction: "Launch one verified current application, select audiovisual mode, and retry."
    )
}

app.activate(options: [.activateAllWindows])
usleep(300_000)
cleanupToPet()
guard let initialPet = waitForWindow(timeout: 2.5, matching: isPet) else {
    fail(
        code: "UI_DIRECT_PLAY_RUNTIME_UNAVAILABLE",
        message: "The running application did not expose a stable pet window.",
        recoveryAction: "Close transient panels, switch to the pet presentation, and retry."
    )
}

click(CGPoint(x: initialPet.midX, y: initialPet.minY + min(52, initialPet.height / 2)))
guard let singleExpanded = waitForWindow(timeout: 3.2, matching: isStage) else {
    fail(
        code: "UI_DIRECT_PLAY_EXPANSION_FAILED",
        message: "A direct pet click did not expand into an audiovisual stage.",
        recoveryAction: "Choose audiovisual playback, disable reduced dynamic effects, then retry the direct-play audit.",
        initialPet: initialPet
    )
}
guard let singleRestored = waitForWindow(timeout: 10, matching: isPet) else {
    fail(
        code: "UI_DIRECT_PLAY_RESTORATION_FAILED",
        message: "The direct pet response did not restore the original pet presentation.",
        recoveryAction: "Switch to pet mode, restart the current build, and rerun the audit.",
        initialPet: initialPet,
        singleExpanded: singleExpanded
    )
}
// Hover immediately after the stable return. Automatic cues resume after a
// bounded handoff, so waiting here could let an unrelated reminder own the
// stage before the audit reaches the toolbar.
let interactivePet = singleRestored
let wandPoint = CGPoint(x: interactivePet.maxX - 18, y: interactivePet.maxY - 15)
movePointer(wandPoint)
usleep(500_000)
click(wandPoint)
guard waitForWindow(timeout: 2.5, matching: isPalette) != nil else {
    fail(
        code: "UI_DIRECT_PLAY_PALETTE_FAILED",
        message: "The magic-wand control did not open the bounded play palette.",
        recoveryAction: "Return to pet mode, ensure the toolbar is visible, and retry.",
        initialPet: initialPet,
        singleExpanded: singleExpanded,
        singleRestored: singleRestored
    )
}
usleep(450_000)
guard let palette = windowBounds(), isPalette(palette) else {
    fail(
        code: "UI_DIRECT_PLAY_PALETTE_FAILED",
        message: "The magic-wand play palette did not settle into its bounded layout.",
        recoveryAction: "Close the transient panel, return to pet mode, and retry.",
        initialPet: initialPet,
        singleExpanded: singleExpanded,
        singleRestored: singleRestored
    )
}
let paletteFullyVisible = isFullyVisible(palette)
guard paletteFullyVisible else {
    fail(
        code: "UI_DIRECT_PLAY_PALETTE_CLIPPED",
        message: "The magic-wand play palette extends beyond every active display.",
        recoveryAction: "Move the pet onto a display with enough visible space, then retry.",
        initialPet: initialPet,
        singleExpanded: singleExpanded,
        singleRestored: singleRestored,
        palette: palette
    )
}

// Select the fourth bounded category, then its first three-column item.
click(CGPoint(x: palette.minX + 305, y: palette.minY + 72))
usleep(220_000)
click(CGPoint(x: palette.minX + 150, y: palette.minY + 112))
guard let actionExpanded = waitForWindow(timeout: 3.2, matching: isStage) else {
    fail(
        code: "UI_DIRECT_PLAY_EXPANSION_FAILED",
        message: "A magic-wand action did not expand into an audiovisual stage.",
        recoveryAction: "Choose audiovisual playback and retry a bundled action from the play palette.",
        initialPet: initialPet,
        singleExpanded: singleExpanded,
        singleRestored: singleRestored,
        palette: palette,
        paletteFullyVisible: true
    )
}
guard let actionRestored = waitForWindow(timeout: 10, matching: isPet) else {
    fail(
        code: "UI_DIRECT_PLAY_RESTORATION_FAILED",
        message: "The magic-wand action did not restore the original pet presentation.",
        recoveryAction: "Switch to pet mode, restart the current build, and rerun the audit.",
        initialPet: initialPet,
        singleExpanded: singleExpanded,
        singleRestored: singleRestored,
        palette: palette,
        paletteFullyVisible: true,
        actionExpanded: actionExpanded
    )
}

publish(
    DirectPlayWindowReceipt(
        status: "PASS",
        code: nil,
        message: "Direct click, bounded magic-wand palette, action expansion and pet restoration passed.",
        recoveryAction: nil,
        initialPet: WindowSize(initialPet),
        singleClickExpanded: WindowSize(singleExpanded),
        singleClickRestored: WindowSize(singleRestored),
        palette: WindowSize(palette),
        paletteFullyVisible: true,
        actionExpanded: WindowSize(actionExpanded),
        actionRestored: WindowSize(actionRestored)
    ),
    exitCode: 0
)
