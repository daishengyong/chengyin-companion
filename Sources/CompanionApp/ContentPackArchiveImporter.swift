import Darwin
import Foundation

enum ContentPackArchiveLayout: String, Codable, Equatable, Sendable {
    case flat
    case singleRoot = "single-root"
}

struct ContentPackArchiveInspection: Codable, Equatable, Sendable {
    let layout: ContentPackArchiveLayout
    let fileCount: Int
    let unpackedBytes: Int64
    let compressedBytes: Int64
}

struct ContentPackArchiveExtraction: Sendable {
    let packageDirectory: URL
    let workspaceDirectory: URL
    let inspection: ContentPackArchiveInspection
}

enum ContentPackArchiveError: LocalizedError, Equatable, CompanionErrorCoding {
    case invalidSource
    case invalidArchive
    case unsafeEntry
    case unsupportedFeature
    case resourceLimitExceeded
    case extractionFailed
    case packageRootMissing

    var companionErrorCode: String {
        switch self {
        case .invalidSource: "PACK_ARCHIVE_INVALID_SOURCE"
        case .invalidArchive: "PACK_ARCHIVE_INVALID_ZIP"
        case .unsafeEntry: "PACK_ARCHIVE_UNSAFE_ENTRY"
        case .unsupportedFeature: "PACK_ARCHIVE_UNSUPPORTED_FEATURE"
        case .resourceLimitExceeded: "PACK_ARCHIVE_RESOURCE_LIMIT"
        case .extractionFailed: "PACK_ARCHIVE_EXTRACTION_FAILED"
        case .packageRootMissing: "PACK_ARCHIVE_PACKAGE_ROOT_MISSING"
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidSource:
            "The selected .chengyinpack is missing, unsafe or above the archive-size limit."
        case .invalidArchive:
            "The selected .chengyinpack is not a well-formed ZIP archive."
        case .unsafeEntry:
            "The .chengyinpack contains an unsafe, colliding or non-normalized entry."
        case .unsupportedFeature:
            "The .chengyinpack uses encryption, ZIP64, links or another unsupported ZIP feature."
        case .resourceLimitExceeded:
            "The .chengyinpack exceeds the documented file, unpacked-size or compression-ratio limit."
        case .extractionFailed:
            "The .chengyinpack could not be extracted into the private staging area."
        case .packageRootMissing:
            "The .chengyinpack must contain manifest.json at archive root or inside one top-level directory."
        }
    }
}

/// Performs a bounded ZIP preflight before invoking the fixed macOS extractor.
///
/// The user-selected archive is first copied into a mode-0700 workspace. The
/// copied bytes, central directory and every referenced local header are then
/// checked before extraction, removing the source-path mutation race. The
/// transactional ContentPackStore still performs authoritative manifest,
/// checksum, media, signature and entitlement validation after extraction.
struct ContentPackArchiveImporter: Sendable {
    private let temporaryRoot: URL?

    init(temporaryRoot: URL? = nil) {
        self.temporaryRoot = temporaryRoot?.standardizedFileURL
    }

