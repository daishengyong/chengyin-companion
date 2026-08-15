import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Vision

private struct WindowSnapshot: Encodable {
    let width: Int
    let height: Int
    let fullyVisible: Bool
}

private struct StepReceipt: Encodable {
    let number: Int
    let name: String
    let screenshot: String
    let window: WindowSnapshot
    let expectedEnglishCopy: [String]
    let recognizedEnglishCopy: [String]
    let accessibilityIdentifiers: [String]
    let status: String
}

private struct AuditReceipt: Encodable {
    let schemaVersion = 1
    let contract = "chengyin.english-first-use-visual-audit/v1"
    let status: String
    let code: String?
    let message: String
    let recoveryAction: String?
    let environment: String
    let locale: String
    let steps: [StepReceipt]
    let runtimeAccessibility: String
    let humanVoiceOverAudit: String
    let physicalCleanMacAudit: String
    let proofStrength: String
    let releaseState = "NOT_PUBLIC_RELEASE_READY"
}

private struct Arguments {
    let pid: pid_t
    let output: URL

    init() throws {
        var pid: pid_t?
        var output: URL?
        var index = 1
        while index < CommandLine.arguments.count {
            let argument = CommandLine.arguments[index]
            guard index + 1 < CommandLine.arguments.count else {
                throw AuditFailure.invalidArgument
            }
            let value = CommandLine.arguments[index + 1]
            switch argument {
            case "--pid":
                guard let parsed = Int32(value), parsed > 0 else {
                    throw AuditFailure.invalidArgument
                }
                pid = parsed
            case "--output":
                output = URL(fileURLWithPath: value, isDirectory: true)
            default:
                throw AuditFailure.invalidArgument
            }
            index += 2
        }
        guard let pid, let output else { throw AuditFailure.invalidArgument }
        self.pid = pid
        self.output = output
    }
}

private enum AuditFailure: Error {
    case invalidArgument
    case unsafeOutput
    case runtimeUnavailable
    case windowUnavailable
    case screenshotFailed
    case localeMismatch
    case interactionFailed

    var code: String {
        switch self {
        case .invalidArgument: "FIRST_USE_VISUAL_AUDIT_INVALID_ARGUMENT"
        case .unsafeOutput: "FIRST_USE_VISUAL_AUDIT_UNSAFE_OUTPUT"
        case .runtimeUnavailable: "FIRST_USE_VISUAL_AUDIT_RUNTIME_UNAVAILABLE"
        case .windowUnavailable: "FIRST_USE_VISUAL_AUDIT_WINDOW_UNAVAILABLE"
        case .screenshotFailed: "FIRST_USE_VISUAL_AUDIT_SCREENSHOT_FAILED"
        case .localeMismatch: "FIRST_USE_VISUAL_AUDIT_LOCALE_MISMATCH"
        case .interactionFailed: "FIRST_USE_VISUAL_AUDIT_INTERACTION_FAILED"
        }
    }

    var message: String {
        switch self {
        case .invalidArgument:
            "The English first-use audit arguments are invalid."
        case .unsafeOutput:
            "The English first-use audit output is not a safe local directory."
        case .runtimeUnavailable:
            "The isolated first-use application is not running."
        case .windowUnavailable:
            "The isolated first-use application did not expose a stable visible window."
        case .screenshotFailed:
            "A first-use walkthrough screenshot could not be captured or decoded."
        case .localeMismatch:
            "The visible first-use walkthrough did not contain the required English copy."
        case .interactionFailed:
            "The visible first-use walkthrough did not advance through the expected steps."
        }
    }

    var recoveryAction: String {
        switch self {
        case .invalidArgument:
            "Run the project wrapper instead of invoking the Swift driver directly."
        case .unsafeOutput:
            "Choose a new non-symbolic-link directory inside the audit output root."
        case .runtimeUnavailable:
            "Rebuild the current preview and rerun the isolated English first-use audit."
        case .windowUnavailable:
            "Close transient companion panels, keep one display available, and retry."
        case .screenshotFailed:
            "Verify existing screen-capture access, then rerun without requesting new permissions."
        case .localeMismatch:
            "Inspect the captured step, repair the English localization or layout, and retry."
        case .interactionFailed:
            "Inspect the last captured step and repair its gesture or accessibility target before retrying."
        }
    }
}

