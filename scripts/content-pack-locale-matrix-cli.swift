import Foundation

private let localeMatrixContract = "chengyin.content-pack-locale-matrix/v1"
private let maximumRequestedLocales = 32

private struct LocaleMatrixWarning: Codable {
    let code: String
    let count: Int
}

private struct LocaleMatrixAssetResolution: Codable {
    let assetID: String
    let kind: String
    let accessibilityDeclared: Bool
    let descriptionLocale: String?
    let transcriptLocale: String?
    let altTextLocale: String?
    let captionLocale: String?
    let soundDescriptionLocale: String?
    let runtimeLabelLocale: String?
    let runtimeSpeechLocale: String?
}

private struct LocaleMatrixExperienceResolution: Codable {
    let experienceID: String
    let mediaEligible: Bool
    let selectedMediaLocale: String?
}

private struct LocaleMatrixRow: Codable {
    let requestedLocale: String
    let packMediaEligible: Bool
    let selectedPackMediaLocale: String?
    let accessibilityFallbackUsed: Bool
    let assetResolutions: [LocaleMatrixAssetResolution]
    let experienceResolutions: [LocaleMatrixExperienceResolution]
    let warnings: [LocaleMatrixWarning]
}

private struct LocaleMatrixSummary: Codable {
    let requestedLocaleCount: Int
    let mediaEligibleLocaleCount: Int
    let assetCount: Int
    let accessibilityDeclaredAssetCount: Int
    let experienceCount: Int
    let warningCount: Int
}

private struct LocaleMatrixReceipt: Codable {
    let schemaVersion: Int
    let contract: String
    let status: String
    let packID: String
    let version: String
    let contributionMode: String
    let declaredLocales: [String]
    let rows: [LocaleMatrixRow]
    let summary: LocaleMatrixSummary
    let networkRequired: Bool
    let mediaDecodePerformed: Bool
    let containsLocalizedCopy: Bool
    let releaseState: String
}

@main
private enum ContentPackLocaleMatrixCLI {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.contains("--help") || arguments.contains("-h") {
            printUsage()
            exit(0)
        }

