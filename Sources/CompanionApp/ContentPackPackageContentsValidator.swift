import Foundation

/// Enumerates one extracted package without following links and enforces the
/// declared-file, collision and aggregate resource envelope. It does not hash
/// media or interpret asset metadata.
struct ContentPackPackageContentsValidator {
    let fileManager: FileManager

    func validate(
        _ packageRoot: URL,
        declaredPaths: Set<String>
    ) throws {
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey
        ]
        guard let enumerator = fileManager.enumerator(
            at: packageRoot,
            includingPropertiesForKeys: keys,
            options: []
        ) else {
            throw ContentPackValidationError.manifestMissing
        }

        var fileCount = 0
        var unpackedBytes: Int64 = 0
        var foldedPaths = Set<String>()
        let rootPrefix = packageRoot.path.hasSuffix("/")
            ? packageRoot.path
            : packageRoot.path + "/"
        let controlFiles: Set<String> = ["manifest.json", "manifest.sig"]
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: Set(keys))
            let path = fileURL.standardizedFileURL.path
            guard path.hasPrefix(rootPrefix) else {
                throw ContentPackValidationError.assetOutsidePackage(path)
            }
            let relativePath = String(path.dropFirst(rootPrefix.count))
            let components = NSString(string: relativePath).pathComponents
            if components.contains(where: { $0.hasPrefix(".") }) {
                throw ContentPackValidationError.hiddenPathNotAllowed(relativePath)
            }
            let folded = relativePath.precomposedStringWithCanonicalMapping.lowercased()
            guard foldedPaths.insert(folded).inserted else {
                throw ContentPackValidationError.caseInsensitivePathCollision(relativePath)
            }
            if values.isSymbolicLink == true {
                throw ContentPackValidationError.symbolicLinkNotAllowed(relativePath)
            }
            if values.isDirectory == true {
                continue
            }
            guard values.isRegularFile == true else {
                throw ContentPackValidationError.unsupportedFileType(relativePath)
            }
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let referenceCount = (attributes[.referenceCount] as? NSNumber)?.intValue ?? 1
            if referenceCount > 1 {
                throw ContentPackValidationError.hardLinkNotAllowed(relativePath)
            }
            guard controlFiles.contains(relativePath) || declaredPaths.contains(relativePath) else {
                throw ContentPackValidationError.undeclaredFile(relativePath)
            }
            fileCount += 1
            unpackedBytes += Int64(values.fileSize ?? 0)
            if fileCount > ContentPackValidator.maximumFileCount {
                throw ContentPackValidationError.tooManyFiles(
                    actual: fileCount,
                    maximum: ContentPackValidator.maximumFileCount
                )
            }
            if unpackedBytes > ContentPackValidator.maximumUnpackedBytes {
                throw ContentPackValidationError.unpackedSizeTooLarge(
                    actual: unpackedBytes,
                    maximum: ContentPackValidator.maximumUnpackedBytes
                )
            }
        }
    }
}