private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return encoder
}()

private func publish(_ receipt: AuditReceipt, exitCode: Int32) -> Never {
    let data = (try? encoder.encode(receipt)) ?? Data("{}".utf8)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(exitCode)
}

private struct WindowInfo {
    let id: CGWindowID
    let bounds: CGRect
}

private func windowInfo(pid: pid_t) -> WindowInfo? {
    let windows = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
    ) as? [[String: Any]] ?? []
    return windows.compactMap { value -> WindowInfo? in
        guard
            (value[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
            (value[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0 > 0,
            let identifier = (value[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
            let rawBounds = value[kCGWindowBounds as String] as? [String: Any],
            let x = (rawBounds["X"] as? NSNumber)?.doubleValue,
            let y = (rawBounds["Y"] as? NSNumber)?.doubleValue,
            let width = (rawBounds["Width"] as? NSNumber)?.doubleValue,
            let height = (rawBounds["Height"] as? NSNumber)?.doubleValue,
            width >= 120,
            height >= 120
        else { return nil }
        return WindowInfo(
            id: identifier,
            bounds: CGRect(x: x, y: y, width: width, height: height)
        )
    }.max { lhs, rhs in
        lhs.bounds.width * lhs.bounds.height < rhs.bounds.width * rhs.bounds.height
    }
}

private func waitForWindow(pid: pid_t, timeout: TimeInterval) -> WindowInfo? {
    let deadline = Date().addingTimeInterval(timeout)
    var previous: WindowInfo?
    var stableCount = 0
    repeat {
        if let current = windowInfo(pid: pid) {
            if let previous,
               abs(previous.bounds.width - current.bounds.width) <= 1,
               abs(previous.bounds.height - current.bounds.height) <= 1,
               abs(previous.bounds.minX - current.bounds.minX) <= 1,
               abs(previous.bounds.minY - current.bounds.minY) <= 1 {
                stableCount += 1
            } else {
                stableCount = 1
            }
            previous = current
            if stableCount >= 3 { return current }
        }
        usleep(100_000)
    } while Date() < deadline
    return nil
}

private func isFullyVisible(_ bounds: CGRect) -> Bool {
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
        return false
    }
    var displays = Array(repeating: CGDirectDisplayID(), count: Int(count))
    guard CGGetActiveDisplayList(count, &displays, &count) == .success else {
        return false
    }
    return displays.prefix(Int(count)).contains {
        CGDisplayBounds($0).insetBy(dx: -1, dy: -1).contains(bounds)
    }
}

private func capture(window: WindowInfo, to url: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    process.arguments = ["-x", "-l", String(window.id), url.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0,
          let attributes = try? FileManager.default.attributesOfItem(
            atPath: url.path
          ),
          (attributes[.size] as? NSNumber)?.intValue ?? 0 > 1_024 else {
        throw AuditFailure.screenshotFailed
    }
}

private func recognizedText(in url: URL) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["en-US"]
    let handler = VNImageRequestHandler(url: url, options: [:])
    try handler.perform([request])
    return (request.results ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")
}

private func normalized(_ value: String) -> String {
    value
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        .replacingOccurrences(of: "—", with: "-")
        .replacingOccurrences(of: "’", with: "'")
        .replacingOccurrences(of: "\n", with: " ")
}

private func textMatches(_ expected: String, in recognized: String) -> Bool {
    normalized(recognized).contains(normalized(expected))
}

private func axAttribute(
    _ element: AXUIElement,
    _ attribute: CFString
) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
        return nil
    }
    return value
}

private func accessibilityElements(
    for pid: pid_t,
    maximumCount: Int = 1_000
) -> [AXUIElement] {
    guard AXIsProcessTrusted() else { return [] }
    var queue = [AXUIElementCreateApplication(pid)]
    var result: [AXUIElement] = []
    while !queue.isEmpty, result.count < maximumCount {
        let element = queue.removeFirst()
        result.append(element)
        if let children = axAttribute(
            element,
            kAXChildrenAttribute as CFString
        ) as? [AXUIElement] {
            queue.append(contentsOf: children)
        }
    }
    return result
}

private func accessibilityIdentifier(_ element: AXUIElement) -> String? {
    axAttribute(element, "AXIdentifier" as CFString) as? String
}

private func elementBounds(_ element: AXUIElement) -> CGRect? {
    guard
        let rawPosition = axAttribute(
            element,
            kAXPositionAttribute as CFString
        ),
        let rawSize = axAttribute(
            element,
            kAXSizeAttribute as CFString
        ),
        CFGetTypeID(rawPosition) == AXValueGetTypeID(),
        CFGetTypeID(rawSize) == AXValueGetTypeID()
    else { return nil }
    let positionValue = rawPosition as! AXValue
    let sizeValue = rawSize as! AXValue
    var position = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(positionValue, .cgPoint, &position),
          AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }
    return CGRect(origin: position, size: size)
}

private func matchingIdentifiers(
    _ identifiers: [String],
    in elements: [AXUIElement]
) -> [String] {
    let available = Set(elements.compactMap(accessibilityIdentifier))
    return identifiers.filter(available.contains)
}

private let eventSource = CGEventSource(stateID: .hidSystemState)

private func click(_ point: CGPoint, count: Int = 1) {
    let move = CGEvent(
        mouseEventSource: eventSource,
        mouseType: .mouseMoved,
        mouseCursorPosition: point,
        mouseButton: .left
    )!
    move.post(tap: .cghidEventTap)
    usleep(80_000)
    for clickIndex in 1...max(1, count) {
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            let event = CGEvent(
                mouseEventSource: eventSource,
                mouseType: type,
                mouseCursorPosition: point,
                mouseButton: .left
            )!
            event.setIntegerValueField(
                .mouseEventClickState,
                value: Int64(clickIndex)
            )
            event.post(tap: .cghidEventTap)
            usleep(55_000)
        }
        usleep(70_000)
    }
}

private func waitUntil(
    timeout: TimeInterval,
    condition: () -> Bool
) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        if condition() { return true }
        usleep(120_000)
    } while Date() < deadline
    return false
}