        do {
            guard let path = arguments.first, !path.hasPrefix("-") else {
                throw LocaleMatrixCLIError(
                    code: "CREATOR_LOCALE_MATRIX_ARGUMENTS",
                    message: "A content-pack directory is required"
                )
            }

            var appVersion = "0.19.98"
            var emitsJSON = false
            var requestedLocales: [String] = []
            var requestedLocaleKeys = Set<String>()
            var index = 1
            while index < arguments.count {
                switch arguments[index] {
                case "--app-version":
                    guard index + 1 < arguments.count,
                          !arguments[index + 1].hasPrefix("-") else {
                        throw LocaleMatrixCLIError(
                            code: "CREATOR_LOCALE_MATRIX_APP_VERSION_MISSING",
                            message: "The app-version value is missing"
                        )
                    }
                    appVersion = arguments[index + 1]
                    index += 2
                case "--locale":
                    guard index + 1 < arguments.count,
                          !arguments[index + 1].hasPrefix("-") else {
                        throw LocaleMatrixCLIError(
                            code: "CREATOR_LOCALE_MATRIX_LOCALE_MISSING",
                            message: "The requested locale value is missing"
                        )
                    }
                    let rawLocale = arguments[index + 1]
                    guard let normalized = CompanionLocaleResolutionPolicy
                        .normalizedTag(rawLocale) else {
                        throw LocaleMatrixCLIError(
                            code: "CREATOR_LOCALE_MATRIX_INVALID_LOCALE",
                            message: "A requested locale tag is invalid"
                        )
                    }
                    guard requestedLocaleKeys.insert(normalized).inserted else {
                        throw LocaleMatrixCLIError(
                            code: "CREATOR_LOCALE_MATRIX_DUPLICATE_LOCALE",
                            message: "A requested locale is duplicated after normalization"
                        )
                    }
                    requestedLocales.append(normalized)
                    guard requestedLocales.count <= maximumRequestedLocales else {
                        throw LocaleMatrixCLIError(
                            code: "CREATOR_LOCALE_MATRIX_TOO_MANY_LOCALES",
                            message: "Too many requested locales were supplied"
                        )
                    }
                    index += 2
                case "--json":
                    emitsJSON = true
                    index += 1
                default:
                    throw LocaleMatrixCLIError(
                        code: "CREATOR_LOCALE_MATRIX_UNKNOWN_OPTION",
                        message: "The locale-matrix command received an unknown option"
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
                throw LocaleMatrixCLIError(
                    code: "CREATOR_LOCALE_MATRIX_PACK_DIRECTORY_MISSING",
                    message: "The selected pack directory is missing or unavailable"
                )
            }

            let manifest = try ContentPackValidator().loadAndValidate(
                packageDirectory: directory,
                currentAppVersion: appVersion
            )
            if requestedLocales.isEmpty {
                requestedLocales = manifest.locales.compactMap {
                    CompanionLocaleResolutionPolicy.normalizedTag($0)
                }
            }
            let receipt = makeReceipt(
                manifest: manifest,
                requestedLocales: requestedLocales
            )
            if emitsJSON {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                print(String(decoding: try encoder.encode(receipt), as: UTF8.self))
            } else {
                print("\(receipt.status)  \(receipt.packID)@\(receipt.version)")
                for row in receipt.rows {
                    let media = row.selectedPackMediaLocale ?? "unavailable"
                    print(
                        "      \(row.requestedLocale): media=\(media), "
                            + "warnings=\(row.warnings.reduce(0) { $0 + $1.count })"
                    )
                }
                print("      localized copy is intentionally omitted")
            }
        } catch {
            let receipt = CompanionFailureReceipt(
                error: error,
                fallbackCode: "CREATOR_LOCALE_MATRIX_UNEXPECTED_ERROR"
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

    private static func makeReceipt(
        manifest: ContentPackManifest,
        requestedLocales: [String]
    ) -> LocaleMatrixReceipt {
        let accessibilityByAssetID = Dictionary(
            uniqueKeysWithValues: (manifest.contribution?.accessibility ?? [])
                .map { ($0.assetID, $0) }
        )
        let rows = requestedLocales.map { requestedLocale in
            makeRow(
                manifest: manifest,
                accessibilityByAssetID: accessibilityByAssetID,
                requestedLocale: requestedLocale
            )
        }
        let warningCount = rows.flatMap(\.warnings).reduce(0) {
            $0 + $1.count
        }
        return LocaleMatrixReceipt(
            schemaVersion: 1,
            contract: localeMatrixContract,
            status: warningCount == 0 ? "PASS" : "PASS_WITH_WARNINGS",
            packID: manifest.id,
            version: manifest.version,
            contributionMode: manifest.contributionMode.rawValue,
            declaredLocales: manifest.locales,
            rows: rows,
            summary: LocaleMatrixSummary(
                requestedLocaleCount: rows.count,
                mediaEligibleLocaleCount: rows.filter(\.packMediaEligible).count,
                assetCount: manifest.assets.count,
                accessibilityDeclaredAssetCount: accessibilityByAssetID.count,
                experienceCount: manifest.experiences?.count ?? 0,
                warningCount: warningCount
            ),
            networkRequired: false,
            mediaDecodePerformed: false,
            containsLocalizedCopy: false,
            releaseState: "NOT_PUBLIC_RELEASE_READY"
        )
    }

    private static func makeRow(
        manifest: ContentPackManifest,
        accessibilityByAssetID: [String: ContentPackAssetAccessibility],
        requestedLocale: String
    ) -> LocaleMatrixRow {
        let selectedPackMediaLocale = CompanionLocaleResolutionPolicy
            .bestCompatibleMatch(
                preferred: requestedLocale,
                available: manifest.locales
            )
        let experiences = (manifest.experiences ?? []).map { experience in
            let selected = CompanionLocaleResolutionPolicy.bestCompatibleMatch(
                preferred: requestedLocale,
                available: experience.locales ?? manifest.locales
            )
            return LocaleMatrixExperienceResolution(
                experienceID: experience.id,
                mediaEligible: selected != nil,
                selectedMediaLocale: selected
            )
        }
        let assets = manifest.assets.map { asset in
            makeAssetResolution(
                asset: asset,
                accessibility: accessibilityByAssetID[asset.id],
                localeOrder: manifest.locales,
                requestedLocale: requestedLocale
            )
        }

        let missingAccessibility = assets.filter { !$0.accessibilityDeclared }.count
        let missingLabels = zip(manifest.assets, assets).filter { asset, result in
            (asset.kind == .video || asset.kind == .image)
                && result.runtimeLabelLocale == nil
        }.count
        let missingSpeech = zip(manifest.assets, assets).filter { asset, result in
            (asset.kind == .audio
                || (asset.kind == .video && asset.hasNativeAudio == true))
                && result.runtimeSpeechLocale == nil
        }.count
        let unavailableExperiences = experiences.filter { !$0.mediaEligible }.count
        let fallbackUsed = assets.contains { result in
            [
                result.descriptionLocale,
                result.transcriptLocale,
                result.altTextLocale,
                result.captionLocale,
                result.soundDescriptionLocale
            ].compactMap { $0 }.contains {
                !sameLocale($0, requestedLocale)
            }
        }

        var warnings: [LocaleMatrixWarning] = []
        appendWarning(
            code: "pack-media-unavailable",
            count: selectedPackMediaLocale == nil ? 1 : 0,
            to: &warnings
        )
        appendWarning(
            code: "experience-media-unavailable",
            count: unavailableExperiences,
            to: &warnings
        )
        appendWarning(
            code: "accessibility-declaration-missing",
            count: missingAccessibility,
            to: &warnings
        )
        appendWarning(
            code: "runtime-label-unavailable",
            count: missingLabels,
            to: &warnings
        )
        appendWarning(
            code: "runtime-speech-unavailable",
            count: missingSpeech,
            to: &warnings
        )
        appendWarning(
            code: "accessibility-fallback-used",
            count: fallbackUsed ? 1 : 0,
            to: &warnings
        )

        return LocaleMatrixRow(
            requestedLocale: requestedLocale,
            packMediaEligible: selectedPackMediaLocale != nil,
            selectedPackMediaLocale: selectedPackMediaLocale,
            accessibilityFallbackUsed: fallbackUsed,
            assetResolutions: assets,
            experienceResolutions: experiences,
            warnings: warnings
        )
    }

    private static func makeAssetResolution(
        asset: ContentPackAsset,
        accessibility: ContentPackAssetAccessibility?,
        localeOrder: [String],
        requestedLocale: String
    ) -> LocaleMatrixAssetResolution {
        let descriptions = selectLocale(
            accessibility?.descriptions,
            localeOrder: localeOrder,
            requestedLocale: requestedLocale
        )
        let transcripts = selectLocale(
            accessibility?.transcripts,
            localeOrder: localeOrder,
            requestedLocale: requestedLocale
        )
        let altText = selectLocale(
            accessibility?.altText,
            localeOrder: localeOrder,
            requestedLocale: requestedLocale
        )
        let captions = selectLocale(
            accessibility?.captions,
            localeOrder: localeOrder,
            requestedLocale: requestedLocale
        )
        let soundDescriptions = selectLocale(
            accessibility?.soundDescriptions,
            localeOrder: localeOrder,
            requestedLocale: requestedLocale
        )
        return LocaleMatrixAssetResolution(
            assetID: asset.id,
            kind: asset.kind.rawValue,
            accessibilityDeclared: accessibility != nil,
            descriptionLocale: descriptions,
            transcriptLocale: transcripts,
            altTextLocale: altText,
            captionLocale: captions,
            soundDescriptionLocale: soundDescriptions,
            runtimeLabelLocale: altText ?? descriptions,
            runtimeSpeechLocale: captions ?? transcripts
        )
    }

    private static func selectLocale(
        _ table: [String: String]?,
        localeOrder: [String],
        requestedLocale: String
    ) -> String? {
        guard let table, !table.isEmpty else { return nil }
        return CompanionLocaleResolutionPolicy.bestMatch(
            preferred: requestedLocale,
            available: table.keys.sorted(),
            fallbackOrder: localeOrder
        )
    }

    private static func sameLocale(_ lhs: String, _ rhs: String) -> Bool {
        CompanionLocaleResolutionPolicy.normalizedTag(lhs)
            == CompanionLocaleResolutionPolicy.normalizedTag(rhs)
    }

    private static func appendWarning(
        code: String,
        count: Int,
        to warnings: inout [LocaleMatrixWarning]
    ) {
        guard count > 0 else { return }
        warnings.append(LocaleMatrixWarning(code: code, count: count))
    }

    private static func printUsage() {
        print(
            """
            Usage: audit-content-pack-locales.sh <pack-directory> [options]

              --locale <tag>         Repeat up to 32 system locales; defaults to declared pack locales
              --app-version <x.y.z>  Validate minimum app compatibility (default 0.19.98)
              --json                 Print a machine-readable, copy-free locale matrix
              --help                 Show this message
            """
        )
    }
}

private struct LocaleMatrixCLIError: LocalizedError, CompanionErrorCoding {
    let code: String
    let message: String

    var companionErrorCode: String { code }
    var errorDescription: String? { message }
}
