import Darwin
import Foundation

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(
        Data("usage: atomic-app-swap <candidate.app> <installed.app>\n".utf8)
    )
    exit(64)
}

let candidate = CommandLine.arguments[1]
let installed = CommandLine.arguments[2]

guard FileManager.default.fileExists(atPath: candidate),
      FileManager.default.fileExists(atPath: installed) else {
    FileHandle.standardError.write(
        Data("both app paths must exist before an atomic swap\n".utf8)
    )
    exit(66)
}

let result = candidate.withCString { candidatePath in
    installed.withCString { installedPath in
        renameatx_np(
            AT_FDCWD,
            candidatePath,
            AT_FDCWD,
            installedPath,
            UInt32(RENAME_SWAP)
        )
    }
}

guard result == 0 else {
    let message = String(cString: strerror(errno))
    FileHandle.standardError.write(
        Data("atomic app swap failed: \(message)\n".utf8)
    )
    exit(74)
}