private func captureStep(
    number: Int,
    name: String,
    fileName: String,
    expectedCopy: [String],
    expectedIdentifiers: [String],
    pid: pid_t,
    output: URL
) throws -> StepReceipt {
    let screenshotURL = output.appendingPathComponent(fileName)
    let deadline = Date().addingTimeInterval(4)
    var acceptedWindow: WindowInfo?
    var acceptedCopy: [String] = []
    repeat {
        guard let window = waitForWindow(pid: pid, timeout: 1) else {
            throw AuditFailure.windowUnavailable
        }
        try capture(window: window, to: screenshotURL)
        let recognized = try recognizedText(in: screenshotURL)
        let matchedCopy = expectedCopy.filter { textMatches($0, in: recognized) }
        if matchedCopy.count == expectedCopy.count {
            acceptedWindow = window
            acceptedCopy = matchedCopy
            break
        }
        usleep(250_000)
    } while Date() < deadline
    guard let window = acceptedWindow else {
        throw AuditFailure.localeMismatch
    }
    let elements = accessibilityElements(for: pid)
    let matchedIdentifiers = matchingIdentifiers(
        expectedIdentifiers,
        in: elements
    )
    return StepReceipt(
        number: number,
        name: name,
        screenshot: fileName,
        window: WindowSnapshot(
            width: Int(window.bounds.width.rounded()),
            height: Int(window.bounds.height.rounded()),
            fullyVisible: isFullyVisible(window.bounds)
        ),
        expectedEnglishCopy: expectedCopy,
        recognizedEnglishCopy: acceptedCopy,
        accessibilityIdentifiers: matchedIdentifiers,
        status: "PASS"
    )
}

