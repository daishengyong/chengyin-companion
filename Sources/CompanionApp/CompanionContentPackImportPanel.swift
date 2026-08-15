import AppKit
import Foundation
import UniformTypeIdentifiers

/// One focused AppKit boundary for choosing either a directory draft or the
/// distributable `.chengyinpack` archive. Validation and extraction remain in
/// the content library; the panel never interprets the selected path.
@MainActor
enum CompanionContentPackImportPanel {
    static func choose() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if let archiveType = UTType(filenameExtension: "chengyinpack") {
            panel.allowedContentTypes = [archiveType]
        }
        panel.prompt = CompanionLocalization.string(
            key: "pack.import.prompt",
            fallback: "验证并导入"
        )
        panel.message = CompanionLocalization.string(
            key: "pack.import.message",
            fallback: "请选择 .chengyinpack 文件，或包含 manifest.json 的本地内容包目录。"
        )
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
