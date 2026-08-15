import Foundation

private struct AssetMigrationGap: Codable {
    let assetID: String
    let requiredRightsFields: [String]
    let requiredAccessibilityFields: [String]
    let requiredFallbackFields: [String]
}

private struct MigrationReceipt: Codable {
    let status: String
    let packID: String
    let packVersion: String
    let sourceSchemaVersion: Int
    let targetSchemaVersion: Int
    let sourceMode: String
    let writesPerformed: Bool
    let rightsInferred: Bool
    let preservedManifestFields: [String]
    let requiredPackageFields: [String]
    let assetGaps: [AssetMigrationGap]
    let recoveryAction: String
}

@main
private enum ContentPackMigrationCLI {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        do {
            guard let path = arguments.first, path != "--help" else {
                printUsage()
                exit(arguments.first == "--help" ? 0 : 2)
            }
            guard arguments.dropFirst().allSatisfy({ $0 == "--json" }) else {
                throw MigrationError(
                    code: "CREATOR_MIGRATION_UNKNOWN_OPTION",
                    message: "Only --json is supported"
                )
            }
            let directory = URL(fileURLWithPath: path, isDirectory: true)
                .standardizedFileURL
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(
                atPath: directory.path,
                isDirectory: &isDirectory
            ), isDirectory.boolValue else {
                throw MigrationError(
                    code: "CREATOR_MIGRATION_PACK_DIRECTORY_MISSING",
                    message: "Pack directory does not exist or is not a directory"
                )
            }

            let manifest = try ContentPackValidator().loadAndValidate(
                packageDirectory: directory,
                currentAppVersion: "999.0.0"
            )
            let receipt = makeReceipt(manifest)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: try encoder.encode(receipt), as: UTF8.self))
        } catch {
            let receipt = CompanionFailureReceipt(
                error: error,
                fallbackCode: "CREATOR_MIGRATION_UNEXPECTED_ERROR"
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(receipt) {
                print(String(decoding: data, as: UTF8.self))
            }
            exit(1)
        }
    }

    private static func makeReceipt(
        _ manifest: ContentPackManifest
    ) -> MigrationReceipt {
        let rightsByAsset = Dictionary(
            uniqueKeysWithValues: (manifest.contribution?.rights ?? []).map {
                ($0.assetID, $0)
            }
        )
        let accessByAsset = Dictionary(
            uniqueKeysWithValues: (manifest.contribution?.accessibility ?? []).map {
                ($0.assetID, $0)
            }
        )
        let fallbackByAsset = Dictionary(
            uniqueKeysWithValues: (manifest.contribution?.fallback.assets ?? []).map {
                ($0.assetID, $0)
            }
        )
        let gaps = manifest.assets.map { asset in
            let rights = rightsByAsset[asset.id]
            let access = accessByAsset[asset.id]
            var rightsFields: [String] = []
            if rights == nil { rightsFields.append("record") }
            if rights?.source == nil { rightsFields.append("source") }
            if rights?.author == nil { rightsFields.append("author") }
            if rights?.authorizationBasis == nil { rightsFields.append("authorizationBasis") }
            if rights?.allowedUses == nil { rightsFields.append("allowedUses") }
            if rights?.attribution == nil { rightsFields.append("attribution") }
            if rights?.review == nil { rightsFields.append("review") }

            var accessibilityFields: [String] = []
            if access == nil { accessibilityFields.append("record") }
            if [.video, .image].contains(asset.kind), access?.altText == nil {
                accessibilityFields.append("altText")
            }
            let audible = asset.kind == .audio
                || (asset.kind == .video && asset.hasNativeAudio == true)
            if audible, access?.captions == nil {
                accessibilityFields.append("captions")
            }
            if audible, access?.soundDescriptions == nil {
                accessibilityFields.append("soundDescriptions")
            }
            if access?.review == nil { accessibilityFields.append("review") }
            let fallbackFields = fallbackByAsset[asset.id] == nil
                ? ["assetID", "strategy"]
                : []
            return AssetMigrationGap(
                assetID: asset.id,
                requiredRightsFields: Array(Set(rightsFields)).sorted(),
                requiredAccessibilityFields: Array(Set(accessibilityFields)).sorted(),
                requiredFallbackFields: fallbackFields
            )
        }
        let packageFields = manifest.contribution?.package == nil
            ? [
                "source", "author", "provider", "origin", "license",
                "authorizationBasis", "allowedUses", "attribution",
                "adultFictionStatus", "evidenceID", "review"
            ]
            : []
        let hasGaps = !packageFields.isEmpty || gaps.contains {
            !$0.requiredRightsFields.isEmpty
                || !$0.requiredAccessibilityFields.isEmpty
                || !$0.requiredFallbackFields.isEmpty
        }
        return MigrationReceipt(
            status: hasGaps ? "MIGRATION_EVIDENCE_REQUIRED" : "STRICT_V2_COMPLETE",
            packID: manifest.id,
            packVersion: manifest.version,
            sourceSchemaVersion: manifest.schemaVersion,
            targetSchemaVersion: 2,
            sourceMode: manifest.contributionMode.rawValue,
            writesPerformed: false,
            rightsInferred: false,
            preservedManifestFields: [
                "id", "version", "minAppVersion", "tier", "character",
                "locales", "assets", "license", "experiences"
            ],
            requiredPackageFields: packageFields,
            assetGaps: gaps,
            recoveryAction: "Copy the preserved fields into a schema v2 draft, provide factual evidence for every listed gap, then run scripts/audit-content-pack.sh <pack-directory> --strict --json."
        )
    }

    private static func printUsage() {
        print(
            "Usage: plan-content-pack-v2-migration.sh <pack-directory> [--json]\n\nProduces a read-only migration receipt. It never infers rights or edits the pack."
        )
    }
}

private struct MigrationError: LocalizedError, CompanionErrorCoding {
    let code: String
    let message: String

    var companionErrorCode: String { code }
    var errorDescription: String? { message }
}