private func run() throws -> AuditReceipt {
    let arguments = try Arguments()
    let fileManager = FileManager.default
    let output = arguments.output.standardizedFileURL
    let existingOutputValues = try? output.resourceValues(
        forKeys: [.isSymbolicLinkKey]
    )
    guard !output.path.isEmpty,
          existingOutputValues?.isSymbolicLink != true else {
        throw AuditFailure.unsafeOutput
    }
    try fileManager.createDirectory(
        at: output,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
    )
    guard waitUntil(timeout: 5, condition: {
        NSRunningApplication(processIdentifier: arguments.pid) != nil
    }) else {
        throw AuditFailure.runtimeUnavailable
    }
    guard let initialWindow = waitForWindow(pid: arguments.pid, timeout: 8) else {
        throw AuditFailure.windowUnavailable
    }

    var steps: [StepReceipt] = []
    steps.append(try captureStep(
        number: 1,
        name: "Tap invitation",
        fileName: "01-tap-invitation.png",
        expectedCopy: ["Tap Chengyin once", "Skip"],
        expectedIdentifiers: [
            "chengyin.first-session-coach",
            "chengyin.first-session-skip",
            "chengyin.pet-interaction"
        ],
        pid: arguments.pid,
        output: output
    ))

    click(CGPoint(x: initialWindow.bounds.midX, y: initialWindow.bounds.midY))
    guard waitUntil(timeout: 3, condition: {
        let ids = accessibilityElements(for: arguments.pid)
        if !ids.isEmpty {
            return matchingIdentifiers(
                ["chengyin.first-session-coach"],
                in: ids
            ).count == 1
        }
        return true
    }) else { throw AuditFailure.interactionFailed }
    usleep(700_000)
    steps.append(try captureStep(
        number: 2,
        name: "Double-click invitation",
        fileName: "02-double-click-invitation.png",
        expectedCopy: ["Nice-now double-click", "Every activity remains free"],
        expectedIdentifiers: [
            "chengyin.first-session-coach",
            "chengyin.first-session-skip",
            "chengyin.pet-interaction"
        ],
        pid: arguments.pid,
        output: output
    ))

    guard let doubleWindow = waitForWindow(pid: arguments.pid, timeout: 2) else {
        throw AuditFailure.windowUnavailable
    }
    click(
        CGPoint(x: doubleWindow.bounds.midX, y: doubleWindow.bounds.midY),
        count: 2
    )
    usleep(900_000)
    let preferenceIdentifiers = [
        "chengyin.first-session-preference-workCompanion",
        "chengyin.first-session-preference-playfulBreaks",
        "chengyin.first-session-preference-gentleCare"
    ]
    steps.append(try captureStep(
        number: 3,
        name: "Local preference",
        fileName: "03-local-preference.png",
        expectedCopy: [
            "What kind of company would you like?",
            "Work with me",
            "Playful breaks",
            "Gentle reminders"
        ],
        expectedIdentifiers: ["chengyin.first-session-coach"]
            + preferenceIdentifiers,
        pid: arguments.pid,
        output: output
    ))

    let preferenceElements = accessibilityElements(for: arguments.pid)
    let workPreference = preferenceElements.first {
        accessibilityIdentifier($0) == preferenceIdentifiers[0]
    }
    if let workPreference, let bounds = elementBounds(workPreference) {
        click(CGPoint(x: bounds.midX, y: bounds.midY))
    } else if let preferenceWindow = waitForWindow(
        pid: arguments.pid,
        timeout: 2
    ) {
        click(CGPoint(
            x: preferenceWindow.bounds.minX + 105,
            y: preferenceWindow.bounds.maxY - 40
        ))
    } else {
        throw AuditFailure.interactionFailed
    }
    usleep(800_000)
    steps.append(try captureStep(
        number: 4,
        name: "Shared work arc",
        fileName: "04-shared-work-arc.png",
        expectedCopy: [
            "Your first shared work arc is playing",
            "without treating progress as completion"
        ],
        expectedIdentifiers: ["chengyin.first-session-coach"],
        pid: arguments.pid,
        output: output
    ))

    usleep(5_200_000)
    guard waitUntil(timeout: 3, condition: {
        let ids = matchingIdentifiers(
            ["chengyin.first-session-coach"],
            in: accessibilityElements(for: arguments.pid)
        )
        return ids.isEmpty
    }) else { throw AuditFailure.interactionFailed }
    guard let completedWindow = waitForWindow(pid: arguments.pid, timeout: 3) else {
        throw AuditFailure.windowUnavailable
    }
    let completedURL = output.appendingPathComponent("05-completed.png")
    try capture(window: completedWindow, to: completedURL)
    steps.append(StepReceipt(
        number: 5,
        name: "Completed locally",
        screenshot: "05-completed.png",
        window: WindowSnapshot(
            width: Int(completedWindow.bounds.width.rounded()),
            height: Int(completedWindow.bounds.height.rounded()),
            fullyVisible: isFullyVisible(completedWindow.bounds)
        ),
        expectedEnglishCopy: [],
        recognizedEnglishCopy: [],
        accessibilityIdentifiers: matchingIdentifiers(
            ["chengyin.pet-interaction"],
            in: accessibilityElements(for: arguments.pid)
        ),
        status: "PASS"
    ))

    guard steps.allSatisfy({ $0.window.fullyVisible }) else {
        throw AuditFailure.windowUnavailable
    }
    let runtimeAccessibility = AXIsProcessTrusted()
        && steps.prefix(4).allSatisfy { !$0.accessibilityIdentifiers.isEmpty }
        ? "PASS"
        : "PENDING_RUNTIME_ASSISTIVE_TECHNOLOGY"
    return AuditReceipt(
        status: "PASS_WITH_PENDING",
        code: nil,
        message: "The isolated English first-use walkthrough completed with current-run screenshots and runtime semantics where available.",
        recoveryAction: "Run the same receipt on a physically clean English Mac with a human VoiceOver reviewer before closing the public-release gate.",
        environment: "ISOLATED_LOCAL_LAB",
        locale: "en-US",
        steps: steps,
        runtimeAccessibility: runtimeAccessibility,
        humanVoiceOverAudit: "PENDING_HUMAN_REVIEW",
        physicalCleanMacAudit: "PENDING_EXTERNAL_DEVICE",
        proofStrength: "current-run-window-capture-plus-vision-ocr-plus-ax-where-trusted-human_review_required-physical_clean_mac_required"
    )
}

