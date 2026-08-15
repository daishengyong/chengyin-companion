/// Pure per-asset fallback coverage and media-kind compatibility validation.
struct ContentPackFallbackValidator {
    func validate(
        _ fallback: ContentPackFallbackDeclaration,
        strict: Bool,
        assetsByID: [String: ContentPackAsset]
    ) throws {
        var fallbackAssetIDs = Set<String>()
        for fallback in fallback.assets ?? [] {
            guard fallbackAssetIDs.insert(fallback.assetID).inserted else {
                throw ContentPackValidationError.duplicateFallbackAsset(
                    fallback.assetID
                )
            }
            guard let asset = assetsByID[fallback.assetID] else {
                throw ContentPackValidationError.unknownFallbackAsset(
                    fallback.assetID
                )
            }
            if [.video, .audio, .image].contains(asset.kind),
               fallback.strategy != .starter {
                throw ContentPackValidationError.invalidAssetFallback(
                    fallback.assetID
                )
            }
        }
        if strict {
            for assetID in assetsByID.keys where !fallbackAssetIDs.contains(assetID) {
                throw ContentPackValidationError.strictFallbackMetadataMissing(assetID)
            }
        }
    }
}
