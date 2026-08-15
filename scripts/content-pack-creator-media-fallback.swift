import Foundation

struct FixedFFmpegContentPackVideoDecodeFallback:
    ContentPackVideoDecodeFallback {
    let executableURL: URL

    var backendID: String {
        "fixed-ffmpeg-full-software-decode"
    }

    static func available() -> Self? {
        guard ProcessInfo.processInfo.environment["CODEX_SANDBOX"] != nil else {
            return nil
        }
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg",
        ]
        for candidate in candidates {
            let url = URL(fileURLWithPath: candidate)
                .resolvingSymlinksInPath()
                .standardizedFileURL
            let path = url.path
            let allowed = path == "/usr/bin/ffmpeg"
                || path.hasPrefix("/opt/homebrew/Cellar/ffmpeg/")
                || path.hasPrefix("/usr/local/Cellar/ffmpeg/")
            if allowed,
               FileManager.default.isExecutableFile(atPath: path) {
                return Self(executableURL: url)
            }
        }
        return nil
    }

    func decodeVideo(
        at url: URL,
        declarationID: String
    ) throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "-nostdin",
            "-hide_banner",
            "-loglevel", "error",
            "-xerror",
            "-threads", "1",
            "-i", url.path,
            "-map", "0:v:0",
            "-map", "0:a?",
            "-f", "null",
            "-",
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw ContentPackMediaProbeError.firstFrameDecodeFailed(
                declarationID
            )
        }
        let deadline = Date().addingTimeInterval(20)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            throw ContentPackMediaProbeError.firstFrameDecodeFailed(
                declarationID
            )
        }
        guard process.terminationReason == .exit,
              process.terminationStatus == 0 else {
            throw ContentPackMediaProbeError.firstFrameDecodeFailed(
                declarationID
            )
        }
    }
}

func creatorContentPackMediaProbe() -> AVFoundationContentPackMediaProbe {
    AVFoundationContentPackMediaProbe(
        videoDecodeFallback:
            FixedFFmpegContentPackVideoDecodeFallback.available()
    )
}

func creatorMediaValidationBackendID() -> String {
    if let fallback = FixedFFmpegContentPackVideoDecodeFallback.available() {
        return "avfoundation+\(fallback.backendID)"
    }
    return "avfoundation"
}
