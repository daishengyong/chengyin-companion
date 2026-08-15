import Foundation

private struct ArchiveAuditReceipt: Codable {
    let status: String
    let schemaVersion: String
    let packID: String
    let version: String
    let packSchemaVersion: Int
    let layout: String
    let fileCount: Int
    let unpackedBytes: Int64
    let compressedBytes: Int64
    let validationScope: String
    let writesPerformed: Bool
    let releaseState: String
}

@main
private enum ContentPackArchiveAuditCLI {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        do {
            guard let path = arguments.first, path != "--help" else {
                printUsage()
                exit(arguments.first == "--help" ? 0 : 2)
            }
            var appVersion = "0.19.98"
            var emitsJSON = false
            var index = 1
            while index < arguments.count {
                switch arguments[index] {
                case "--app-version":
                    guard index + 1 < arguments.count else {
                        throw ArchiveAuditCLIError(
                            code: "CREATOR_ARCHIVE_AUDIT_APP_VERSION_MISSING",
                            message: "--app-version requires a semantic version"
                        )
                    }
                    appVersion = arguments[index + 1]
                    index += 2
                case "--json":
                    emitsJSON = true
                    index += 1
                default:
                    throw ArchiveAuditCLIError(
                        code: "CREATOR_ARCHIVE_AUDIT_UNKNOWN_OPTION",
                        message: "The archive-audit command contains an unknown option"
                    )
                }
            }

            let archive = URL(fileURLWithPath: path, isDirectory: false)
                .standardizedFileURL
            let importer = ContentPackArchiveImporter()
            let extraction = try importer.extract(from: archive)
            defer { importer.removeExtraction(extraction) }
            let manifest = try ContentPackValidator().loadAndValidate(
                packageDirectory: extraction.packageDirectory,
                currentAppVersion: appVersion
            )
            try await creatorContentPackMediaProbe().probe(
                packageDirectory: extraction.packageDirectory,
                manifest: manifest
            )
            let receipt = ArchiveAuditReceipt(
                status: "PASS",
                schemaVersion: "chengyin.content-pack-archive-audit/v1",
                packID: manifest.id,
                version: manifest.version,
                packSchemaVersion: manifest.schemaVersion,
                layout: extraction.inspection.layout.rawValue,
                fileCount: extraction.inspection.fileCount,
                unpackedBytes: extraction.inspection.unpackedBytes,
                compressedBytes: extraction.inspection.compressedBytes,
                validationScope: "zip-structure-manifest-hashes-and-media-decode",
                writesPerformed: false,
                releaseState: "NOT_PUBLIC_RELEASE_READY"
            )
            if emitsJSON {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                print(String(decoding: try encoder.encode(receipt), as: UTF8.self))
            } else {
                print("PASS  \(manifest.id)@\(manifest.version)")
                print("      layout \(receipt.layout), \(receipt.fileCount) files")
                print("      archive safety, manifest hashes and media decode verified")
            }
        } catch {
            let receipt = CompanionFailureReceipt(
                error: error,
                fallbackCode: "CREATOR_ARCHIVE_AUDIT_UNEXPECTED_ERROR"
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

    private static func printUsage() {
        print(
            """
            Usage: audit-content-pack-archive.sh <archive.chengyinpack> [options]

              --app-version <x.y.z>  Validate minimum app version (default 0.19.98)
              --json                 Print a path-free machine-readable receipt
              --help                 Show this message
            """
        )
    }
}

private struct ArchiveAuditCLIError: LocalizedError, CompanionErrorCoding {
    let code: String
    let message: String

    var companionErrorCode: String { code }
    var errorDescription: String? { message }
}
