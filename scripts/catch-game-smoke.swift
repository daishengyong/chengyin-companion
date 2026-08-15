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
let arguments = Array(CommandLine.arguments.dropFirst())
let usesAlreadyActiveGame = arguments.contains("--active")
let shouldOnlyToggle = arguments.contains("toggle")
let catches = arguments.compactMap(Int.init).first ?? 5
let keyCodeG: CGKeyCode = 5

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
    let move = CGEvent(
        mouseEventSource: source,
        mouseType: .mouseMoved,
        mouseCursorPosition: point,
        mouseButton: .left
    )!
    move.post(tap: .cghidEventTap)
    usleep(80_000)
    let down = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseDown,
        mouseCursorPosition: point,
        mouseButton: .left
    )!
    down.setIntegerValueField(.mouseEventClickState, value: 1)
    down.post(tap: .cghidEventTap)
    usleep(55_000)
    let up = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseUp,
        mouseCursorPosition: point,
        mouseButton: .left
    )!
    up.setIntegerValueField(.mouseEventClickState, value: 1)
    up.post(tap: .cghidEventTap)
}

func movePointer(_ point: CGPoint) {
    let move = CGEvent(
        mouseEventSource: source,
        mouseType: .mouseMoved,
        mouseCursorPosition: point,
        mouseButton: .left
    )!
    move.post(tap: .cghidEventTap)
}

func postCatchShortcut() {
    for isDown in [true, false] {
        let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCodeG,
            keyDown: isDown
        )!
        event.flags = [.maskCommand, .maskShift]
        event.post(tap: .cghidEventTap)
    }
}

func waitForPetMoved(
    from previous: CGRect,
    timeout: TimeInterval = 2.2
) -> CGRect? {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        if let bounds = petBounds(),
           hypot(bounds.midX - previous.midX, bounds.midY - previous.midY) > 36 {
            return bounds
        }
        usleep(90_000)
    } while Date() < deadline
    return nil
}

func waitForReward(timeout: TimeInterval = 3.0) -> CGRect? {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []
        var candidates: [CGRect] = []
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
            candidates.append(CGRect(x: x, y: y, width: width, height: height))
        }
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        if let fullscreenReward = candidates.max(by: {
            $0.width * $0.height < $1.width * $1.height
        }), visibleFrames.contains(where: { visible in
            fullscreenReward.width >= visible.width * 0.80
                && fullscreenReward.height >= visible.height * 0.80
        }) {
            return fullscreenReward
        }
        usleep(90_000)
    } while Date() < deadline
    return nil
}

func waitForRestoredPet(timeout: TimeInterval = 14.0) -> CGRect? {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        if let bounds = petBounds() {
            return bounds
        }
        usleep(120_000)
    } while Date() < deadline
    return nil
}

var ownsActiveGame = usesAlreadyActiveGame

func stopOwnedGame() {
    guard ownsActiveGame else { return }
    postCatchShortcut()
    usleep(250_000)
    ownsActiveGame = false
}

if !usesAlreadyActiveGame {
    guard let restingPet = petBounds() else {
        fputs("抓住我开始前没有找到迷你头像。\n", stderr)
        exit(3)
    }
    movePointer(CGPoint(x: restingPet.midX, y: restingPet.midY))
    usleep(100_000)
    postCatchShortcut()
    ownsActiveGame = true
    if waitForPetMoved(from: restingPet) == nil {
        // A previous failed audit may still own a live game; the first shortcut
        // then stops it. Toggle once more and require the game-owned move.
        ownsActiveGame = false
        guard let settledPet = petBounds() else {
            fputs("抓住我切换后没有找到迷你头像。\n", stderr)
            exit(3)
        }
        movePointer(CGPoint(x: settledPet.midX, y: settledPet.midY))
        postCatchShortcut()
        ownsActiveGame = true
        guard waitForPetMoved(from: settledPet) != nil else {
            stopOwnedGame()
            fputs("抓住我没有进入可移动计分状态。\n", stderr)
            exit(3)
        }
    }
}

if shouldOnlyToggle {
    print("catch-game toggled")
    exit(0)
}

var verifiedScore = 0
var observedReward: CGRect?
while verifiedScore < min(catches, 5) {
    let nextScore = verifiedScore + 1
    var registered = false
    for attempt in 1...3 {
        guard let bounds = petBounds() else {
            fputs("第 \(nextScore) 次没有找到迷你头像。\n", stderr)
            exit(4)
        }
        let target = CGPoint(x: bounds.midX, y: bounds.minY + 56)
        click(target)
        if nextScore < 5, waitForPetMoved(from: bounds) != nil {
            verifiedScore = nextScore
            print("verified catch \(nextScore)/5 at \(Int(target.x)),\(Int(target.y))")
            fflush(stdout)
            registered = true
            usleep(460_000)
            break
        }
        if nextScore >= 5, let reward = waitForReward(timeout: 2.8) {
            verifiedScore = 5
            observedReward = reward
            print("verified catch 5/5 from expanded reward state")
            fflush(stdout)
            registered = true
            break
        }
        fputs("第 \(nextScore) 次点击未计分，正在重试（\(attempt)/3）。\n", stderr)
    }
    guard registered else {
        stopOwnedGame()
        exit(5)
    }
}

if verifiedScore >= 5 {
    guard let reward = observedReward ?? waitForReward() else {
        stopOwnedGame()
        fputs("五连抓已计分，但没有展开到接近显示器可用区域的奖励画面。\n", stderr)
        exit(6)
    }
    print(
        "catch-game reward expanded: "
            + "\(Int(reward.width))x\(Int(reward.height))"
    )
    guard let restored = waitForRestoredPet() else {
        stopOwnedGame()
        fputs("大幅奖励播放后没有回收到迷你头像。\n", stderr)
        exit(7)
    }
    print(
        "catch-game reward restored: "
            + "\(Int(restored.width))x\(Int(restored.height))"
    )
}

ownsActiveGame = false
print("catch-game sequence verified at \(verifiedScore)/5")
