import AppKit
import Foundation

enum CompanionWindowVisibilityPolicy {
    static var steadyCollectionBehavior: NSWindow.CollectionBehavior {
        var behavior: NSWindow.CollectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
        ]
        if #available(macOS 26.0, *) {
            // macOS 26 adds the explicit floating-overlay contract for joining
            // other applications' full-screen and Stage Manager spaces.
            behavior.insert(.canJoinAllApplications)
        } else {
            behavior.insert(.fullScreenAuxiliary)
        }
        return behavior
    }
}

/// Reasserts the pet window's cross-Space contract when macOS changes the
/// active Space or unhides the app. A five-second main-queue guard also repairs
/// silent SwiftUI/AppKit collection-behavior resets. It does not decode media,
/// activate the app, move the pointer, request Accessibility permission, or
/// override intentional minimization.
@MainActor
final class CompanionWindowVisibilityKeeper: NSObject {
    private weak var application: NSApplication?
    private let workspaceNotificationCenter: NotificationCenter
    private let appNotificationCenter: NotificationCenter
    private var started = false
    private var revealGeneration: UInt64 = 0
    private var visibilityTimer: DispatchSourceTimer?

    init(
        application: NSApplication,
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        appNotificationCenter: NotificationCenter = .default
    ) {
        self.application = application
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.appNotificationCenter = appNotificationCenter
    }

    func start() {
        guard !started else { return }
        started = true
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange(_:)),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        appNotificationCenter.addObserver(
            self,
            selector: #selector(applicationDidUnhide(_:)),
            name: NSApplication.didUnhideNotification,
            object: nil
        )
        appNotificationCenter.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(
            deadline: .now() + 2,
            repeating: 5,
            leeway: .milliseconds(750)
        )
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.reassertVisibility()
            }
        }
        visibilityTimer = timer
        timer.resume()
        reveal(attemptsRemaining: 8)
    }

    func stop() {
        guard started else { return }
        started = false
        revealGeneration &+= 1
        visibilityTimer?.setEventHandler {}
        visibilityTimer?.cancel()
        visibilityTimer = nil
        workspaceNotificationCenter.removeObserver(self)
        appNotificationCenter.removeObserver(self)
    }

    func reveal(attemptsRemaining: Int = 2) {
        revealGeneration &+= 1
        let generation = revealGeneration
        reveal(
            attemptsRemaining: max(0, attemptsRemaining),
            generation: generation
        )
    }

    @objc private func activeSpaceDidChange(_ notification: Notification) {
        _ = notification
        reassertVisibility()
    }

    @objc private func applicationDidUnhide(_ notification: Notification) {
        _ = notification
        reassertVisibility()
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        _ = notification
        reassertVisibility()
    }

    private func reveal(
        attemptsRemaining: Int,
        generation: UInt64
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self,
                  self.started,
                  self.revealGeneration == generation else { return }
            if self.reassertVisibility() {
                return
            }
            guard attemptsRemaining > 0 else { return }
            self.reveal(
                attemptsRemaining: attemptsRemaining - 1,
                generation: generation
            )
        }
    }

    @discardableResult
    private func reassertVisibility() -> Bool {
        guard let window = companionWindow else { return false }
        guard !window.isMiniaturized else { return true }

        // SwiftUI may silently replace collection behaviors after a Space or
        // display transition. Reapply one authoritative policy. On macOS 26+
        // `canJoinAllApplications` is the dedicated floating-overlay contract
        // for other apps' full-screen and Stage Manager spaces.
        window.collectionBehavior = CompanionWindowVisibilityPolicy
            .steadyCollectionBehavior
        window.level = .floating
        window.canHide = false
        window.hidesOnDeactivate = false
        window.orderFrontRegardless()
        return true
    }

    private var companionWindow: NSWindow? {
        guard let application else { return nil }
        return application.windows.first { $0.title == "澄音" }
            ?? application.windows.first
    }
}
