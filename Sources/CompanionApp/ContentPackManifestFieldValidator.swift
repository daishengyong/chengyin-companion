import Foundation

/// Rejects unknown JSON keys before Codable decoding. Keeping this raw-shape
/// pass separate prevents a decoder-model change from silently widening the
/// untrusted Content Pack input surface.
struct ContentPackManifestFieldValidator {
    static func validate(_ data: Data) throws {
        let raw = try JSONSerialization.jsonObject(with: data)
        guard let root = raw as? [String: Any] else {
            throw ContentPackValidationError.manifestInvalidJSON
        }
        try rejectUnknownKeys(
            root,
            allowed: [
                "schemaVersion", "id", "version", "minAppVersion", "tier",
                "character", "locales", "assets", "license", "experiences",
                "contribution"
            ],
            path: "manifest"
        )
        for (index, value) in (root["assets"] as? [Any] ?? []).enumerated() {
            guard let asset = value as? [String: Any] else { continue }
            let path = "assets[\(index)]"
            try rejectUnknownKeys(
                asset,
                allowed: [
                    "id", "kind", "path", "sha256", "durationMs", "width",
                    "height", "aspectRatio", "hasNativeAudio", "loop",
                    "cropAnchors", "focalTracks", "safeAreas", "triggers",
                    "tags", "cooldownSeconds", "weight"
                ],
                path: path
            )
            for (mode, anchorValue) in asset["cropAnchors"] as? [String: Any] ?? [:] {
                if let anchor = anchorValue as? [String: Any] {
                    try rejectUnknownKeys(
                        anchor,
                        allowed: ["x", "y", "scale"],
                        path: "\(path).cropAnchors.\(safeKey(mode))"
                    )
                }
            }
            for (mode, trackValue) in asset["focalTracks"] as? [String: Any] ?? [:] {
                for (keyframeIndex, keyframeValue) in (trackValue as? [Any] ?? []).enumerated() {
                    if let keyframe = keyframeValue as? [String: Any] {
                        try rejectUnknownKeys(
                            keyframe,
                            allowed: ["timeMs", "x", "y", "scale"],
                            path: "\(path).focalTracks.\(safeKey(mode))[\(keyframeIndex)]"
                        )
                    }
                }
            }
            for (mode, safeAreaValue) in asset["safeAreas"] as? [String: Any] ?? [:] {
                if let safeArea = safeAreaValue as? [String: Any] {
                    try rejectUnknownKeys(
                        safeArea,
                        allowed: ["x", "y", "width", "height"],
                        path: "\(path).safeAreas.\(safeKey(mode))"
                    )
                }
            }
        }
        for (index, value) in (root["experiences"] as? [Any] ?? []).enumerated() {
            guard let experience = value as? [String: Any] else { continue }
            let path = "experiences[\(index)]"
            try rejectUnknownKeys(
                experience,
                allowed: [
                    "id", "kind", "triggers", "steps", "locales",
                    "cooldownSeconds", "weight", "returnPolicy"
                ],
                path: path
            )
            for (stepIndex, stepValue) in (experience["steps"] as? [Any] ?? []).enumerated() {
                if let step = stepValue as? [String: Any] {
                    try rejectUnknownKeys(
                        step,
                        allowed: ["assetID", "role", "minimumPlaybackMs", "transition"],
                        path: "\(path).steps[\(stepIndex)]"
                    )
                }
            }
        }
        guard let contribution = root["contribution"] as? [String: Any] else {
            return
        }
        try rejectUnknownKeys(
            contribution,
            allowed: ["contractVersion", "package", "rights", "accessibility", "fallback"],
            path: "contribution"
        )
        if let package = contribution["package"] as? [String: Any] {
            try rejectUnknownKeys(
                package,
                allowed: [
                    "source", "author", "provider", "origin", "license",
                    "authorizationBasis", "allowedUses", "attribution",
                    "adultFictionStatus", "evidenceID", "review"
                ],
                path: "contribution.package"
            )
            try validateNestedEvidenceObjects(package, path: "contribution.package")
        }
        for (index, value) in (contribution["rights"] as? [Any] ?? []).enumerated() {
            guard let rights = value as? [String: Any] else { continue }
            let path = "contribution.rights[\(index)]"
            try rejectUnknownKeys(
                rights,
                allowed: [
                    "assetID", "origin", "holder", "license", "evidenceID",
                    "sourceSHA256", "commercialUseReviewed", "subjectStatus",
                    "source", "author", "provider", "authorizationBasis",
                    "allowedUses", "attribution", "review"
                ],
                path: path
            )
            try validateNestedEvidenceObjects(rights, path: path)
        }
        for (index, value) in (contribution["accessibility"] as? [Any] ?? []).enumerated() {
            guard let accessibility = value as? [String: Any] else { continue }
            let path = "contribution.accessibility[\(index)]"
            try rejectUnknownKeys(
                accessibility,
                allowed: [
                    "assetID", "descriptions", "transcripts", "altText",
                    "captions", "soundDescriptions", "flashingLights",
                    "suddenLoudAudio", "review"
                ],
                path: path
            )
            if let review = accessibility["review"] as? [String: Any] {
                try rejectUnknownKeys(
                    review,
                    allowed: ["status", "version", "reviewerID"],
                    path: "\(path).review"
                )
            }
        }
        if let fallback = contribution["fallback"] as? [String: Any] {
            try rejectUnknownKeys(
                fallback,
                allowed: ["strategy", "assets"],
                path: "contribution.fallback"
            )
            for (index, value) in (fallback["assets"] as? [Any] ?? []).enumerated() {
                if let asset = value as? [String: Any] {
                    try rejectUnknownKeys(
                        asset,
                        allowed: ["assetID", "strategy"],
                        path: "contribution.fallback.assets[\(index)]"
                    )
                }
            }
        }
    }

    private static func validateNestedEvidenceObjects(
        _ object: [String: Any],
        path: String
    ) throws {
        if let attribution = object["attribution"] as? [String: Any] {
            try rejectUnknownKeys(
                attribution,
                allowed: ["required", "text"],
                path: "\(path).attribution"
            )
        }
        if let review = object["review"] as? [String: Any] {
            try rejectUnknownKeys(
                review,
                allowed: ["status", "version", "reviewerID"],
                path: "\(path).review"
            )
        }
    }

    private static func rejectUnknownKeys(
        _ object: [String: Any],
        allowed: Set<String>,
        path: String
    ) throws {
        if let unknown = object.keys.first(where: { !allowed.contains($0) }) {
            throw ContentPackValidationError.unknownManifestField(
                "\(path).\(safeKey(unknown))"
            )
        }
    }

    private static func safeKey(_ key: String) -> String {
        key.range(
            of: #"^[A-Za-z0-9_.-]{1,64}$"#,
            options: .regularExpression
        ) != nil ? key : "<invalid-key>"
    }
}
