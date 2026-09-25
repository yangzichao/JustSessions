import Foundation

/// Recognizes a session file among the files a CLI holds open and reads the session id from its name.
/// Codex keeps `sessions/YYYY/MM/DD/rollout-<timestamp>-<session id>.jsonl` open while it runs, and
/// Antigravity its SQLite `conversations/<session id>.db` with `-wal` and `-shm` companions.
/// Claude Code does not keep its transcript open; its tabs are matched by session id instead.
enum OpenSessionFileName {
    static func sessionID(inOpenFilePath path: String, provider: ConversationProvider) -> String? {
        let file = URL(fileURLWithPath: path)
        let sessionID: String
        switch provider {
        case .claude:
            return nil
        case .codex:
            guard file.lastPathComponent.hasPrefix("rollout-"), file.pathExtension == "jsonl" else { return nil }
            sessionID = String(file.deletingPathExtension().lastPathComponent.suffix(36))
        case .antigravity:
            guard file.deletingLastPathComponent().lastPathComponent == "conversations" else { return nil }
            let databaseFileName = ["-wal", "-shm", "-journal"].reduce(file.lastPathComponent) { fileName, suffix in
                fileName.hasSuffix(suffix) ? String(fileName.dropLast(suffix.count)) : fileName
            }
            guard databaseFileName.hasSuffix(".db") else { return nil }
            sessionID = String(databaseFileName.dropLast(".db".count))
        }
        return ConversationMetadata.isValidSessionID(sessionID) ? sessionID : nil
    }
}
