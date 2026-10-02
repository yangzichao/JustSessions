import Foundation

/// What the `session_meta` line opening a Codex rollout file says: the session and the folder it ran in.
struct CodexRolloutHead: Sendable {
    let sessionID: String
    let projectPath: String

    /// Nil when the file does not open with a valid `session_meta` line, such as one Codex has not finished writing.
    init?(file: URL) {
        guard let root = ConversationMetadata.firstLine(of: file),
              root["type"] as? String == "session_meta",
              let payload = root["payload"] as? [String: Any],
              let sessionID = payload["id"] as? String,
              ConversationMetadata.isValidSessionID(sessionID),
              let projectPath = payload["cwd"] as? String else { return nil }
        self.sessionID = sessionID
        self.projectPath = projectPath
    }
}
