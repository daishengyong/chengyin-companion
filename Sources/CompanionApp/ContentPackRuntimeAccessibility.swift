import Foundation

#if canImport(CompanionContracts)
import CompanionContracts
#endif

/// Localized, presentation-safe accessibility copy carried from a validated
/// Content Pack declaration into immutable runtime media values.
///
/// It contains no paths, URLs, commands or executable behavior. Compatibility
/// packs may omit it; strict-v2 review remains the public-distribution gate.
struct CompanionRuntimeMediaAccessibility: Equatable, Sendable {
    static let maximumLabelCharacters = 512
    static let maximumValueCharacters = 1_024

    let localeOrder: [String]
    let descriptions: [String: String]
    let transcripts: [String: String]
    let altText: [String: String]
    let captions: [String: String]
    let soundDescriptions: [String: String]
    let flashingLights: Bool
    let suddenLoudAudio: Bool

    init(
        declaration: ContentPackAssetAccessibility,
        localeOrder: [String]
    ) {
        self.localeOrder = localeOrder
        descriptions = declaration.descriptions
        transcripts = declaration.transcripts ?? [:]
        altText = declaration.altText ?? [:]
        captions = declaration.captions ?? [:]
        soundDescriptions = declaration.soundDescriptions ?? [:]
        flashingLights = declaration.flashingLights
        suddenLoudAudio = declaration.suddenLoudAudio
    }

    func resolved(
        preferredLocale: String
    ) -> CompanionResolvedMediaAccessibility? {
        let label = localizedValue(in: altText, preferredLocale: preferredLocale)
            ?? localizedValue(in: descriptions, preferredLocale: preferredLocale)
        let spoken = localizedValue(in: captions, preferredLocale: preferredLocale)
            ?? localizedValue(in: transcripts, preferredLocale: preferredLocale)
        let sound = localizedValue(
            in: soundDescriptions,
            preferredLocale: preferredLocale
        )
        let value = Self.joinDistinct(
            [spoken, sound].compactMap { $0 },
            maximumCharacters: Self.maximumValueCharacters
        )
        guard label != nil || value != nil else { return nil }
        return CompanionResolvedMediaAccessibility(
            label: label.map {
                Self.bounded($0, maximumCharacters: Self.maximumLabelCharacters)
            },
            value: value,
            flashingLights: flashingLights,
            suddenLoudAudio: suddenLoudAudio
        )
    }

    private func localizedValue(
        in table: [String: String],
        preferredLocale: String
    ) -> String? {
        guard !table.isEmpty else { return nil }
        let keys = table.keys.sorted()
        guard let match = CompanionLocaleResolutionPolicy.bestMatch(
            preferred: preferredLocale,
            available: keys,
            fallbackOrder: localeOrder
        ) else { return nil }
        return Self.cleaned(table[match])
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let compact = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return compact.isEmpty ? nil : compact
    }

    fileprivate static func joinDistinct(
        _ values: [String],
        maximumCharacters: Int
    ) -> String? {
        var seen = Set<String>()
        let unique = values.compactMap { cleaned($0) }.filter {
            seen.insert($0).inserted
        }
        guard !unique.isEmpty else { return nil }
        return bounded(
            unique.joined(separator: " "),
            maximumCharacters: maximumCharacters
        )
    }

    fileprivate static func bounded(
        _ value: String,
        maximumCharacters: Int
    ) -> String {
        String(value.prefix(max(1, maximumCharacters)))
    }
}

struct CompanionResolvedMediaAccessibility: Equatable, Sendable {
    let label: String?
    let value: String?
    let flashingLights: Bool
    let suddenLoudAudio: Bool
}

extension CompanionVideoAsset {
    func resolvedAccessibility(
        preferredLocale: String
    ) -> CompanionResolvedMediaAccessibility? {
        accessibility?.resolved(preferredLocale: preferredLocale)
    }
}

extension CompanionVideoSequence {
    func resolvedAccessibility(
        preferredLocale: String
    ) -> CompanionResolvedMediaAccessibility? {
        let descriptors = steps.compactMap {
            $0.asset.resolvedAccessibility(preferredLocale: preferredLocale)
        }
        guard !descriptors.isEmpty else { return nil }
        return CompanionResolvedMediaAccessibility(
            label: CompanionRuntimeMediaAccessibility.joinDistinct(
                descriptors.compactMap(\.label),
                maximumCharacters: CompanionRuntimeMediaAccessibility
                    .maximumLabelCharacters
            ),
            value: CompanionRuntimeMediaAccessibility.joinDistinct(
                descriptors.compactMap(\.value),
                maximumCharacters: CompanionRuntimeMediaAccessibility
                    .maximumValueCharacters
            ),
            flashingLights: descriptors.contains(where: \.flashingLights),
            suddenLoudAudio: descriptors.contains(where: \.suddenLoudAudio)
        )
    }
}
