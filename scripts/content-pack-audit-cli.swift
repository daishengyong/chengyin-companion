import Foundation

private struct AuditReceipt: Codable {
    let status: String
    let packID: String
    let version: String
    let schemaVersion: Int
    let qualityCandidate: String
    let warningCount: Int
    let warnings: [String]
    let rightsCoveredAssetCount: Int
    let accessibilityCoveredAssetCount: Int
    let dynamicFocalAssetCount: Int
    let safeAreaAssetCount: Int
    let fallbackStrategy: String?
    let contributionReady: Bool
    let contributionMode: String
    let packageReviewStatus: String?
    let mediaValidationBackend: String
}

@main
private enum ContentPackAuditCLI {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        do {
            guard let path = arguments.first, path != "--help" else {
                printUsage()
                exit(arguments.first == "--help" ? 0 : 2)
            }

            var appVersion = "0.19.98"
            var emitsJSON = false
            var strict = false
            var index = 1
            while index < arguments.count {
                switch arguments[index] {
                case "--app-version":
                    guard index + 1 < arguments.count else {
                        throw AuditError(
                            code: "CREATOR_AUDIT_APP_VERSION_MISSING",
                            message: "--app-version requires a semantic version"
                        )
                    }
                    appVersion = arguments[index + 1]
                    index += 2
                case "--json":
                    emitsJSON = true
                    index += 1
                case "--strict":
                    strict = true
                    index += 1
                default:
                    throw AuditError(
                        code: "CREATOR_AUDIT_UNKNOWN_OPTION",
                        message: "Unknown option: \(arguments[index])"
                    )
                }
            }

            let directory = URL(fileURLWithPath: path, isDirectory: true)
                .standardizedFileURL
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(
                atPath: directory.path,
                isDirectory: &isDirectory
            ), isDirectory.boolValue else {
                throw AuditError(
                    code: "CREATOR_AUDIT_PACK_DIRECTORY_MISSING",
                    message: "Pack directory does not exist or is not a directory"
                )
            }

            let manifest = try ContentPackValidator().loadAndValidate(
                packageDirectory: directory,
                currentAppVersion: appVersion
            )
            try await creatorContentPackMediaProbe().probe(
                packageDirectory: directory,
                manifest: manifest
            )
            let warnings = audit(manifest)
            let contributionReadiness = manifest.contributionReadiness
            let receipt = AuditReceipt(
                status: warnings.isEmpty ? "PASS" : "PASS_WITH_WARNINGS",
                packID: manifest.id,
                version: manifest.version,
                schemaVersion: manifest.schemaVersion,
                qualityCandidate: warnings.isEmpty ? "READY_FOR_LAB" : "DRAFT",
                warningCount: warnings.count,
                warnings: warnings,
                rightsCoveredAssetCount: contributionReadiness.rightsCoveredAssetCount,
                accessibilityCoveredAssetCount: contributionReadiness.accessibilityCoveredAssetCount,
                dynamicFocalAssetCount: manifest.assets.filter {
                    !($0.focalTracks ?? [:]).isEmpty
                }.count,
                safeAreaAssetCount: manifest.assets.filter {
                    !($0.safeAreas ?? [:]).isEmpty
                }.count,
                fallbackStrategy: manifest.contribution?.fallback.strategy.rawValue,
                contributionReady: contributionReadiness.isReady,
                contributionMode: manifest.contributionMode.rawValue,
                packageReviewStatus: manifest.contribution?.package?.review.status.rawValue,
                mediaValidationBackend: creatorMediaValidationBackendID()
            )

