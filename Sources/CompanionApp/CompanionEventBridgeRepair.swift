import Darwin
import Foundation

enum CompanionEventBridgeRepairStatus: String, Equatable, Sendable {
    case ready
    case repaired
    case needsRepair
    case refused
    case failed
}

/// A path-free receipt suitable for UI, logs and issue reports. It never
/// exposes the event directory, username, home directory or a raw system error.
struct CompanionEventBridgeRepairReceipt: Equatable, Sendable {
    let status: CompanionEventBridgeRepairStatus
    let code: String?

    var isReady: Bool {
        status == .ready || status == .repaired
    }
}

/// Repairs only the app-owned event directory itself. An unexpected regular
/// file or symbolic link is preserved and refused; the repairer never renames,
/// removes or follows it. This deliberately small boundary is safe to invoke
/// from the local Doctor without a confirmation dialog.
struct CompanionEventBridgeRepairer {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func inspect(root: URL) -> CompanionEventBridgeRepairReceipt {
        do {
            let state = try entryState(root: root)
            switch state {
            case .missing, .directoryNeedsPermissions:
                return CompanionEventBridgeRepairReceipt(
                    status: .needsRepair,
                    code: nil
                )
            case .directoryReady:
                return CompanionEventBridgeRepairReceipt(status: .ready, code: nil)
            case .unsafeEntry:
                return refusedReceipt
            }
        } catch {
            return failedReceipt
        }
    }

    func repair(root: URL) -> CompanionEventBridgeRepairReceipt {
        do {
            let before = try entryState(root: root)
            switch before {
            case .unsafeEntry:
                return refusedReceipt
            case .directoryReady:
                return CompanionEventBridgeRepairReceipt(status: .ready, code: nil)
            case .missing:
                try fileManager.createDirectory(
                    at: root,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
            case .directoryNeedsPermissions:
                break
            }

            // Operate through a no-follow directory descriptor. A raced
            // replacement therefore fails instead of applying chmod to a
            // symbolic-link target.
            let descriptor = Darwin.open(
                root.path,
                O_RDONLY | O_DIRECTORY | O_NOFOLLOW
            )
            guard descriptor >= 0 else {
                return errno == ELOOP ? refusedReceipt : failedReceipt
            }
            defer { Darwin.close(descriptor) }
            var descriptorState = stat()
            guard fstat(descriptor, &descriptorState) == 0,
                  descriptorState.st_mode & S_IFMT == S_IFDIR else {
                return refusedReceipt
            }
            guard fchmod(descriptor, mode_t(0o700)) == 0,
                  fstat(descriptor, &descriptorState) == 0,
                  descriptorState.st_mode & mode_t(0o777) == mode_t(0o700)
            else {
                return failedReceipt
            }
            return CompanionEventBridgeRepairReceipt(status: .repaired, code: nil)
        } catch {
            return failedReceipt
        }
    }

    private enum EntryState: Equatable {
        case missing
        case directoryReady
        case directoryNeedsPermissions
        case unsafeEntry
    }

    private func entryState(root: URL) throws -> EntryState {
        var state = stat()
        guard lstat(root.path, &state) == 0 else {
            if errno == ENOENT {
                return .missing
            }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard state.st_mode & S_IFMT == S_IFDIR else {
            return .unsafeEntry
        }
        let modeIsPrivate = state.st_mode & mode_t(0o777) == mode_t(0o700)
        return modeIsPrivate
            && fileManager.isReadableFile(atPath: root.path)
            && fileManager.isWritableFile(atPath: root.path)
            ? .directoryReady
            : .directoryNeedsPermissions
    }

    private var refusedReceipt: CompanionEventBridgeRepairReceipt {
        CompanionEventBridgeRepairReceipt(
            status: .refused,
            code: "UI_RUNTIME_REPAIR_REFUSED"
        )
    }

    private var failedReceipt: CompanionEventBridgeRepairReceipt {
        CompanionEventBridgeRepairReceipt(
            status: .failed,
            code: "UI_RUNTIME_REPAIR_FAILED"
        )
    }
}
