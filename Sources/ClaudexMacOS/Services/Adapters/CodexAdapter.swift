import Foundation

struct CodexAdapter: ConversationAdapter {
    let codexDirectory: URL
    let deletionExecutableURL: URL?
    var provider: ConversationProvider { .codex }

    init(codexDirectory: URL? = nil, deletionExecutableURL: URL? = nil) {
        let configured = ProcessInfo.processInfo.environment["CODEX_HOME"]
        self.codexDirectory = codexDirectory
            ?? URL(fileURLWithPath: configured ?? NSHomeDirectory() + "/.codex")
        self.deletionExecutableURL = deletionExecutableURL
    }

    func discover() throws -> [Conversation] {
        let titles = loadTitles()
        let sessionsDirectory = codexDirectory.appendingPathComponent("sessions")
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var conversations: [Conversation] = []
        for case let file as URL in enumerator where file.pathExtension == "jsonl" && file.lastPathComponent.hasPrefix("rollout-") {
            guard let root = ConversationMetadata.firstLine(of: file),
                  root["type"] as? String == "session_meta",
                  let payload = root["payload"] as? [String: Any],
                  let sessionID = payload["id"] as? String,
                  ConversationMetadata.isValidSessionID(sessionID),
                  let projectPath = payload["cwd"] as? String else { continue }
            let title = ConversationMetadata.cleanTitle(
                titles[sessionID]?.title ?? firstUserPrompt(in: file),
                fallback: "Untitled conversation"
            )
            let updatedAt = max(titles[sessionID]?.updatedAt ?? .distantPast, ConversationMetadata.fileModificationDate(file))
            conversations.append(Conversation(
                provider: provider,
                sessionID: sessionID,
                projectPath: projectPath,
                suggestedTitle: title,
                updatedAt: updatedAt,
                sourceFile: file
            ))
        }
        return conversations
    }

    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] {
        switch action {
        case .resume: ["resume", conversation.sessionID]
        case .branch: ["fork", conversation.sessionID]
        }
    }

    func delete(_ conversation: Conversation) throws {
        try CodexConversationDeletion(
            codexDirectory: codexDirectory,
            executableURL: deletionExecutableURL
        ).delete(conversation)
    }

    private func loadTitles() -> [String: (title: String, updatedAt: Date?)] {
        let indexFile = codexDirectory.appendingPathComponent("session_index.jsonl")
        guard let text = try? String(contentsOf: indexFile, encoding: .utf8) else { return [:] }
        var titles: [String: (title: String, updatedAt: Date?)] = [:]
        for line in text.split(separator: "\n") {
            guard let entry = ConversationMetadata.object(from: Data(line.utf8)),
                  let sessionID = entry["id"] as? String,
                  let title = entry["thread_name"] as? String else { continue }
            titles[sessionID] = (title, ConversationMetadata.date(entry["updated_at"]))
        }
        return titles
    }

    private func firstUserPrompt(in file: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 262_144) else { return nil }
        for line in data.split(separator: 10, omittingEmptySubsequences: true).prefix(80) {
            guard let root = ConversationMetadata.object(from: Data(line)),
                  root["type"] as? String == "response_item",
                  let payload = root["payload"] as? [String: Any],
                  payload["type"] as? String == "message",
                  payload["role"] as? String == "user",
                  let content = payload["content"] as? [[String: Any]] else { continue }
            for part in content {
                guard part["type"] as? String == "input_text",
                      let text = part["text"] as? String else { continue }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed.hasPrefix("# AGENTS.md")
                    || trimmed.hasPrefix("<environment_context>")
                    || trimmed.hasPrefix("<user_instructions>") { continue }
                return trimmed
            }
        }
        return nil
    }
}
