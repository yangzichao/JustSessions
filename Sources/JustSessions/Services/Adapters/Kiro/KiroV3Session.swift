import Foundation

/// Kiro CLI's V3 engine, chosen with `--agent-engine v3` and the default from Kiro CLI 3.0, keeps each session in a folder
/// of its own beside V2's `sessions/cli`: `sessions/<workspace hash>/sess_<uuid>/`, with `session.json`, its metadata,
/// and `messages.jsonl`, an event log Kiro rewrites whole as the session grows (its agent's `atomicWriteFile`, Kiro CLI
/// 2.16.2). The workspace hash is the first 16 hex digits of the SHA-256 of the session's folder. Kiro calls the layout
/// internal; this reads what 2.16.2 and 2.34.0 write, as the AWS and codeburn readers describe it. 2.34.0 adds a hidden
/// `.index` beside the sessions and an index of its own in `~/.kiro/session-index`, which `--delete-session` keeps up to
/// date, so sessions are deleted through Kiro rather than by removing their folder.
enum KiroV3Session {
    static let idPrefix = "sess_"
    static let metadataFileName = "session.json"
    static let messagesFileName = "messages.jsonl"
    /// `--resume-id` takes the `sess_` id, as `--list-sessions` prints it; under V2, which Kiro CLI runs unless told
    /// otherwise (2.34.0 too), it starts another conversation instead. 2.16.2 started a new one for the bare UUID, which
    /// 2.34.0 also takes.
    static let engineArguments = ["--agent-engine", "v3"]

    /// `sess_` followed by a UUID, as Kiro's `generateSessionId()` makes them.
    static func isSessionID(_ value: String) -> Bool {
        value.hasPrefix(idPrefix) && UUID(uuidString: String(value.dropFirst(idPrefix.count))) != nil
    }

    static func isMessagesFile(_ file: URL) -> Bool {
        file.lastPathComponent == messagesFileName && isSessionID(file.deletingLastPathComponent().lastPathComponent)
    }

    static func sessionsRoot(besideClassicDirectory classicDirectory: URL) -> URL {
        classicDirectory.deletingLastPathComponent()
    }
}

/// The fields of a V3 session's `session.json` that list it. Kiro's agent defines them as `id`, `title`,
/// `workspacePaths`, `createdAt`, `lastModifiedAt`, and the optional `parentSessionId` and `createdReason`, which is
/// `human`, `rewind`, `subagent`, or `tangent`.
struct KiroV3SessionMetadata: Equatable {
    static let maximumByteCount = 1_048_576

    let sessionID: String
    let title: String?
    let projectPath: String
    let updatedAt: Date?
    let createdReason: String?
    let parentSessionID: String?

    init?(object: [String: Any]) {
        guard let sessionID = object["id"] as? String,
            let projectPath = (object["workspacePaths"] as? [Any])?.first as? String
        else { return nil }
        self.sessionID = sessionID
        self.projectPath = projectPath
        title = (object["title"] as? String).flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        updatedAt = ConversationMetadata.date(object["lastModifiedAt"]) ?? ConversationMetadata.date(object["createdAt"])
        createdReason = object["createdReason"] as? String
        parentSessionID = (object["parentSessionId"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    init?(file: URL) {
        guard let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size <= Self.maximumByteCount,
            let data = try? Data(contentsOf: file), let object = ConversationMetadata.object(from: data)
        else { return nil }
        self.init(object: object)
    }

    /// A subagent's session belongs to the one that started it, as Kiro's own session list shows it; a tangent or a
    /// rewind is a conversation you forked, as a branch is, so it's listed.
    var isSubagentSession: Bool { createdReason == "subagent" }
}
