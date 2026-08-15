import Foundation

struct ContentPackArchiveEntry: Equatable, Sendable {
    let path: String
    let isDirectory: Bool
    let unpackedBytes: Int64
}

struct ContentPackArchivePolicyResult: Equatable, Sendable {
    let entries: [ContentPackArchiveEntry]
    let layout: ContentPackArchiveLayout
    let rootComponent: String?
    let inspection: ContentPackArchiveInspection
}

/// Pure bounded parser for the ZIP central directory and referenced local
/// headers. It does not extract, write or invoke a process.
struct ContentPackArchivePolicy: Sendable {
    static let maximumArchiveBytes: Int64 = 512 * 1_024 * 1_024
    static let maximumFiles = 256
    static let maximumUnpackedBytes: Int64 = 1_500 * 1_024 * 1_024
    static let maximumEntryBytes: Int64 = 512 * 1_024 * 1_024
    static let maximumCentralDirectoryBytes: Int64 = 8 * 1_024 * 1_024
    static let compressionRatioThreshold = 200.0

    func inspect(_ archive: URL) throws -> ContentPackArchivePolicyResult {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: archive)
        } catch {
            throw ContentPackArchiveError.invalidArchive
        }
        defer { try? handle.close() }
        let archiveSize = try fileSize(archive)
        guard archiveSize >= 22,
              archiveSize <= Self.maximumArchiveBytes else {
            throw ContentPackArchiveError.invalidArchive
        }

        let tailSize = Int(min(archiveSize, 65_557))
        let tail = try read(
            handle,
            offset: UInt64(archiveSize - Int64(tailSize)),
            count: tailSize
        )
        guard let eocdOffset = endOfCentralDirectoryOffset(in: tail),
              let disk = tail.uint16LE(at: eocdOffset + 4),
              let centralDisk = tail.uint16LE(at: eocdOffset + 6),
              let entriesOnDisk = tail.uint16LE(at: eocdOffset + 8),
              let entryCount = tail.uint16LE(at: eocdOffset + 10),
              let centralSize32 = tail.uint32LE(at: eocdOffset + 12),
              let centralOffset32 = tail.uint32LE(at: eocdOffset + 16),
              disk == 0,
              centralDisk == 0,
              entriesOnDisk == entryCount,
              entryCount > 0,
              entryCount != UInt16.max,
              centralSize32 != UInt32.max,
              centralOffset32 != UInt32.max else {
            throw ContentPackArchiveError.unsupportedFeature
        }
        let centralSize = Int64(centralSize32)
        let centralOffset = Int64(centralOffset32)
        let absoluteEOCD = archiveSize - Int64(tailSize) + Int64(eocdOffset)
        guard centralSize <= Self.maximumCentralDirectoryBytes,
              centralOffset >= 0,
              centralSize >= 0,
              centralOffset + centralSize == absoluteEOCD else {
            throw ContentPackArchiveError.invalidArchive
        }
        let central = try read(
            handle,
            offset: UInt64(centralOffset),
            count: Int(centralSize)
        )

        var cursor = 0
        var entries: [ContentPackArchiveEntry] = []
        var exactNames = Set<String>()
        var nodes: [String: ArchiveNode] = [:]
        var payloadIntervals: [Range<Int64>] = []
        var fileCount = 0
        var unpackedBytes: Int64 = 0
        var compressedBytes: Int64 = 0

        for _ in 0..<Int(entryCount) {
            guard central.uint32LE(at: cursor) == 0x0201_4B50,
                  let versionMadeBy = central.uint16LE(at: cursor + 4),
                  let flags = central.uint16LE(at: cursor + 8),
                  let method = central.uint16LE(at: cursor + 10),
                  let compressed32 = central.uint32LE(at: cursor + 20),
                  let unpacked32 = central.uint32LE(at: cursor + 24),
                  let nameLength = central.uint16LE(at: cursor + 28),
                  let extraLength = central.uint16LE(at: cursor + 30),
                  let commentLength = central.uint16LE(at: cursor + 32),
                  let startDisk = central.uint16LE(at: cursor + 34),
                  let externalAttributes = central.uint32LE(at: cursor + 38),
                  let localOffset32 = central.uint32LE(at: cursor + 42) else {
                throw ContentPackArchiveError.invalidArchive
            }
            guard compressed32 != UInt32.max,
                  unpacked32 != UInt32.max,
                  localOffset32 != UInt32.max,
                  startDisk == 0 else {
                throw ContentPackArchiveError.unsupportedFeature
            }
            let recordLength = 46
                + Int(nameLength)
                + Int(extraLength)
                + Int(commentLength)
            guard nameLength > 0,
                  nameLength <= 1_024,
                  cursor + recordLength <= central.count else {
                throw ContentPackArchiveError.invalidArchive
            }
            let nameData = central.subdata(
                in: (cursor + 46)..<(cursor + 46 + Int(nameLength))
            )
            guard let name = String(data: nameData, encoding: .utf8) else {
                throw ContentPackArchiveError.unsafeEntry
            }
            let isDirectory = name.hasSuffix("/")
            try validateFlags(flags, method: method)
            try validateEntryMode(
                versionMadeBy: versionMadeBy,
                externalAttributes: externalAttributes,
                isDirectory: isDirectory
            )
            let components = try validatePath(
                name,
                isDirectory: isDirectory,
                exactNames: &exactNames,
                nodes: &nodes
            )
            let compressed = Int64(compressed32)
            let unpacked = Int64(unpacked32)
            if isDirectory {
                guard compressed == 0, unpacked == 0 else {
                    throw ContentPackArchiveError.invalidArchive
                }
            } else {
                fileCount += 1
                guard fileCount <= Self.maximumFiles,
                      unpacked <= Self.maximumEntryBytes else {
                    throw ContentPackArchiveError.resourceLimitExceeded
                }
                unpackedBytes += unpacked
                compressedBytes += compressed
                guard unpackedBytes <= Self.maximumUnpackedBytes else {
                    throw ContentPackArchiveError.resourceLimitExceeded
                }
                if unpacked > 16 * 1_024 * 1_024 {
                    guard compressed > 0,
                          Double(unpacked) / Double(compressed)
                            <= Self.compressionRatioThreshold else {
                        throw ContentPackArchiveError.resourceLimitExceeded
                    }
                }
            }

            let localOffset = Int64(localOffset32)
            let payloadRange = try validateLocalHeader(
                handle,
                archiveSize: archiveSize,
                centralOffset: centralOffset,
                localOffset: localOffset,
                expectedName: nameData,
                expectedFlags: flags,
                expectedMethod: method,
                expectedCompressed: compressed32,
                expectedUnpacked: unpacked32
            )
            payloadIntervals.append(payloadRange)
            entries.append(
                ContentPackArchiveEntry(
                    path: components.joined(separator: "/"),
                    isDirectory: isDirectory,
                    unpackedBytes: unpacked
                )
            )
            cursor += recordLength
        }
        guard cursor == central.count,
              fileCount > 0 else {
            throw ContentPackArchiveError.invalidArchive
        }
        let sortedIntervals = payloadIntervals.sorted {
            $0.lowerBound < $1.lowerBound
        }
        for pair in zip(sortedIntervals, sortedIntervals.dropFirst()) {
            guard pair.0.upperBound <= pair.1.lowerBound else {
                throw ContentPackArchiveError.unsafeEntry
            }
        }

        let paths = Set(entries.map(\.path))
        let layout: ContentPackArchiveLayout
        let rootComponent: String?
        if paths.contains("manifest.json") {
            layout = .flat
            rootComponent = nil
        } else {
            let roots = Set(entries.compactMap {
                $0.path.split(separator: "/").first.map(String.init)
            })
            guard roots.count == 1,
                  let root = roots.first,
                  paths.contains("\(root)/manifest.json") else {
                throw ContentPackArchiveError.packageRootMissing
            }
            layout = .singleRoot
            rootComponent = root
        }
        return ContentPackArchivePolicyResult(
            entries: entries,
            layout: layout,
            rootComponent: rootComponent,
            inspection: ContentPackArchiveInspection(
                layout: layout,
                fileCount: fileCount,
                unpackedBytes: unpackedBytes,
                compressedBytes: compressedBytes
            )
        )
    }

    private func validateFlags(_ flags: UInt16, method: UInt16) throws {
        guard flags & 0x0001 == 0,
              flags & 0x0040 == 0,
              flags & 0x2000 == 0,
              method == 0 || method == 8 else {
            throw ContentPackArchiveError.unsupportedFeature
        }
    }

    private func validateEntryMode(
        versionMadeBy: UInt16,
        externalAttributes: UInt32,
        isDirectory: Bool
    ) throws {
        let creatorSystem = UInt8((versionMadeBy >> 8) & 0xFF)
        guard creatorSystem == 3 else { return }
        let mode = UInt16((externalAttributes >> 16) & 0xFFFF)
        let fileType = mode & 0o170000
        guard fileType != 0o120000,
              fileType == 0
                || (isDirectory && fileType == 0o040000)
                || (!isDirectory && fileType == 0o100000) else {
            throw ContentPackArchiveError.unsupportedFeature
        }
    }

    private func validatePath(
        _ rawName: String,
        isDirectory: Bool,
        exactNames: inout Set<String>,
        nodes: inout [String: ArchiveNode]
    ) throws -> [String] {
        guard !rawName.isEmpty,
              !rawName.hasPrefix("/"),
              !rawName.contains("\\"),
              !rawName.contains("\0") else {
            throw ContentPackArchiveError.unsafeEntry
        }
        let trimmed = isDirectory ? String(rawName.dropLast()) : rawName
        let components = trimmed
            .split(separator: "/", omittingEmptySubsequences: false)
            .map(String.init)
        guard !components.isEmpty,
              components.allSatisfy({
                  !$0.isEmpty
                    && $0 != "."
                    && $0 != ".."
                    && !$0.hasPrefix(".")
                    && $0.utf8.count <= 255
              }),
              exactNames.insert(rawName).inserted else {
            throw ContentPackArchiveError.unsafeEntry
        }
        var displayParts: [String] = []
        var canonicalParts: [String] = []
        for (index, component) in components.enumerated() {
            let display = component.precomposedStringWithCanonicalMapping
            let canonical = display.lowercased(
                with: Locale(identifier: "en_US_POSIX")
            )
            displayParts.append(display)
            canonicalParts.append(canonical)
            let displayPath = displayParts.joined(separator: "/")
            let canonicalPath = canonicalParts.joined(separator: "/")
            let nodeIsDirectory = index < components.count - 1 || isDirectory
            if let existing = nodes[canonicalPath] {
                guard existing.displayPath == displayPath,
                      existing.isDirectory == nodeIsDirectory else {
                    throw ContentPackArchiveError.unsafeEntry
                }
            } else {
                nodes[canonicalPath] = ArchiveNode(
                    displayPath: displayPath,
                    isDirectory: nodeIsDirectory
                )
            }
        }
        return components
    }

    private func validateLocalHeader(
        _ handle: FileHandle,
        archiveSize: Int64,
        centralOffset: Int64,
        localOffset: Int64,
        expectedName: Data,
        expectedFlags: UInt16,
        expectedMethod: UInt16,
        expectedCompressed: UInt32,
        expectedUnpacked: UInt32
    ) throws -> Range<Int64> {
        guard localOffset >= 0,
              localOffset + 30 <= centralOffset else {
            throw ContentPackArchiveError.invalidArchive
        }
        let header = try read(handle, offset: UInt64(localOffset), count: 30)
        guard header.uint32LE(at: 0) == 0x0403_4B50,
              header.uint16LE(at: 6) == expectedFlags,
              header.uint16LE(at: 8) == expectedMethod,
              let compressed = header.uint32LE(at: 18),
              let unpacked = header.uint32LE(at: 22),
              let nameLength = header.uint16LE(at: 26),
              let extraLength = header.uint16LE(at: 28),
              Int(nameLength) == expectedName.count else {
            throw ContentPackArchiveError.invalidArchive
        }
        if expectedFlags & 0x0008 == 0 {
            guard compressed == expectedCompressed,
                  unpacked == expectedUnpacked else {
                throw ContentPackArchiveError.invalidArchive
            }
        }
        let localName = try read(
            handle,
            offset: UInt64(localOffset + 30),
            count: Int(nameLength)
        )
        guard localName == expectedName else {
            throw ContentPackArchiveError.unsafeEntry
        }
        let payloadStart = localOffset
            + 30
            + Int64(nameLength)
            + Int64(extraLength)
        let payloadEnd = payloadStart + Int64(expectedCompressed)
        guard payloadStart >= localOffset,
              payloadEnd >= payloadStart,
              payloadEnd <= centralOffset,
              payloadEnd <= archiveSize else {
            throw ContentPackArchiveError.invalidArchive
        }
        return localOffset..<payloadEnd
    }

    private func endOfCentralDirectoryOffset(in tail: Data) -> Int? {
        guard tail.count >= 22 else { return nil }
        for offset in stride(from: tail.count - 22, through: 0, by: -1) {
            guard tail.uint32LE(at: offset) == 0x0605_4B50,
                  let commentLength = tail.uint16LE(at: offset + 20),
                  offset + 22 + Int(commentLength) == tail.count else {
                continue
            }
            return offset
        }
        return nil
    }

    private func read(
        _ handle: FileHandle,
        offset: UInt64,
        count: Int
    ) throws -> Data {
        guard count >= 0 else { throw ContentPackArchiveError.invalidArchive }
        do {
            try handle.seek(toOffset: offset)
            guard let data = try handle.read(upToCount: count),
                  data.count == count else {
                throw ContentPackArchiveError.invalidArchive
            }
            return data
        } catch let error as ContentPackArchiveError {
            throw error
        } catch {
            throw ContentPackArchiveError.invalidArchive
        }
    }

    private func fileSize(_ url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values.fileSize, size >= 0 else {
            throw ContentPackArchiveError.invalidArchive
        }
        return Int64(size)
    }
}

private struct ArchiveNode {
    let displayPath: String
    let isDirectory: Bool
}

private extension Data {
    func uint16LE(at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= count else { return nil }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func uint32LE(at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= count else { return nil }
        return UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }
}
