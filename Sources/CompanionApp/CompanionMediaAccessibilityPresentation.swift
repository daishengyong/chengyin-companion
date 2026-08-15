import Foundation
import SwiftUI

extension CompanionViewModel {
    private var resolvedContentAccessibility:
        CompanionResolvedMediaAccessibility? {
        activeContentSequence?.resolvedAccessibility(
            preferredLocale: Locale.preferredLanguages.first ?? "en"
        )
    }

    var mediaAccessibilityLabel: String {
        resolvedContentAccessibility?.label ?? status
    }

    var mediaAccessibilityValue: String {
        guard let resolvedContentAccessibility else {
            return latestCompanionText
        }
        return resolvedContentAccessibility.value ?? ""
    }

    var mediaAccessibilityHint: String {
        guard let resolvedContentAccessibility else { return "" }
        return switch (
            resolvedContentAccessibility.flashingLights,
            resolvedContentAccessibility.suddenLoudAudio
        ) {
        case (true, true):
            CompanionLocalization.string(
                key: "media.accessibility.hint.flashingAndLoud",
                fallback: "包含闪烁画面和突然的较大声音。"
            )
        case (true, false):
            CompanionLocalization.string(
                key: "media.accessibility.hint.flashing",
                fallback: "包含闪烁画面。"
            )
        case (false, true):
            CompanionLocalization.string(
                key: "media.accessibility.hint.loud",
                fallback: "包含突然的较大声音。"
            )
        case (false, false):
            ""
        }
    }
}

extension View {
    func companionMediaAccessibility(
        _ viewModel: CompanionViewModel
    ) -> some View {
        accessibilityLabel(Text(viewModel.mediaAccessibilityLabel))
            .accessibilityValue(Text(viewModel.mediaAccessibilityValue))
            .accessibilityHint(Text(viewModel.mediaAccessibilityHint))
    }
}
