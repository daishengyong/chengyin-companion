#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Darwin
import Foundation

enum CompanionEventSpoolStatus: String, Equatable, Sendable {
    case ready
    case rootUnavailable
    case rootUnsafe
    case entryLimitExceeded

    var companionErrorCode: String? {
        switch self {
        case .ready:
            nil
        case .rootUnavailable:
            "EVENT_SPOOL_ROOT_UNAVAILABLE"
        case .rootUnsafe:
            "EVENT_SPOOL_ROOT_UNSAFE"
        case .entryLimitExceeded:
            "EVENT_SPOOL_ENTRY_LIMIT_EXCEEDED"
        }
    }
}

struct CompanionEventSpoolEntry: Equatable, Sendable {
    let eventID: String
    let data: Data
}

struct CompanionEventSpoolScanReceipt: Equatable, Sendable {
    let status: CompanionEventSpoolStatus
    let entries: [CompanionEventSpoolEntry]
    let ignoredEntryCount: Int
    let prunedEntryCount: Int

    var isReady: Bool { status == .ready }
    var companionErrorCode: String? { status.companionErrorCode }
}

/// Reads the app-owned Companion Event inbox through a no-follow directory
/// descriptor. It accepts only current-user, single-link, 0600 regular files
/// whose filename is the UUID encoded inside the event. Old and excess safe
/// event files are pruned through the already-open directory; unexpected
/// entries are preserved and ignored.
///
/// These checks protect against accidental links, broad permissions, malformed
/// files and unbounded normal use. They do not claim to defeat another active
/// process running as the same user and racing every local filesystem call.
struct CompanionEventSpool {
    static let defaultMaximumRetainedFiles = 512
    static let defaultMaximumDirectoryEntries = 4_096
    static let defaultMaximumAge: TimeInterval = 36 * 60 * 60

    private struct Fingerprint: Equatable {
        let device: UInt64
        let inode: UInt64
        let modificationNanoseconds: Int64
        let size: Int64
    }

    private struct Candidate {
        let name: String
        let eventID: String
        let fingerprint: Fingerprint
        let modificationDate: Date
        let readableSize: Int?
    }

    private let maximumRetainedFiles: Int
    private let maximumDirectoryEntries: Int
    private let maximumAge: TimeInterval
    private var fingerprints: [String: Fingerprint] = [:]

    init(
        maximumRetainedFiles: Int = Self.defaultMaximumRetainedFiles,
        maximumDirectoryEntries: Int = Self.defaultMaximumDirectoryEntries,
        maximumAge: TimeInterval = Self.defaultMaximumAge
    ) {
        self.maximumRetainedFiles = max(1, maximumRetainedFiles)
        self.maximumDirectoryEntries = max(1, maximumDirectoryEntries)
        self.maximumAge = maximumAge.isFinite ? max(1, maximumAge) : Self.defaultMaximumAge
    }

    func inspectRoot(_ root: URL) -> CompanionEventSpoolStatus {
        guard let descriptor = openRoot(root) else {
            return rootFailureStatus(root)
        }
        defer { Darwin.close(descriptor) }
        return rootDescriptorIsPrivate(descriptor) ? .ready : .rootUnsafe
    }

    mutating func scan(
        root: URL,
        now: Date = Date()
    ) -> CompanionEventSpoolScanReceipt {
        guard let rootDescriptor = openRoot(root) else {
            fingerprints.removeAll(keepingCapacity: true)
            return receipt(status: rootFailureStatus(root))
        }
        defer { Darwin.close(rootDescriptor) }
        guard rootDescriptorIsPrivate(rootDescriptor) else {
            fingerprints.removeAll(keepingCapacity: true)
            return receipt(status: .rootUnsafe)
        }

        guard let names = entryNames(rootDescriptor) else {
            fingerprints.removeAll(keepingCapacity: true)
            return receipt(status: .rootUnavailable)
        }
        guard names.count <= maximumDirectoryEntries else {
            fingerprints.removeAll(keepingCapacity: true)
            return receipt(status: .entryLimitExceeded)
        }

        var ignored = 0
        var pruned = 0
        var candidates: [Candidate] = []
        candidates.reserveCapacity(min(names.count, maximumRetainedFiles))

        for name in names {
            guard let eventID = eventID(from: name),
                  let candidate = candidate(
                    name: name,
                    eventID: eventID,
                    rootDescriptor: rootDescriptor
                  ) else {
                ignored += 1
                continue
            }
            if now.timeIntervalSince(candidate.modificationDate) > maximumAge {
                if safelyUnlink(candidate, rootDescriptor: rootDescriptor) {
                    pruned += 1
                } else {
                    ignored += 1
                }
                continue
            }
            candidates.append(candidate)
        }

        candidates.sort {
            if $0.modificationDate == $1.modificationDate {
                return $0.name < $1.name
            }
            return $0.modificationDate > $1.modificationDate
        }

        if candidates.count > maximumRetainedFiles {
            for candidate in candidates.dropFirst(maximumRetainedFiles) {
                if safelyUnlink(candidate, rootDescriptor: rootDescriptor) {
                    pruned += 1
                } else {
                    ignored += 1
                }
            }
            candidates.removeSubrange(maximumRetainedFiles...)
        }

        var currentFingerprints: [String: Fingerprint] = [:]
        var entries: [CompanionEventSpoolEntry] = []
        currentFingerprints.reserveCapacity(candidates.count)

        for candidate in candidates {
            currentFingerprints[candidate.name] = candidate.fingerprint
            guard fingerprints[candidate.name] != candidate.fingerprint else {
                continue
            }
            guard let readableSize = candidate.readableSize,
                  let data = read(
                    candidate,
                    expectedSize: readableSize,
                    rootDescriptor: rootDescriptor
                  ) else {
                ignored += 1
                continue
            }
            entries.append(
                CompanionEventSpoolEntry(
                    eventID: candidate.eventID,
                    data: data
                )
            )
        }

        fingerprints = currentFingerprints
        return CompanionEventSpoolScanReceipt(
            status: .ready,
            entries: entries,
            ignoredEntryCount: ignored,
            prunedEntryCount: pruned
        )
    }

