import Foundation

/// Keeps the public validation surface stable while separating package
/// enumeration, asset-file authentication and pure projection policy.
struct ContentPackAssetValidator {
    private let packageContentsValidator: ContentPackPackageContentsValidator
    private let assetFileValidator: ContentPackAssetFileValidator
    private let projectionValidator = ContentPackAssetProjectionValidator()

    init(fileManager: FileManager) {
        packageContentsValidator = ContentPackPackageContentsValidator(
            fileManager: fileManager
        )
        assetFileValidator = ContentPackAssetFileValidator(
            fileManager: fileManager
        )
    }

    func validatePackageContents(
        _ packageRoot: URL,
        declaredPaths: Set<String>
    ) throws {
        try packageContentsValidator.validate(
            packageRoot,
            declaredPaths: declaredPaths
        )
    }

    func validate(
        _ asset: ContentPackAsset,
        packageRoot: URL
    ) throws {
        try assetFileValidator.validate(asset, packageRoot: packageRoot)
        try projectionValidator.validate(asset)
    }
}
