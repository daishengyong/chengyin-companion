import Foundation

/// Deterministic locale compatibility shared by content selection and
/// accessibility copy. It ranks exact, script-compatible and language-only
/// declarations without performing network or filesystem work.
public enum CompanionLocaleResolutionPolicy {
    public static let maximumTagCharacters = 128
    public static let maximumCandidateCount = 64

    /// Accepts the bounded BCP-47 shape used by Content Pack manifests and
    /// normalizes system-style underscore separators for runtime matching.
    public static func normalizedTag(_ rawValue: String) -> String? {
        let value = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
        guard !value.isEmpty, value.count <= maximumTagCharacters else {
            return nil
        }
        let subtags = value.split(separator: "-", omittingEmptySubsequences: false)
        guard let language = subtags.first,
              (2...8).contains(language.count),
              language.allSatisfy(Self.isASCIILetter),
              subtags.dropFirst().allSatisfy({ subtag in
                  (1...8).contains(subtag.count)
                      && subtag.allSatisfy(Self.isASCIIAlphaNumeric)
              }) else {
            return nil
        }
        return subtags.map { $0.lowercased() }.joined(separator: "-")
    }

    /// Higher values are more specific. `nil` means the declarations are not
    /// compatible. Generic language tags intentionally outrank a conflicting
    /// regional variant, while a matching script outranks the generic tag.
    public static func compatibilityScore(
        candidate: String,
        preferred: String
    ) -> Int? {
        guard let candidate = parts(candidate),
              let preferred = parts(preferred),
              candidate.language == preferred.language else {
            return nil
        }
        if candidate.normalized == preferred.normalized { return 1_000 }

        let candidateScript = resolvedScript(for: candidate)
        let preferredScript = resolvedScript(for: preferred)
        if let candidateScript, let preferredScript,
           candidateScript != preferredScript {
            return nil
        }
        if let region = candidate.region, region == preferred.region {
            return 900
        }
        if candidate.script != nil,
           candidateScript != nil,
           candidateScript == preferredScript {
            return 860
        }
        if preferred.script != nil,
           preferredScript != nil,
           candidateScript == preferredScript {
            return 850
        }
        if candidate.script == nil, candidate.region == nil {
            return 800
        }
        if candidateScript != nil, candidateScript == preferredScript {
            return 650
        }
        return 600
    }

    /// Returns the original declared tag so callers retain manifest identity.
    /// Preferred matching is attempted first, then each declared fallback in
    /// order, and finally the first syntactically valid available tag.
    public static func bestMatch(
        preferred: String,
        available: [String],
        fallbackOrder: [String] = []
    ) -> String? {
        let bounded = Array(available.prefix(maximumCandidateCount))
        if let match = bestCompatibleMatch(
            preferred: preferred,
            available: bounded
        ) {
            return match
        }
        for fallback in fallbackOrder.prefix(maximumCandidateCount) {
            if let match = bestCompatibleMatch(
                preferred: fallback,
                available: bounded
            ) {
                return match
            }
        }
        return bounded.first { normalizedTag($0) != nil }
    }

    /// Returns only a compatible declaration and never applies a fallback.
    /// Media eligibility uses this stricter boundary, while accessibility copy
    /// calls `bestMatch` with the pack's declared fallback order. Exposing both
    /// contracts lets creator tooling report exactly what runtime will do
    /// without reimplementing locale ranking.
    public static func bestCompatibleMatch(
        preferred: String,
        available: [String]
    ) -> String? {
        highestRanked(
            preferred: preferred,
            available: Array(available.prefix(maximumCandidateCount))
        )
    }

    private static func highestRanked(
        preferred: String,
        available: [String]
    ) -> String? {
        var best: (tag: String, score: Int)?
        for tag in available {
            guard let score = compatibilityScore(
                candidate: tag,
                preferred: preferred
            ) else { continue }
            if best == nil || score > best!.score {
                best = (tag, score)
            }
        }
        return best?.tag
    }

    private struct Parts {
        let normalized: String
        let language: String
        let script: String?
        let region: String?
    }

    private static func parts(_ rawValue: String) -> Parts? {
        guard let normalized = normalizedTag(rawValue) else { return nil }
        let subtags = normalized.split(separator: "-").map(String.init)
        let trailing = subtags.dropFirst()
        let script = trailing.first {
            $0.count == 4 && $0.allSatisfy(Self.isASCIILetter)
        }
        let region = trailing.first {
            ($0.count == 2 && $0.allSatisfy(Self.isASCIILetter))
                || ($0.count == 3 && $0.allSatisfy(Self.isASCIIDigit))
        }
        return Parts(
            normalized: normalized,
            language: subtags[0],
            script: script,
            region: region
        )
    }

    private static func resolvedScript(for parts: Parts) -> String? {
        if let script = parts.script { return script }
        guard parts.region != nil else { return nil }
        return Locale(identifier: parts.normalized)
            .language
            .script?
            .identifier
            .lowercased()
    }

    private static func isASCIILetter(_ character: Character) -> Bool {
        character.isASCII && character.isLetter
    }

    private static func isASCIIDigit(_ character: Character) -> Bool {
        character.isASCII && character.isNumber
    }

    private static func isASCIIAlphaNumeric(_ character: Character) -> Bool {
        isASCIILetter(character) || isASCIIDigit(character)
    }
}