    private func receipt(status: CompanionEventSpoolStatus) -> CompanionEventSpoolScanReceipt {
        CompanionEventSpoolScanReceipt(
            status: status,
            entries: [],
            ignoredEntryCount: 0,
            prunedEntryCount: 0
        )
    }

    private func openRoot(_ root: URL) -> Int32? {
        let descriptor = Darwin.open(
            root.path,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        return descriptor >= 0 ? descriptor : nil
    }

    private func rootFailureStatus(_ root: URL) -> CompanionEventSpoolStatus {
        var state = stat()
        guard lstat(root.path, &state) == 0 else {
            return .rootUnavailable
        }
        return .rootUnsafe
    }

    private func rootDescriptorIsPrivate(_ descriptor: Int32) -> Bool {
        var state = stat()
        return fstat(descriptor, &state) == 0
            && state.st_mode & S_IFMT == S_IFDIR
            && state.st_uid == geteuid()
            && state.st_mode & mode_t(0o777) == mode_t(0o700)
    }

    private func entryNames(_ rootDescriptor: Int32) -> [String]? {
        let duplicateDescriptor = Darwin.dup(rootDescriptor)
        guard duplicateDescriptor >= 0 else { return nil }
        guard let directory = fdopendir(duplicateDescriptor) else {
            Darwin.close(duplicateDescriptor)
            return nil
        }
        defer { closedir(directory) }

        var names: [String] = []
        while let entry = readdir(directory) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String(cString: $0)
                }
            }
            if name == "." || name == ".." { continue }
            names.append(name)
            if names.count > maximumDirectoryEntries {
                break
            }
        }
        return names
    }

    private func eventID(from name: String) -> String? {
        guard name.utf8.count <= 64,
              name.hasSuffix(".json") else {
            return nil
        }
        let stem = String(name.dropLast(5))
        guard UUID(uuidString: stem) != nil else { return nil }
        return stem
    }

    private func candidate(
        name: String,
        eventID: String,
        rootDescriptor: Int32
    ) -> Candidate? {
        let descriptor = Darwin.openat(
            rootDescriptor,
            name,
            O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK
        )
        guard descriptor >= 0 else { return nil }
        defer { Darwin.close(descriptor) }

        var state = stat()
        guard fstat(descriptor, &state) == 0,
              state.st_mode & S_IFMT == S_IFREG,
              state.st_uid == geteuid(),
              state.st_nlink == 1,
              state.st_mode & mode_t(0o777) == mode_t(0o600),
              state.st_size >= 0 else {
            return nil
        }

        let fingerprint = Self.fingerprint(state)
        let readableSize = state.st_size > 0
            && state.st_size <= CompanionEventCodec.maximumPayloadBytes
            ? Int(state.st_size)
            : nil
        return Candidate(
            name: name,
            eventID: eventID,
            fingerprint: fingerprint,
            modificationDate: Self.modificationDate(state),
            readableSize: readableSize
        )
    }

    private func read(
        _ candidate: Candidate,
        expectedSize: Int,
        rootDescriptor: Int32
    ) -> Data? {
        let descriptor = Darwin.openat(
            rootDescriptor,
            candidate.name,
            O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK
        )
        guard descriptor >= 0 else { return nil }
        defer { Darwin.close(descriptor) }

        var before = stat()
        guard fstat(descriptor, &before) == 0,
              Self.fingerprint(before) == candidate.fingerprint else {
            return nil
        }

        var result = Data()
        result.reserveCapacity(expectedSize)
        var buffer = [UInt8](repeating: 0, count: min(8_192, expectedSize + 1))
        while result.count <= expectedSize {
            let count = buffer.withUnsafeMutableBytes {
                Darwin.read(descriptor, $0.baseAddress, $0.count)
            }
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                return nil
            }
            result.append(buffer, count: count)
            if result.count > expectedSize { return nil }
        }

        var after = stat()
        guard result.count == expectedSize,
              fstat(descriptor, &after) == 0,
              Self.fingerprint(after) == candidate.fingerprint else {
            return nil
        }
        return result
    }

    private func safelyUnlink(
        _ candidate: Candidate,
        rootDescriptor: Int32
    ) -> Bool {
        var current = stat()
        guard fstatat(
            rootDescriptor,
            candidate.name,
            &current,
            AT_SYMLINK_NOFOLLOW
        ) == 0,
        current.st_mode & S_IFMT == S_IFREG,
        current.st_uid == geteuid(),
        current.st_nlink == 1,
        current.st_mode & mode_t(0o777) == mode_t(0o600),
        Self.fingerprint(current) == candidate.fingerprint else {
            return false
        }
        return unlinkat(rootDescriptor, candidate.name, 0) == 0
    }

    private static func fingerprint(_ state: stat) -> Fingerprint {
        Fingerprint(
            device: UInt64(state.st_dev),
            inode: UInt64(state.st_ino),
            modificationNanoseconds: Int64(state.st_mtimespec.tv_sec) * 1_000_000_000
                + Int64(state.st_mtimespec.tv_nsec),
            size: Int64(state.st_size)
        )
    }

    private static func modificationDate(_ state: stat) -> Date {
        Date(
            timeIntervalSince1970: TimeInterval(state.st_mtimespec.tv_sec)
                + TimeInterval(state.st_mtimespec.tv_nsec) / 1_000_000_000
        )
    }
}
