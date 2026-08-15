@preconcurrency import AppKit
import CompanionContracts
import CoreGraphics
import Foundation

struct CompanionDisplayOption: Identifiable, Equatable {
    let id: String
    let label: String
    let visibleFrame: CGRect
    let isMain: Bool
}

/// AppKit adapter for the Core display-selection policy. Human-readable screen
/// names remain ephemeral UI data; only the technical identifier is persisted.
@MainActor
final class CompanionDisplayCatalog: ObservableObject {
    @Published private(set) var options: [CompanionDisplayOption] = []
    @Published private(set) var revision = 0
    @Published private(set) var companionWindowDisplayIdentifier: String?

    nonisolated(unsafe) private var screenChangeObserver: NSObjectProtocol?

    init(notificationCenter: NotificationCenter = .default) {
        refresh()
        screenChangeObserver = notificationCenter.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    deinit {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
    }

    func refresh() {
        let mainIdentifier = NSScreen.main.flatMap(Self.identifier(for:))
        options = NSScreen.screens.compactMap { screen in
            guard let identifier = Self.identifier(for: screen) else { return nil }
            return CompanionDisplayOption(
                id: identifier,
                label: screen.localizedName,
                visibleFrame: screen.visibleFrame,
                isMain: identifier == mainIdentifier
            )
        }
        revision &+= 1
    }

    func selection(
        for target: CompanionDisplayTarget,
        currentScreen: NSScreen?
    ) -> CompanionDisplaySelection {
        CompanionDisplaySelectionPolicy.resolve(
            target: target,
            currentDisplayIdentifier: currentScreen.flatMap(Self.identifier(for:)),
            displays: options.map {
                CompanionDisplayDescriptor(
                    identifier: $0.id,
                    visibleFrame: $0.visibleFrame,
                    isMain: $0.isMain
                )
            }
        )
    }

    func companionWindowSelection(
        for target: CompanionDisplayTarget
    ) -> CompanionDisplaySelection {
        CompanionDisplaySelectionPolicy.resolve(
            target: target,
            currentDisplayIdentifier: companionWindowDisplayIdentifier,
            displays: options.map {
                CompanionDisplayDescriptor(
                    identifier: $0.id,
                    visibleFrame: $0.visibleFrame,
                    isMain: $0.isMain
                )
            }
        )
    }

    func noteCompanionWindowScreen(_ screen: NSScreen?) {
        let identifier = screen.flatMap(Self.identifier(for:))
        if companionWindowDisplayIdentifier != identifier {
            companionWindowDisplayIdentifier = identifier
        }
    }

    func screen(
        for target: CompanionDisplayTarget,
        currentScreen: NSScreen?
    ) -> NSScreen? {
        let selected = selection(for: target, currentScreen: currentScreen)
        return NSScreen.screens.first {
            Self.identifier(for: $0) == selected.descriptor.identifier
        } ?? currentScreen ?? NSScreen.main ?? NSScreen.screens.first
    }

    func label(for target: CompanionDisplayTarget) -> String? {
        guard target.mode == .specific, let identifier = target.identifier else {
            return nil
        }
        return options.first(where: { $0.id == identifier })?.label
    }

    func resolution(
        for target: CompanionDisplayTarget,
        currentScreen: NSScreen? = nil
    ) -> CompanionDisplayResolution {
        if let currentScreen {
            return selection(for: target, currentScreen: currentScreen).resolution
        }
        return companionWindowSelection(for: target).resolution
    }

    static func identifier(for screen: NSScreen) -> String? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else {
            return nil
        }
        let displayID = CGDirectDisplayID(number.uint32Value)
        if let unmanaged = CGDisplayCreateUUIDFromDisplayID(displayID) {
            let uuid = unmanaged.takeRetainedValue()
            return (CFUUIDCreateString(nil, uuid) as String).lowercased()
        }
        return "display-\(displayID)"
    }
}
