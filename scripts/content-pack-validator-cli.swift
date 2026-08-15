import Foundation

private struct ValidationReceipt: Codable {
    let status: String
    let packID: String
    let version: String
    let schemaVersion: Int
    let assetCount: Int
    let experienceCount: Int
    let locales: [String]
    let contributionMode: String
}

@main
private enum ContentPackValidatorCLI {
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
                        throw CLIError(
                            code: "CREATOR_CLI_APP_VERSION_MISSING",
                            message: "--app-version requires a semantic version"
                        )
                    }
                    appVersion = arguments[index + 1]
                    index += 2
                case "--json":
                    emitsJSON = true
                    index += 1
                default:
                    throw CLIError(
                        code: "CREATOR_CLI_UNKNOWN_OPTION",
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
                throw CLIError(
                    code: "CREATOR_CLI_PACK_DIRECTORY_MISSING",
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

            let receipt = ValidationReceipt(
                status: "PASS",
                packID: manifest.id,
                version: manifest.version,
                schemaVersion: manifest.schemaVersion,
                assetCount: manifest.assets.count,
                experienceCount: manifest.experiences?.count ?? 0,
                locales: manifest.locales,
                contributionMode: manifest.contributionMode.rawValue
            )
            if emitsJSON {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                print(String(decoding: try encoder.encode(receipt), as: UTF8.self))
            } else {
                print("PASS  \(manifest.id)@\(manifest.version)")
                print("      schema \(manifest.schemaVersion), \(manifest.assets.count) assets, \(manifest.experiences?.count ?? 0) experiences")
                print("      locales: \(manifest.locales.joined(separator: ", "))")
            }
        } catch {
            let receipt = CompanionFailureReceipt(
                error: error,
                fallbackCode: "CREATOR_CLI_UNEXPECTED_ERROR"
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
            Usage: validate-content-pack.sh <pack-directory> [options]

              --app-version <x.y.z>  Validate the minimum app version (default 0.19.98)
              --json                 Print a machine-readable validation receipt
              --help                 Show this message
            """
        )
    }
}

private struct CLIError: LocalizedError, CompanionErrorCoding {
    let code: String
    let message: String

    init(code: String, message: String) {
        self.code = code
        self.message = message
    }

    var companionErrorCode: String { code }
    var errorDescription: String? { message }
}
