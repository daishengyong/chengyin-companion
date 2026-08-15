import Darwin
import Foundation

/// Process-wide serialization for the private content-pack transaction root.
/// The lock is deliberately local-only and never exposes its filesystem path.
final class ContentPackStoreFileLock {
    private var fileDescriptor: Int32

    private init(fileDescriptor: Int32) {
        self.fileDescriptor = fileDescriptor
    }

    static func acquire(at url: URL) throws -> ContentPackStoreFileLock {
        let descriptor = open(url.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        guard flock(descriptor, LOCK_EX) == 0 else {
            let code = errno
            close(descriptor)
            throw POSIXError(.init(rawValue: code) ?? .EIO)
        }
        return ContentPackStoreFileLock(fileDescriptor: descriptor)
    }

    func release() {
        guard fileDescriptor >= 0 else { return }
        _ = flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
        fileDescriptor = -1
    }

    deinit {
        release()
    }
}

/// Publishes one active-pointer record only after its bytes and containing
/// directory are durable. A failed write unlinks only its exact private temp.
enum ContentPackAtomicFileWriter {
    static func write(_ data: Data, to destination: URL) throws {
        let parent = destination.deletingLastPathComponent()
        let temporary = parent.appendingPathComponent(
            ".\(destination.lastPathComponent).\(UUID().uuidString).tmp"
        )
        let descriptor = open(
            temporary.path,
            O_CREAT | O_EXCL | O_WRONLY,
            S_IRUSR | S_IWUSR
        )
        guard descriptor >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }

        do {
            try data.withUnsafeBytes { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress else { return }
                var offset = 0
                while offset < rawBuffer.count {
                    let written = Darwin.write(
                        descriptor,
                        baseAddress.advanced(by: offset),
                        rawBuffer.count - offset
                    )
                    guard written >= 0 else {
                        throw POSIXError(.init(rawValue: errno) ?? .EIO)
                    }
                    offset += written
                }
            }
            guard fsync(descriptor) == 0 else {
                throw POSIXError(.init(rawValue: errno) ?? .EIO)
            }
            close(descriptor)
            guard rename(temporary.path, destination.path) == 0 else {
                throw POSIXError(.init(rawValue: errno) ?? .EIO)
            }
            let parentDescriptor = open(parent.path, O_RDONLY)
            if parentDescriptor >= 0 {
                _ = fsync(parentDescriptor)
                close(parentDescriptor)
            }
        } catch {
            close(descriptor)
            _ = unlink(temporary.path)
            throw error
        }
    }
}
