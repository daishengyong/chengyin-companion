import Foundation

public enum CodexNotifyConfigPlanStatus: String, Codable, Equatable, Sendable {
    case appendAtTop
    case alreadyConfigured
    case conflict
}

public struct CodexNotifyConfigPlan: Codable, Equatable, Sendable {
    public var status: CodexNotifyConfigPlanStatus
    public var proposedLine: String

    public init(status: CodexNotifyConfigPlanStatus, proposedLine: String) {
        self.status = status
        self.proposedLine = proposedLine
    }
}

public enum CodexNotifyConfigPlannerError: Error, Equatable, Sendable {
    case invalidHelperPath
    case configNotUTF8
}

extension CodexNotifyConfigPlannerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidHelperPath:
            "The notify helper path must be an absolute path without control characters."
        case .configNotUTF8:
            "The Codex config is not valid UTF-8."
        }
    }
}

public enum CodexNotifyConfigPlanner {
    /// Produces a non-mutating plan. It never returns or logs the user's config
    /// body, which may contain unrelated private settings.
    public static func plan(
        existingConfig: Data?,
        helperPath: String
    ) throws -> CodexNotifyConfigPlan {
        guard helperPath.hasPrefix("/"),
              !helperPath.contains("\n"),
              !helperPath.contains("\r"),
              !helperPath.contains("\0") else {
            throw CodexNotifyConfigPlannerError.invalidHelperPath
        }

        let escapedPath = helperPath
            .replacingOccurrences(of: #"\"#, with: #"\\"#)
            .replacingOccurrences(of: "\"", with: #"\""#)
        let proposed = #"notify = ["\#(escapedPath)", "codex-notify"]"#

        guard let existingConfig else {
            return CodexNotifyConfigPlan(
                status: .appendAtTop,
                proposedLine: proposed
            )
        }
        guard let text = String(data: existingConfig, encoding: .utf8) else {
            throw CodexNotifyConfigPlannerError.configNotUTF8
        }

        let activeNotifyLines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                !line.isEmpty
                    && !line.hasPrefix("#")
                    && line.range(
                        of: #"^notify\s*="#,
                        options: .regularExpression
                    ) != nil
            }

        if activeNotifyLines.isEmpty {
            return CodexNotifyConfigPlan(
                status: .appendAtTop,
                proposedLine: proposed
            )
        }
        if activeNotifyLines.count == 1,
           normalized(activeNotifyLines[0]) == normalized(proposed) {
            return CodexNotifyConfigPlan(
                status: .alreadyConfigured,
                proposedLine: proposed
            )
        }
        return CodexNotifyConfigPlan(
            status: .conflict,
            proposedLine: proposed
        )
    }

    private static func normalized(_ line: String) -> String {
        line.replacingOccurrences(
            of: #"\s+"#,
            with: "",
            options: .regularExpression
        )
    }
}
