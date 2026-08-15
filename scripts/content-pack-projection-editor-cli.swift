import Foundation

@main
private enum ContentPackProjectionEditorCLI {
    static func main() async {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            guard let path = arguments.first, path != "--help" else {
                printUsage()
                exit(arguments.first == "--help" ? 0 : 2)
            }

            var appVersion = "0.19.98"
            var assetID: String?
            var outputPath: String?
            var index = 1
            while index < arguments.count {
                switch arguments[index] {
                case "--app-version":
                    guard index + 1 < arguments.count else {
                        throw EditorError(
                            code: "CREATOR_PROJECTION_EDITOR_APP_VERSION_MISSING",
                            message: "--app-version requires a semantic version"
                        )
                    }
                    appVersion = arguments[index + 1]
                    index += 2
                case "--asset":
                    guard index + 1 < arguments.count else {
                        throw EditorError(
                            code: "CREATOR_PROJECTION_EDITOR_ASSET_MISSING",
                            message: "--asset requires a declared video asset ID"
                        )
                    }
                    assetID = arguments[index + 1]
                    index += 2
                case "--output":
                    guard index + 1 < arguments.count else {
                        throw EditorError(
                            code: "CREATOR_PROJECTION_EDITOR_OUTPUT_MISSING",
                            message: "--output requires an HTML path"
                        )
                    }
                    outputPath = arguments[index + 1]
                    index += 2
                default:
                    throw EditorError(
                        code: "CREATOR_PROJECTION_EDITOR_UNKNOWN_OPTION",
                        message: "Unknown option"
                    )
                }
            }
            guard let outputPath else {
                throw EditorError(
                    code: "CREATOR_PROJECTION_EDITOR_OUTPUT_MISSING",
                    message: "--output is required"
                )
            }

            let packageDirectory = URL(fileURLWithPath: path, isDirectory: true)
                .standardizedFileURL
            let outputURL = URL(fileURLWithPath: outputPath, isDirectory: false)
                .standardizedFileURL
            guard !isInside(outputURL, directory: packageDirectory) else {
                throw EditorError(
                    code: "CREATOR_PROJECTION_EDITOR_OUTPUT_INSIDE_PACK",
                    message: "Editor output must stay outside the pack"
                )
            }

            let manifest = try ContentPackValidator().loadAndValidate(
                packageDirectory: packageDirectory,
                currentAppVersion: appVersion
            )
            let videoAssets = manifest.assets.filter { $0.kind == .video }
            guard !videoAssets.isEmpty else {
                throw EditorError(
                    code: "CREATOR_PROJECTION_EDITOR_NO_VIDEO",
                    message: "The validated pack has no declared video asset"
                )
            }
            let asset: ContentPackAsset
            if let assetID {
                guard let requested = videoAssets.first(where: { $0.id == assetID }) else {
                    throw EditorError(
                        code: "CREATOR_PROJECTION_EDITOR_ASSET_NOT_FOUND",
                        message: "The requested video asset is not declared by this pack"
                    )
                }
                asset = requested
            } else {
                asset = videoAssets[0]
            }

            try await creatorContentPackMediaProbe().probe(
                packageDirectory: packageDirectory,
                manifest: ContentPackManifest(
                    schemaVersion: manifest.schemaVersion,
                    id: manifest.id,
                    version: manifest.version,
                    minAppVersion: manifest.minAppVersion,
                    tier: manifest.tier,
                    character: manifest.character,
                    locales: manifest.locales,
                    assets: [asset],
                    license: manifest.license,
                    experiences: [],
                    contribution: nil
                )
            )
            let html = try ContentPackProjectionEditor.render(
                packID: manifest.id,
                asset: asset,
                assetURL: packageDirectory.appendingPathComponent(asset.path),
                appVersion: appVersion,
                preferredLocale: manifest.locales.first ?? "en"
            )
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(html.utf8).write(to: outputURL, options: .atomic)
            print("PASS  \(manifest.id)@\(manifest.version) · \(asset.id)")
            print("EDITOR  \(outputURL.path)")
        } catch {
            let receipt = CompanionFailureReceipt(
                error: error,
                fallbackCode: "CREATOR_PROJECTION_EDITOR_UNEXPECTED_ERROR"
            )
            fputs(receipt.safeLog + "\n", stderr)
            exit(1)
        }
    }

    private static func printUsage() {
        print("Usage: projection-editor <pack-directory> --output editor.html [--asset id] [--app-version x.y.z]")
    }

    private static func isInside(_ file: URL, directory: URL) -> Bool {
        let root = directory.resolvingSymlinksInPath().path
        let candidate = file.resolvingSymlinksInPath().path
        return candidate == root || candidate.hasPrefix(root + "/")
    }
}

private struct EditorError: LocalizedError, CompanionErrorCoding {
    let code: String
    let message: String

    var errorDescription: String? { message }
    var companionErrorCode: String { code }
    var recoveryAction: String {
        switch code {
        case "CREATOR_PROJECTION_EDITOR_NO_VIDEO":
            "Declare and validate a local 16:9 video asset, then reopen the editor."
        case "CREATOR_PROJECTION_EDITOR_ASSET_NOT_FOUND":
            "List the manifest video asset IDs, choose one exactly, then retry."
        case "CREATOR_PROJECTION_EDITOR_OUTPUT_INSIDE_PACK":
            "Choose an output path outside the pack so its inventory remains reproducible."
        default:
            "Check the command options, validate the pack, then retry without changing media files."
        }
    }
}
