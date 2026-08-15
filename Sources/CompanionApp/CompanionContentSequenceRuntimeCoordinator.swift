import Combine
import Foundation

enum CompanionContentSequenceTerminal<Fallback> {
    case ignored
    case completed(fallback: Fallback?)
    case failed(fallback: Fallback?)
}

/// Owns the session-local selection cache and active declarative sequence.
///
/// The coordinator receives an immutable catalog and caller-projected playback
/// memory. It has no filesystem, media-decoder, speech, window, persistence or
/// network capability; those effects remain in the app composition layer.
/// Replaced sequences invalidate stale completion and failure callbacks.
@MainActor
final class CompanionContentSequenceRuntimeCoordinator<Fallback>: ObservableObject {
    @Published private(set) var activeSequence: CompanionVideoSequence?

    private var activeFallback: Fallback?
    private var selectedAssetKey: String?
    private var selectedAsset: CompanionVideoAsset?

    var isActive: Bool { activeSequence != nil }

    func selectVideo(
        key: String,
        triggers: [String],
        catalog: ContentPackRuntimeCatalog,
        preferredLocale: String,
        context: ContentPackSelectionContext
    ) -> CompanionVideoAsset? {
        if selectedAssetKey == key {
            return selectedAsset
        }
        let asset = catalog.selectVideo(
            for: triggers,
            preferredLocale: preferredLocale,
            context: context
        )
        selectedAssetKey = key
        selectedAsset = asset
        return asset
    }

    @discardableResult
    func selectAndBegin(
        triggers: [String],
        catalog: ContentPackRuntimeCatalog,
        preferredLocale: String,
        context: ContentPackSelectionContext,
        fallback: Fallback
    ) -> CompanionVideoSequence? {
        guard let selection = catalog.selectExperience(
            for: triggers,
            preferredLocale: preferredLocale,
            context: context
        ) else {
            return nil
        }
        activeFallback = fallback
        activeSequence = selection.sequence
        return selection.sequence
    }

    func finish(
        sequenceID: String,
        succeeded: Bool
    ) -> CompanionContentSequenceTerminal<Fallback> {
        guard activeSequence?.id == sequenceID else { return .ignored }
        let fallback = activeFallback
        activeSequence = nil
        activeFallback = nil
        return succeeded
            ? .completed(fallback: fallback)
            : .failed(fallback: fallback)
    }

    func cancelActive() {
        activeSequence = nil
        activeFallback = nil
    }

    func resetSelectionCache() {
        selectedAssetKey = nil
        selectedAsset = nil
    }

    func reset() {
        cancelActive()
        resetSelectionCache()
    }
}
