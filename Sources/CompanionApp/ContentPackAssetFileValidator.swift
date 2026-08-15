import Foundation

/// Resolves and authenticates one declared asset under an extracted package.
/// It owns path, link, size, executable and SHA-256 checks, but no projection,
/// contribution or media-decoder policy.
struct ContentPackAssetFileValidator {
    private static let hashPattern = #"^[a-f0-9]{64}$"#
    private static let executableExtensions: Set<String> = [
        "app", "appex", "bundle", "command", "dylib", "exe", "framework",
        "js", "kext", "mach-o", "node", "pkg", "plugin", "py", "sh"
    ]

    let fileManager: FileManager

    func validate(
        _ asset: ContentPackAsset,
        packageRoot: URL
    ) throws {
        let trimmedPath = asset.path.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = NSString(string: trimmedPath).pathComponents
        guard !trimmedPath.isEmpty,
              !trimmedPath.hasPrefix("/"),
              !components.contains(".."),
              !components.contains("."),
              !trimmedPath.contains("\\") else {
            throw ContentPackValidationError.invalidAssetPath(asset.path)
        }

        let assetURL = packageRoot
            .appendingPathComponent(trimmedPath)
            .standardizedFileURL
        let resolvedURL = assetURL.resolvingSymlinksInPath()
        let rootPrefix = packageRoot.path.hasSuffix("/")
            ? packageRoot.path
            : packageRoot.path + "/"
        guard resolvedURL.path.hasPrefix(rootPrefix) else {
            throw ContentPackValidationError.assetOutsidePackage(asset.path)
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: assetURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            throw ContentPackValidationError.assetMissing(asset.path)
        }

        let values = try assetURL.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        if values.isSymbolicLink == true || resolvedURL.path != assetURL.path {
            throw ContentPackValidationError.symbolicLinkNotAllowed(asset.path)
        }
        guard values.isRegularFile == true else {
            throw ContentPackValidationError.assetMissing(asset.path)
        }

        let attributes = try fileManager.attributesOfItem(atPath: assetURL.path)
        let assetBytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard assetBytes <= ContentPackValidator.maximumSingleAssetBytes else {
            throw ContentPackValidationError.assetTooLarge(
                asset: asset.id,
                actual: assetBytes,
                maximum: ContentPackValidator.maximumSingleAssetBytes
            )
        }

        let pathExtension = assetURL.pathExtension.lowercased()
        if Self.executableExtensions.contains(pathExtension) ||
            fileManager.isExecutableFile(atPath: assetURL.path) {
            throw ContentPackValidationError.executableNotAllowed(asset.path)
        }

        guard Self.matches(asset.sha256, pattern: Self.hashPattern) else {
            throw ContentPackValidationError.invalidHash(asset.path)
        }
        guard try ContentPackValidator.sha256(of: assetURL) == asset.sha256 else {
            throw ContentPackValidationError.hashMismatch(path: asset.path)
        }
    }

    private static func matches(_ string: String, pattern: String) -> Bool {
        string.range(of: pattern, options: .regularExpression) != nil
    }
}
