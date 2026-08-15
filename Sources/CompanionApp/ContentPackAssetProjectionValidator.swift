import Foundation

#if canImport(CompanionContracts)
import CompanionContracts
#endif

/// Validates bounded media declarations, crop/focal projection, visible safe
/// areas and trigger compatibility. This policy is value-only: it cannot read
/// package files, calculate hashes or decode media.
struct ContentPackAssetProjectionValidator {
    private static let allowedProjectionKeys: Set<String> = [
        "pet", "stage", "fullscreen", "partial", "full"
    ]

    func validate(_ asset: ContentPackAsset) throws {
        if asset.kind == .video {
            guard let duration = asset.durationMs, duration > 0,
                  let width = asset.width, width > 0,
                  let height = asset.height, height > 0,
                  asset.aspectRatio?.isEmpty == false else {
                throw ContentPackValidationError.invalidVideoMetadata(asset.id)
            }
            guard duration <= ContentPackValidator.maximumMediaDurationMs else {
                throw ContentPackValidationError.mediaDurationTooLong(asset.id)
            }
            guard Int64(width) * Int64(height)
                <= Int64(ContentPackValidator.maximumMediaPixels) else {
                throw ContentPackValidationError.mediaDimensionsTooLarge(asset.id)
            }
        } else if let width = asset.width, let height = asset.height,
                  Int64(width) * Int64(height)
                    > Int64(ContentPackValidator.maximumMediaPixels) {
            throw ContentPackValidationError.mediaDimensionsTooLarge(asset.id)
        }

        for (mode, anchor) in asset.cropAnchors ?? [:] {
            guard (0...1).contains(anchor.x),
                  (0...1).contains(anchor.y),
                  anchor.scale >= 1,
                  anchor.scale <= 8 else {
                throw ContentPackValidationError.invalidCropAnchor(
                    asset: asset.id,
                    mode: mode
                )
            }
        }

        let focalTracks = try validateFocalTracks(asset)
        let safeAreas = try validateSafeAreas(asset)
        if !safeAreas.isEmpty {
            let anchors = (asset.cropAnchors ?? [:]).mapValues {
                CompanionMediaCropAnchor(x: $0.x, y: $0.y, scale: $0.scale)
            }
            for (safeAreaKey, safeArea) in safeAreas {
                let mode: CompanionPresentationMode
                switch safeAreaKey {
                case "pet": mode = .pet
                case "stage", "partial": mode = .stage
                case "fullscreen", "full": mode = .fullscreen
                default:
                    throw ContentPackValidationError.invalidSafeArea(
                        asset: asset.id,
                        mode: safeAreaKey
                    )
                }
                let projection = CompanionPresentationProjection.resolve(
                    mode: mode,
                    cropAnchors: anchors,
                    focalTracks: focalTracks,
                    safeAreas: [safeAreaKey: safeArea],
                    reducedDynamicEffectsEnabled: false
                )
                let anchorsToCheck = projection.focalTrack?.keyframes.map(\.anchor)
                    ?? projection.anchor.map { [$0] }
                    ?? []
                guard projection.safeArea != nil,
                      !anchorsToCheck.isEmpty,
                      anchorsToCheck.allSatisfy({ safeArea.isVisible(through: $0) }) else {
                    throw ContentPackValidationError.safeAreaNotVisible(
                        asset: asset.id,
                        mode: safeAreaKey
                    )
                }
            }
        }

        for trigger in asset.triggers where !ContentPackTriggerContract.isAllowed(trigger) {
            throw ContentPackValidationError.unsupportedTrigger(trigger)
        }
    }

    private func validateFocalTracks(
        _ asset: ContentPackAsset
    ) throws -> [String: CompanionMediaFocalTrack] {
        guard let declared = asset.focalTracks else { return [:] }
        guard asset.kind == .video, let durationMs = asset.durationMs else {
            throw ContentPackValidationError.invalidFocalTrack(
                asset: asset.id,
                mode: declared.keys.sorted().first ?? "unknown"
            )
        }
        var result: [String: CompanionMediaFocalTrack] = [:]
        for (mode, keyframes) in declared {
            let track = CompanionMediaFocalTrack(
                keyframes: keyframes.map {
                    CompanionMediaFocalKeyframe(
                        timeMs: $0.timeMs,
                        x: $0.x,
                        y: $0.y,
                        scale: $0.scale
                    )
                }
            )
            guard Self.allowedProjectionKeys.contains(mode),
                  keyframes.count <= ContentPackValidator.maximumFocalKeyframeCount,
                  track.isValid(durationMs: durationMs) else {
                throw ContentPackValidationError.invalidFocalTrack(
                    asset: asset.id,
                    mode: mode
                )
            }
            result[mode] = track
        }
        return result
    }

    private func validateSafeAreas(
        _ asset: ContentPackAsset
    ) throws -> [String: CompanionMediaSafeArea] {
        guard let declared = asset.safeAreas else { return [:] }
        guard asset.kind == .video else {
            throw ContentPackValidationError.invalidSafeArea(
                asset: asset.id,
                mode: declared.keys.sorted().first ?? "unknown"
            )
        }
        var result: [String: CompanionMediaSafeArea] = [:]
        for (mode, area) in declared {
            let safeArea = CompanionMediaSafeArea(
                x: area.x,
                y: area.y,
                width: area.width,
                height: area.height
            )
            guard Self.allowedProjectionKeys.contains(mode), safeArea.isValid else {
                throw ContentPackValidationError.invalidSafeArea(
                    asset: asset.id,
                    mode: mode
                )
            }
            result[mode] = safeArea
        }
        return result
    }
}