    func extract(from source: URL) throws -> ContentPackArchiveExtraction {
        let fileManager = FileManager.default
        guard source.pathExtension.lowercased() == "chengyinpack",
              try isRegularNonLink(source, fileManager: fileManager),
              try fileSize(source) <= ContentPackArchivePolicy.maximumArchiveBytes else {
            throw ContentPackArchiveError.invalidSource
        }

        let base = try prepareWorkspaceBase(fileManager: fileManager)
        let workspace = base.appendingPathComponent(
            "import-\(UUID().uuidString.lowercased())",
            isDirectory: true
        )
        do {
            try fileManager.createDirectory(
                at: workspace,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw ContentPackArchiveError.extractionFailed
        }

        do {
            let snapshot = workspace.appendingPathComponent(
                "input.chengyinpack",
                isDirectory: false
            )
            try fileManager.copyItem(at: source, to: snapshot)
            guard try isRegularNonLink(snapshot, fileManager: fileManager),
                  try fileSize(snapshot)
                    <= ContentPackArchivePolicy.maximumArchiveBytes else {
                throw ContentPackArchiveError.invalidSource
            }

            let parsed = try ContentPackArchivePolicy().inspect(snapshot)
            let extractionRoot = workspace.appendingPathComponent(
                "unpacked",
                isDirectory: true
            )
            try fileManager.createDirectory(
                at: extractionRoot,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
            try runFixedExtractor(snapshot: snapshot, destination: extractionRoot)
            try verifyExtraction(
                parsed,
                extractionRoot: extractionRoot,
                fileManager: fileManager
            )
            let packageDirectory: URL
            switch parsed.layout {
            case .flat:
                packageDirectory = extractionRoot
            case .singleRoot:
                guard let root = parsed.rootComponent else {
                    throw ContentPackArchiveError.packageRootMissing
                }
                packageDirectory = extractionRoot.appendingPathComponent(
                    root,
                    isDirectory: true
                )
            }
            let manifest = packageDirectory.appendingPathComponent("manifest.json")
            guard try isRegularNonLink(manifest, fileManager: fileManager) else {
                throw ContentPackArchiveError.packageRootMissing
            }
            return ContentPackArchiveExtraction(
                packageDirectory: packageDirectory,
                workspaceDirectory: workspace,
                inspection: parsed.inspection
            )
        } catch {
            try? fileManager.removeItem(at: workspace)
            if let archiveError = error as? ContentPackArchiveError {
                throw archiveError
            }
            throw ContentPackArchiveError.extractionFailed
        }
    }

    func removeExtraction(_ extraction: ContentPackArchiveExtraction) {
        try? FileManager.default.removeItem(at: extraction.workspaceDirectory)
    }

    private func prepareWorkspaceBase(fileManager: FileManager) throws -> URL {
        let base = temporaryRoot ?? fileManager.temporaryDirectory
            .appendingPathComponent("ChengyinContentImports", isDirectory: true)
        if fileManager.fileExists(atPath: base.path) {
            let values = try base.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            )
            guard values.isDirectory == true,
                  values.isSymbolicLink != true else {
                throw ContentPackArchiveError.extractionFailed
            }
        } else {
            try fileManager.createDirectory(
                at: base,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        guard chmod(base.path, 0o700) == 0 else {
            throw ContentPackArchiveError.extractionFailed
        }
        return base.standardizedFileURL
    }

    private func runFixedExtractor(snapshot: URL, destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", snapshot.path, destination.path]
        process.environment = ["LANG": "C", "PATH": "/usr/bin:/bin"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ContentPackArchiveError.extractionFailed
        }
        guard process.terminationReason == .exit,
              process.terminationStatus == 0 else {
            throw ContentPackArchiveError.extractionFailed
        }
    }

    private func verifyExtraction(
        _ archive: ContentPackArchivePolicyResult,
        extractionRoot: URL,
        fileManager: FileManager
    ) throws {
        let expectedFiles = Dictionary(
            uniqueKeysWithValues: archive.entries
                .filter { !$0.isDirectory }
                .map { ($0.path, $0.unpackedBytes) }
        )
        var allowedDirectories = Set<String>()
        for path in archive.entries.map(\.path) {
            let parts = path.split(separator: "/").map(String.init)
            guard parts.count > 1 else { continue }
            for length in 1..<parts.count {
                allowedDirectories.insert(parts.prefix(length).joined(separator: "/"))
            }
        }
        allowedDirectories.formUnion(
            archive.entries.filter(\.isDirectory).map(\.path)
        )

        guard let enumerator = fileManager.enumerator(
            at: extractionRoot,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey
            ],
            options: []
        ) else {
            throw ContentPackArchiveError.extractionFailed
        }
        let resolvedRoot = extractionRoot.resolvingSymlinksInPath().standardizedFileURL
        let resolvedPrefix = resolvedRoot.path + "/"
        var observedFiles = Set<String>()
        for case let url as URL in enumerator {
            let values = try url.resourceValues(
                forKeys: [
                    .isDirectoryKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                    .fileSizeKey
                ]
            )
            guard values.isSymbolicLink != true else {
                throw ContentPackArchiveError.unsafeEntry
            }
            let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL
            guard resolvedURL.path.hasPrefix(resolvedPrefix) else {
                throw ContentPackArchiveError.unsafeEntry
            }
            let relative = String(
                resolvedURL.path.dropFirst(resolvedPrefix.count)
            )
            if values.isDirectory == true {
                guard allowedDirectories.contains(relative) else {
                    throw ContentPackArchiveError.unsafeEntry
                }
            } else {
                guard values.isRegularFile == true,
                      let expectedSize = expectedFiles[relative],
                      Int64(values.fileSize ?? -1) == expectedSize else {
                    throw ContentPackArchiveError.unsafeEntry
                }
                observedFiles.insert(relative)
            }
        }
        guard observedFiles == Set(expectedFiles.keys) else {
            throw ContentPackArchiveError.extractionFailed
        }
    }

    private func fileSize(_ url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values.fileSize, size >= 0 else {
            throw ContentPackArchiveError.invalidSource
        }
        return Int64(size)
    }

    private func isRegularNonLink(
        _ url: URL,
        fileManager: FileManager
    ) throws -> Bool {
        let values = try url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        return values.isRegularFile == true && values.isSymbolicLink != true
    }
}