            if emitsJSON {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                print(String(decoding: try encoder.encode(receipt), as: UTF8.self))
            } else {
                print("\(receipt.status)  \(manifest.id)@\(manifest.version)")
                print("      quality candidate: \(receipt.qualityCandidate)")
                print(
                    "      contribution: rights \(receipt.rightsCoveredAssetCount)/\(manifest.assets.count), accessibility \(receipt.accessibilityCoveredAssetCount)/\(manifest.assets.count), fallback \(receipt.fallbackStrategy ?? "missing")"
                )
                print(
                    "      projection: dynamic focal \(receipt.dynamicFocalAssetCount), safe area \(receipt.safeAreaAssetCount)"
                )
                for warning in warnings {
                    print("WARN  \(warning)")
                }
            }
            if strict, !warnings.isEmpty {
                exit(3)
            }
        } catch {
            let receipt = CompanionFailureReceipt(
                error: error,
                fallbackCode: "CREATOR_AUDIT_UNEXPECTED_ERROR"
            )
            if arguments.contains("--json") {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let data = try? encoder.encode(receipt) {
                    print(String(decoding: data, as: UTF8.self))
                } else {
                    fputs(receipt.safeLog + "\n", stderr)
                }
            } else {
                fputs(receipt.safeLog + "\n", stderr)
            }
            exit(1)
        }
    }

    private static func audit(_ manifest: ContentPackManifest) -> [String] {
        var warnings: [String] = []
        let normalizedLicense = manifest.license
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let placeholderTerms = ["tbd", "todo", "placeholder", "test-only", "test content"]
        if placeholderTerms.contains(where: normalizedLicense.contains) {
            warnings.append("license looks like a placeholder; document distribution rights before contribution")
        }

        let videoAssets = manifest.assets.filter { $0.kind == .video }
        for asset in videoAssets {
            let anchors = asset.cropAnchors ?? [:]
            let tracks = asset.focalTracks ?? [:]
            let hasProjection: ([String]) -> Bool = { keys in
                keys.contains { anchors[$0] != nil || tracks[$0] != nil }
            }
            let missing = [
                ("pet", ["pet"]),
                ("stage", ["stage", "partial"]),
                ("fullscreen", ["fullscreen", "full"])
            ].compactMap { label, keys in
                hasProjection(keys) ? nil : label
            }
            if !missing.isEmpty {
                warnings.append("video \(asset.id) is missing projections: \(missing.joined(separator: ", "))")
            }
            if !tracks.isEmpty, (asset.safeAreas ?? [:]).isEmpty {
                warnings.append(
                    "video \(asset.id) has focal tracks but no safe area review envelope"
                )
            }
            if asset.hasNativeAudio != true {
                warnings.append("video \(asset.id) has no declared native audio; verify intentional silent fallback")
            }
            if asset.tags.isEmpty {
                warnings.append("asset \(asset.id) has no discovery tags")
            }
        }

        if manifest.schemaVersion >= 2,
           !(manifest.experiences ?? []).isEmpty,
           videoAssets.isEmpty {
            warnings.append("v2 experiences exist without video assets")
        }

        if manifest.schemaVersion == 1 {
            warnings.append(
                "legacy v1 compatibility mode: no rights, adult-status or accessibility approval is inferred; generate a v1-to-v2 migration receipt before contribution"
            )
        } else if manifest.schemaVersion >= 2 {
            if let contribution = manifest.contribution {
                if manifest.contributionMode == .compatibilityV2 {
                    warnings.append(
                        "compatibility v2 mode: contractVersion 2 package evidence is missing; existing license fields are not treated as contribution approval"
                    )
                }
                if let package = contribution.package {
                    if package.review.status != .approved {
                        warnings.append(
                            "package evidence review is \(package.review.status.rawValue), not approved"
                        )
                    }
                    let missingUses = Set(ContentPackAllowedUse.allCases)
                        .subtracting(package.allowedUses)
                        .map(\.rawValue).sorted()
                    if !missingUses.isEmpty {
                        warnings.append(
                            "package allowedUses is missing: \(missingUses.joined(separator: ", "))"
                        )
                    }
                } else if manifest.contributionMode == .strictV2 {
                    warnings.append("strict v2 package provenance is missing")
                }
                let rightsByAsset = Dictionary(
                    uniqueKeysWithValues: contribution.rights.map { ($0.assetID, $0) }
                )
                let accessibilityByAsset = Dictionary(
                    uniqueKeysWithValues: contribution.accessibility.map {
                        ($0.assetID, $0)
                    }
                )
                for asset in manifest.assets {
                    if let rights = rightsByAsset[asset.id] {
                        if !rights.commercialUseReviewed {
                            warnings.append(
                                "asset \(asset.id) has not passed commercial-use rights review"
                            )
                        }
                        if manifest.contributionMode == .strictV2 {
                            if rights.review?.status != .approved {
                                warnings.append(
                                    "asset \(asset.id) rights review is \(rights.review?.status.rawValue ?? "missing"), not approved"
                                )
                            }
                            let missingUses = Set(ContentPackAllowedUse.allCases)
                                .subtracting(rights.allowedUses ?? [])
                                .map(\.rawValue).sorted()
                            if !missingUses.isEmpty {
                                warnings.append(
                                    "asset \(asset.id) allowedUses is missing: \(missingUses.joined(separator: ", "))"
                                )
                            }
                        }
                        if [.video, .image].contains(asset.kind),
                           rights.subjectStatus == .notApplicable {
                            warnings.append(
                                "visual asset \(asset.id) must declare fictionalAdult, verifiedAdult or noPerson subject status"
                            )
                        }
                    } else {
                        warnings.append("asset \(asset.id) is missing rights metadata")
                    }

                    if let accessibility = accessibilityByAsset[asset.id] {
                        for locale in manifest.locales
                        where accessibility.descriptions[locale] == nil {
                            warnings.append(
                                "asset \(asset.id) is missing an accessibility description for \(locale)"
                            )
                        }
                        let requiresTranscript = asset.kind == .audio
                            || (asset.kind == .video && asset.hasNativeAudio == true)
                        if requiresTranscript {
                            for locale in manifest.locales
                            where accessibility.transcripts?[locale] == nil {
                                warnings.append(
                                    "spoken asset \(asset.id) is missing a transcript for \(locale)"
                                )
                            }
                        }
                        if manifest.contributionMode == .strictV2 {
                            if accessibility.review?.status != .approved {
                                warnings.append(
                                    "asset \(asset.id) accessibility review is \(accessibility.review?.status.rawValue ?? "missing"), not approved"
                                )
                            }
                            if [.video, .image].contains(asset.kind) {
                                for locale in manifest.locales
                                where accessibility.altText?[locale] == nil {
                                    warnings.append(
                                        "visual asset \(asset.id) is missing alt text for \(locale)"
                                    )
                                }
                            }
                            if requiresTranscript {
                                for locale in manifest.locales
                                where accessibility.captions?[locale] == nil {
                                    warnings.append(
                                        "spoken asset \(asset.id) is missing captions for \(locale)"
                                    )
                                }
                                for locale in manifest.locales
                                where accessibility.soundDescriptions?[locale] == nil {
                                    warnings.append(
                                        "audible asset \(asset.id) is missing a sound description for \(locale)"
                                    )
                                }
                            }
                        }
                    } else {
                        warnings.append(
                            "asset \(asset.id) is missing accessibility metadata"
                        )
                    }
                    if manifest.contributionMode == .strictV2 {
                        let fallback = contribution.fallback.assets?
                            .first(where: { $0.assetID == asset.id })
                        if fallback == nil {
                            warnings.append(
                                "asset \(asset.id) is missing an explicit fallback"
                            )
                        }
                    }
                }
            } else if !manifest.assets.isEmpty {
                warnings.append(
                    "compatibility v2 mode: contribution metadata is missing; no rights approval is inferred, so declare package and per-asset evidence plus Starter fallback"
                )
            }
        }
        for experience in manifest.experiences ?? [] {
            let roles = experience.steps.map(\.role)
            if roles.count > 1,
               roles.first != .enter,
               roles.first != .notice {
                warnings.append("experience \(experience.id) starts at \(roles[0].rawValue); consider an enter/notice beat")
            }
            if roles.count > 1,
               roles.last != .settle,
               roles.last != .exit {
                warnings.append("experience \(experience.id) has no settle/exit beat")
            }
        }

        let hasLocalization = manifest.assets.contains { $0.kind == .localization }
        if manifest.locales.count > 1, !hasLocalization {
            warnings.append("multiple locales are declared without a localization asset")
        }
        return warnings.sorted()
    }

    private static func printUsage() {
        print(
            """
            Usage: audit-content-pack.sh <pack-directory> [options]

              --app-version <x.y.z>  Validate minimum app compatibility (default 0.19.98)
              --json                 Print a machine-readable audit receipt
              --strict               Return status 3 when quality warnings exist
              --help                 Show this message

            Audit first runs the authoritative structural and AVFoundation checks.
            READY_FOR_LAB is a creator preflight, not Stable or Verified status.
            """
        )
    }
}

private struct AuditError: LocalizedError, CompanionErrorCoding {
    let code: String
    let message: String

    init(code: String, message: String) {
        self.code = code
        self.message = message
    }

    var companionErrorCode: String { code }
    var errorDescription: String? { message }
}
