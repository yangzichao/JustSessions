import Foundation

/// What the `session_meta` line opening a Codex rollout file says: the session and the folder it ran in, and, for a
/// subagent's thread, the thread that spawned it.
struct CodexRolloutHead: Sendable, Codable {
    /// A thread another thread spawned as a subagent, from `source.subagent.thread_spawn`.
    struct Spawn: Sendable, Codable, Equatable {
        let parentThreadID: String
        /// The name Codex gave the agent, such as `Volta`.
        let agentNickname: String?
        /// Where the agent sits among its parent's agents, such as `/root/decode_plan`.
        let agentPath: String?
    }

    let sessionID: String
    let projectPath: String
    let spawn: Spawn?

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
        let threadSpawn = ((payload["source"] as? [String: Any])?["subagent"] as? [String: Any])?["thread_spawn"] as? [String: Any]
        spawn = (threadSpawn?["parent_thread_id"] as? String).flatMap { parentThreadID in
            guard ConversationMetadata.isValidSessionID(parentThreadID) else { return nil }
            return Spawn(
                parentThreadID: parentThreadID,
                agentNickname: threadSpawn?["agent_nickname"] as? String,
                agentPath: threadSpawn?["agent_path"] as? String
            )
        }
    }

    /// A spawned thread opens with its parent's history, so its first prompt is the parent's. Its nickname and the
    /// last part of its path, such as `Volta · decode_plan`, tell it apart instead.
    var spawnedAgentTitle: String? {
        guard let spawn else { return nil }
        let task = spawn.agentPath.flatMap { $0.split(separator: "/").last.map(String.init) }
        let parts = [spawn.agentNickname, task].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