do {
    publish(try run(), exitCode: 0)
} catch let failure as AuditFailure {
    publish(
        AuditReceipt(
            status: "FAIL",
            code: failure.code,
            message: failure.message,
            recoveryAction: failure.recoveryAction,
            environment: "ISOLATED_LOCAL_LAB",
            locale: "en-US",
            steps: [],
            runtimeAccessibility: "NOT_EVALUATED",
            humanVoiceOverAudit: "PENDING_HUMAN_REVIEW",
            physicalCleanMacAudit: "PENDING_EXTERNAL_DEVICE",
            proofStrength: "failed-before-complete-current-run-evidence"
        ),
        exitCode: 1
    )
} catch {
    publish(
        AuditReceipt(
            status: "FAIL",
            code: "FIRST_USE_VISUAL_AUDIT_SCREENSHOT_FAILED",
            message: "The isolated English first-use audit did not finish safely.",
            recoveryAction: "Inspect the path-safe audit log and rerun the isolated walkthrough.",
            environment: "ISOLATED_LOCAL_LAB",
            locale: "en-US",
            steps: [],
            runtimeAccessibility: "NOT_EVALUATED",
            humanVoiceOverAudit: "PENDING_HUMAN_REVIEW",
            physicalCleanMacAudit: "PENDING_EXTERNAL_DEVICE",
            proofStrength: "failed-before-complete-current-run-evidence"
        ),
        exitCode: 1
    )
}
