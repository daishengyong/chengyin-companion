import Foundation

/// Immutable snapshot of active declarative video assets. The actor-backed
/// store owns installation state; views only receive safe, immutable URLs.
struct ContentPackRuntimeCatalog: Equatable, Sendable {
    static let empty = ContentPackRuntimeCatalog(
        videosByTrigger: [:],
        sequencesByTrigger: [:]
    )

    // Internal read access is limited to the focused selection extension. The
    // catalog remains immutable after construction and exposes no mutation API.
    let videosByTrigger: [String: [CompanionVideoAsset]]
    let sequencesByTrigger: [String: [CompanionVideoSequence]]

    init(activePacks: [InstalledContentPack]) {
        var result: [String: [CompanionVideoAsset]] = [:]
        var sequenceResult: [String: [CompanionVideoSequence]] = [:]
        for pack in activePacks where pack.record.health != .disabled {
            let reference = ContentPackPlaybackReference(
                packID: pack.record.packID,
                version: pack.record.version,
                health: pack.record.health
            )
            var accessibilityByAssetID: [String: ContentPackAssetAccessibility] = [:]
            for declaration in pack.manifest.contribution?.accessibility ?? [] {
                accessibilityByAssetID[declaration.assetID] = declaration
            }
            var runtimeAssetsByManifestID: [String: CompanionVideoAsset] = [:]
            for asset in pack.manifest.assets where asset.kind == .video {
                let url = pack.directory
                    .appendingPathComponent(asset.path)
                    .standardizedFileURL
                let runtimeAsset = CompanionVideoAsset(
                    id: "\(pack.record.packID)@\(pack.record.version):\(asset.id)",
                    url: url,
                    hasNativeAudio: asset.hasNativeAudio ?? false,
                    loops: asset.loop ?? false,
                    cropAnchors: asset.cropAnchors ?? [:],
                    focalTracks: asset.focalTracks ?? [:],
                    safeAreas: asset.safeAreas ?? [:],
                    localeTags: pack.manifest.locales,
                    weight: Self.normalizedWeight(asset.weight),
                    cooldownSeconds: max(0, asset.cooldownSeconds ?? 0),
                    durationMs: asset.durationMs,
                    accessibility: accessibilityByAssetID[asset.id].map {
                        CompanionRuntimeMediaAccessibility(
                            declaration: $0,
                            localeOrder: pack.manifest.locales
                        )
                    },
                    packReference: reference
                )
                runtimeAssetsByManifestID[asset.id] = runtimeAsset
                for trigger in asset.triggers {
                    result[trigger, default: []].append(runtimeAsset)
                }
            }
            for experience in pack.manifest.experiences ?? [] {
                let steps = experience.steps.compactMap { step -> CompanionVideoSequenceStep? in
                    guard let asset = runtimeAssetsByManifestID[step.assetID] else {
                        return nil
                    }
                    return CompanionVideoSequenceStep(
                        asset: asset,
                        role: step.role,
                        minimumPlaybackMs: max(0, step.minimumPlaybackMs ?? 0),
                        transition: step.transition ?? .cut
                    )
                }
                guard steps.count == experience.steps.count,
                      !steps.isEmpty else {
                    continue
                }
                let sequence = CompanionVideoSequence(
                    id: "\(pack.record.packID)@\(pack.record.version):experience:\(experience.id)",
                    kind: experience.kind,
                    steps: steps,
                    returnPolicy: experience.returnPolicy,
                    localeTags: experience.locales ?? pack.manifest.locales,
                    weight: Self.normalizedWeight(experience.weight),
                    cooldownSeconds: max(0, experience.cooldownSeconds ?? 0),
                    packReference: reference
                )
                for trigger in experience.triggers {
                    sequenceResult[trigger, default: []].append(sequence)
                }
            }
        }
        for trigger in result.keys {
            result[trigger]?.sort(by: Self.preferredOrder)
        }
        for trigger in sequenceResult.keys {
            sequenceResult[trigger]?.sort(by: Self.preferredSequenceOrder)
        }
        videosByTrigger = result
        sequencesByTrigger = sequenceResult
    }

    private init(
        videosByTrigger: [String: [CompanionVideoAsset]],
        sequencesByTrigger: [String: [CompanionVideoSequence]]
    ) {
        self.videosByTrigger = videosByTrigger
        self.sequencesByTrigger = sequencesByTrigger
    }

    private static func preferredOrder(
        _ lhs: CompanionVideoAsset,
        _ rhs: CompanionVideoAsset
    ) -> Bool {
        if lhs.weight != rhs.weight {
            return lhs.weight > rhs.weight
        }
        return lhs.id < rhs.id
    }

    private static func preferredSequenceOrder(
        _ lhs: CompanionVideoSequence,
        _ rhs: CompanionVideoSequence
    ) -> Bool {
        if lhs.weight != rhs.weight {
            return lhs.weight > rhs.weight
        }
        return lhs.id < rhs.id
    }

    private static func normalizedWeight(_ weight: Double?) -> Double {
        guard let weight, weight.isFinite else { return 1 }
        return max(0.01, weight)
    }

}
