import Foundation

@main
private enum ContentPackPreviewCLI {
    static func main() async {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            guard let path = arguments.first, path != "--help" else {
                printUsage()
                exit(arguments.first == "--help" ? 0 : 2)
            }

            var appVersion = "0.19.98"
            var outputPath: String?
            var index = 1
            while index < arguments.count {
                switch arguments[index] {
                case "--app-version":
                    guard index + 1 < arguments.count else {
                        throw PreviewError(
                            code: "CREATOR_PREVIEW_APP_VERSION_MISSING",
                            message: "--app-version requires a semantic version"
                        )
                    }
                    appVersion = arguments[index + 1]
                    index += 2
                case "--output":
                    guard index + 1 < arguments.count else {
                        throw PreviewError(
                            code: "CREATOR_PREVIEW_OUTPUT_MISSING",
                            message: "--output requires an HTML path"
                        )
                    }
                    outputPath = arguments[index + 1]
                    index += 2
                default:
                    throw PreviewError(
                        code: "CREATOR_PREVIEW_UNKNOWN_OPTION",
                        message: "Unknown option: \(arguments[index])"
                    )
                }
            }

            guard let outputPath else {
                throw PreviewError(
                    code: "CREATOR_PREVIEW_OUTPUT_MISSING",
                    message: "--output is required"
                )
            }
            let packageDirectory = URL(fileURLWithPath: path, isDirectory: true)
                .standardizedFileURL
            let outputURL = URL(fileURLWithPath: outputPath, isDirectory: false)
                .standardizedFileURL
            guard !isInside(outputURL, directory: packageDirectory) else {
                throw PreviewError(
                    code: "CREATOR_PREVIEW_OUTPUT_INSIDE_PACK",
                    message: "Preview output must stay outside the pack so validation remains reproducible"
                )
            }

            let manifest = try ContentPackValidator().loadAndValidate(
                packageDirectory: packageDirectory,
                currentAppVersion: appVersion
            )
            try await creatorContentPackMediaProbe().probe(
                packageDirectory: packageDirectory,
                manifest: manifest
            )

            let html = try render(
                manifest: manifest,
                packageDirectory: packageDirectory
            )
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(html.utf8).write(to: outputURL, options: .atomic)
            print("PASS  \(manifest.id)@\(manifest.version)")
            print("PREVIEW  \(outputURL.path)")
        } catch {
            let receipt = CompanionFailureReceipt(
                error: error,
                fallbackCode: "CREATOR_PREVIEW_UNEXPECTED_ERROR"
            )
            fputs(receipt.safeLog + "\n", stderr)
            exit(1)
        }
    }

    private static func render(
        manifest: ContentPackManifest,
        packageDirectory: URL
    ) throws -> String {
        let rightsByAsset = Dictionary(
            uniqueKeysWithValues: (manifest.contribution?.rights ?? []).map {
                ($0.assetID, $0)
            }
        )
        let accessibilityByAsset = Dictionary(
            uniqueKeysWithValues: (manifest.contribution?.accessibility ?? []).map {
                ($0.assetID, $0)
            }
        )
        let cards = try manifest.assets.map { asset -> String in
            let assetURL = packageDirectory.appendingPathComponent(asset.path)
            let accessibility = accessibilityByAsset[asset.id]
            let preferredDescription = manifest.locales.lazy.compactMap {
                accessibility?.descriptions[$0]
            }.first ?? asset.id
            let media: String
            switch asset.kind {
            case .video:
                media = ContentPackProjectionPreview.renderVideo(
                    asset: asset,
                    assetURL: assetURL,
                    accessibilityLabel: preferredDescription
                )
            case .audio:
                media = "<audio controls src=\"\(escape(assetURL.absoluteString))\"></audio>"
            case .image:
                let alt = manifest.locales.lazy.compactMap {
                    accessibility?.altText?[$0]
                }.first ?? asset.id
                media = "<img loading=\"lazy\" src=\"\(escape(assetURL.absoluteString))\" alt=\"\(escape(alt))\">"
            case .localization:
                let data = try Data(contentsOf: assetURL)
                let text = String(decoding: data.prefix(65_536), as: UTF8.self)
                media = "<pre>\(escape(text))</pre>"
            case .game:
                media = "<div class=\"placeholder\">Declarative game asset</div>"
            }
            let triggers = asset.triggers.isEmpty
                ? "No triggers"
                : asset.triggers.joined(separator: " · ")
            let tags = asset.tags.isEmpty
                ? "No tags"
                : asset.tags.joined(separator: " · ")
            let rightsHTML: String
            if let rights = rightsByAsset[asset.id] {
                rightsHTML = """
                <dt>Rights</dt><dd>\(escape(rights.origin.rawValue)) · \(escape(rights.license)) · \(rights.commercialUseReviewed ? "reviewed" : "review pending")</dd>
                <dt>Holder</dt><dd>\(escape(rights.holder))</dd>
                <dt>Source</dt><dd>\(escape(rights.source ?? "compatibility record — source not declared"))</dd>
                <dt>Author</dt><dd>\(escape(rights.author ?? "not declared"))</dd>
                <dt>Provider</dt><dd>\(escape(rights.provider ?? "not declared"))</dd>
                <dt>Uses</dt><dd>\(escape((rights.allowedUses ?? []).map(\.rawValue).joined(separator: " · ")))</dd>
                <dt>Attribution</dt><dd>\(escape(rights.attribution?.required == true ? (rights.attribution?.text ?? "required") : "not required"))</dd>
                <dt>Subject</dt><dd>\(escape(rights.subjectStatus.rawValue))</dd>
                <dt>Evidence</dt><dd>\(escape(rights.evidenceID))</dd>
                <dt>Review</dt><dd>\(escape(rights.review?.status.rawValue ?? "compatibility record")) · v\(rights.review?.version ?? 0)</dd>
                """
            } else {
                rightsHTML = "<dt>Rights</dt><dd class=\"warning\">Missing — contribution audit will block readiness</dd>"
            }
            let accessibilityHTML: String
            if let accessibility {
                let transcriptLocales = (accessibility.transcripts ?? [:])
                    .keys.sorted().joined(separator: " · ")
                let altLocales = (accessibility.altText ?? [:])
                    .keys.sorted().joined(separator: " · ")
                let captionLocales = (accessibility.captions ?? [:])
                    .keys.sorted().joined(separator: " · ")
                let soundDescriptionLocales = (accessibility.soundDescriptions ?? [:])
                    .keys.sorted().joined(separator: " · ")
                accessibilityHTML = """
                <dt>Access</dt><dd>\(escape(preferredDescription))</dd>
                <dt>Transcript</dt><dd>\(escape(transcriptLocales.isEmpty ? "None" : transcriptLocales))</dd>
                <dt>Alt text</dt><dd>\(escape(altLocales.isEmpty ? "None" : altLocales))</dd>
                <dt>Captions</dt><dd>\(escape(captionLocales.isEmpty ? "None" : captionLocales))</dd>
                <dt>Sound desc.</dt><dd>\(escape(soundDescriptionLocales.isEmpty ? "None" : soundDescriptionLocales))</dd>
                <dt>Warnings</dt><dd>flashing \(accessibility.flashingLights ? "yes" : "no") · sudden loud audio \(accessibility.suddenLoudAudio ? "yes" : "no")</dd>
                <dt>Access review</dt><dd>\(escape(accessibility.review?.status.rawValue ?? "compatibility record")) · v\(accessibility.review?.version ?? 0)</dd>
                """
            } else {
                accessibilityHTML = "<dt>Access</dt><dd class=\"warning\">Missing — contribution audit will block readiness</dd>"
            }
            return """
            <article class="card">
              <div class="media">\(media)</div>
              <div class="body">
                <div class="kind">\(escape(asset.kind.rawValue))</div>
                <h2>\(escape(asset.id))</h2>
                <p>\(escape(asset.path))</p>
                <dl>
                  <dt>Triggers</dt><dd>\(escape(triggers))</dd>
                  <dt>Tags</dt><dd>\(escape(tags))</dd>
                  \(rightsHTML)
                  \(accessibilityHTML)
                </dl>
              </div>
            </article>
            """
        }.joined(separator: "\n")

        let emptyState = manifest.assets.isEmpty
            ? "<section class=\"empty\">This draft has no assets yet. Add declared files, update SHA-256 values, then preview again.</section>"
            : ""
        let contributionState: String
        if manifest.contributionMode != .strictV2 {
            contributionState = "<section class=\"empty warning-panel\">\(escape(manifest.contributionMode.rawValue)): rights approval is not inferred. Generate a v1-to-v2 migration receipt and complete the strict contribution contract before opening a pull request.</section>"
        } else if !manifest.contributionReadiness.isReady {
            contributionState = "<section class=\"empty warning-panel\">Strict v2 evidence exists but review or coverage is incomplete. Run the strict audit for actionable gaps.</section>"
        } else {
            contributionState = ""
        }
        let experienceCards = (manifest.experiences ?? []).map { experience in
            let steps = experience.steps.enumerated().map { index, step in
                "<li><strong>\(index + 1). \(escape(step.role.rawValue))</strong> · \(escape(step.assetID)) · \(escape(step.transition?.rawValue ?? "cut"))</li>"
            }.joined()
            return """
            <article class="card experience">
              <div class="body">
                <div class="kind">\(escape(experience.kind.rawValue))</div>
                <h2>\(escape(experience.id))</h2>
                <p>\(escape(experience.triggers.joined(separator: " · ")))</p>
                <ol>\(steps)</ol>
                <p>Return: \(escape(experience.returnPolicy.rawValue))</p>
              </div>
            </article>
            """
        }.joined(separator: "\n")
        let experiencesSection = (manifest.experiences ?? []).isEmpty
            ? ""
            : "<h2 class=\"section-title\">Experience sequences</h2><section class=\"grid\">\(experienceCards)</section>"
        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escape(manifest.id)) · Chengyin Pack Preview</title>
          <style>
            :root { color-scheme: dark; font-family: ui-rounded, -apple-system, BlinkMacSystemFont, sans-serif; }
            * { box-sizing: border-box; }
            body { margin: 0; background: #0c0c12; color: #f7f5ff; }
            header { padding: 52px clamp(24px, 6vw, 80px) 30px; background: radial-gradient(circle at 15% 0%, #5f315e 0, #19131f 38%, #0c0c12 72%); }
            .eyebrow, .kind { color: #ff9bd5; font-size: 12px; font-weight: 750; letter-spacing: .14em; text-transform: uppercase; }
            h1 { margin: 10px 0 8px; font-size: clamp(30px, 5vw, 58px); letter-spacing: -.04em; }
            header p { color: #c9c3d3; max-width: 760px; line-height: 1.6; }
            .facts { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 22px; }
            .facts span { padding: 8px 12px; border: 1px solid #ffffff20; border-radius: 999px; background: #ffffff0a; }
            main { padding: 28px clamp(18px, 5vw, 72px) 72px; }
            .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
            .card, .empty { overflow: hidden; border: 1px solid #ffffff1c; border-radius: 22px; background: #17161f; box-shadow: 0 22px 80px #0006; }
            .media { min-height: 190px; display: grid; place-items: center; background: #07070a; }
            video, img { display: block; width: 100%; aspect-ratio: 16 / 9; object-fit: contain; background: #000; }
            .projection-review { width: 100%; padding: 14px; }
            .projection-review-note { margin: 0 0 10px; color: #858092; font-size: 12px; }
            .projection-grid { display: grid; grid-template-columns: minmax(110px, .72fr) repeat(2, minmax(180px, 1fr)); gap: 12px; align-items: end; }
            .projection-panel { min-width: 0; margin: 0; }
            .projection-viewport { position: relative; overflow: hidden; width: 100%; border: 1px solid #ffffff24; border-radius: 14px; background: #000; }
            .projection-viewport.pet { aspect-ratio: 1; }
            .projection-viewport.landscape { aspect-ratio: 16 / 9; }
            .projection-viewport video { position: absolute; max-width: none; max-height: none; aspect-ratio: auto; background: transparent; }
            .projection-safe-area { position: absolute; z-index: 2; pointer-events: none; border: 2px dashed #65f6c1; border-radius: 8px; box-shadow: 0 0 0 9999px #00000018; }
            .projection-panel figcaption { display: grid; gap: 2px; padding: 8px 3px 0; color: #d9d3e2; font-size: 12px; }
            .projection-panel figcaption span, .projection-panel figcaption small { color: #858092; overflow-wrap: anywhere; }
            .projection-storyboard { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px; margin-top: 8px; }
            .projection-story-frame { min-width: 0; margin: 0; }
            .projection-story-viewport { position: relative; overflow: hidden; width: 100%; border: 1px solid #ffffff18; border-radius: 8px; background: #000; }
            .projection-story-viewport.pet { aspect-ratio: 1; }
            .projection-story-viewport.landscape { aspect-ratio: 16 / 9; }
            .projection-story-viewport video { position: absolute; max-width: none; max-height: none; aspect-ratio: auto; background: transparent; }
            .projection-story-frame figcaption { padding-top: 4px; color: #858092; font-size: 10px; text-align: center; }
            @media (max-width: 780px) { .projection-grid { grid-template-columns: 1fr; } .projection-viewport.pet { max-width: 220px; } }
            audio { width: calc(100% - 32px); }
            pre { width: 100%; max-height: 280px; overflow: auto; margin: 0; padding: 22px; color: #d8ffd8; white-space: pre-wrap; }
            .placeholder { color: #a9a3b5; padding: 44px 20px; }
            .body { padding: 20px; }
            h2 { overflow-wrap: anywhere; margin: 8px 0; font-size: 20px; }
            .section-title { margin: 42px 0 18px; font-size: 28px; }
            .body p, dd { color: #b8b1c2; overflow-wrap: anywhere; }
            .warning { color: #ffd38a; }
            .warning-panel { border-color: #f3b35a66; color: #ffd38a; }
            ol { padding-left: 22px; color: #d9d3e2; line-height: 1.7; }
            dl { display: grid; grid-template-columns: 72px 1fr; gap: 8px 12px; margin-bottom: 0; }
            dt { color: #858092; }
            dd { margin: 0; }
            .empty { padding: 36px; color: #c9c3d3; }
          </style>
        </head>
        <body>
          <header>
            <div class="eyebrow">Chengyin content pack · validated local preview</div>
            <h1>\(escape(manifest.id))</h1>
            <p>Character <strong>\(escape(manifest.character))</strong> · license <strong>\(escape(manifest.license))</strong>. This page is generated locally and loads no remote script, font or analytics.</p>
            <div class="facts">
              <span>v\(escape(manifest.version))</span>
              <span>schema \(manifest.schemaVersion)</span>
              <span>\(escape(manifest.contributionMode.rawValue))</span>
              <span>\(manifest.assets.count) assets</span>
              <span>\(manifest.experiences?.count ?? 0) experiences</span>
              <span>\(escape(manifest.locales.joined(separator: " · ")))</span>
            </div>
          </header>
          <main>
            \(emptyState)
            \(contributionState)
            <section class="grid">\(cards)</section>
            \(experiencesSection)
          </main>
        </body>
        </html>
        """
    }

    private static func isInside(_ file: URL, directory: URL) -> Bool {
        let root = directory.resolvingSymlinksInPath().path
        let candidate = file.resolvingSymlinksInPath().path
        return candidate == root || candidate.hasPrefix(root + "/")
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func printUsage() {
        print(
            """
            Usage: content-pack-preview-cli <pack-directory> --output <preview.html> [options]

              --app-version <x.y.z>  Validate the minimum app version (default 0.19.98)
              --output <path>         Write a self-contained local HTML catalog
              --help                  Show this message
            """
        )
    }
}

private struct PreviewError: LocalizedError, CompanionErrorCoding {
    let code: String
    let message: String

    init(code: String, message: String) {
        self.code = code
        self.message = message
    }

    var companionErrorCode: String { code }
    var errorDescription: String? { message }
}
