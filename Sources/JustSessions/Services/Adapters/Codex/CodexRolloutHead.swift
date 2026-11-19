import Foundation

struct CodexRolloutHead: Sendable, Codable {
    struct Spawn: Sendable, Codable, Equatable {
        let parentThreadID: String
        let agentNickname: String?
        let agentPath: String?
    }

    let sessionID: String
    let projectPath: String
    let spawn: Spawn?

    init?(file: URL) {
        guard let root = ConversationMetadata.firstLine(of: file, requiresRegularFile: true),
            root["type"] as? String == "session_meta",
            let payload = root["payload"] as? [String: Any],
            let sessionID = payload["id"] as? String,
            ConversationMetadata.isValidSessionID(sessionID),
            let projectPath = payload["cwd"] as? String
        else { return nil }
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
