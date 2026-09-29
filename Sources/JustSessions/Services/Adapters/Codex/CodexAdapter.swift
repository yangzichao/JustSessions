import Foundation

struct CodexAdapter: ConversationAdapter {
    let codexDirectory: URL
    let deletionExecutableURL: URL?
    var provider: ConversationProvider { .codex }

    static var defaultCodexDirectory: URL {
        let configured = ProcessInfo.processInfo.environment["CODEX_HOME"]
        return URL(fileURLWithPath: configured ?? NSHomeDirectory() + "/.codex")
    }

    init(codexDirectory: URL = CodexAdapter.defaultCodexDirectory, deletionExecutableURL: URL? = nil) {
        self.codexDirectory = codexDirectory
        self.deletionExecutableURL = deletionExecutableURL
    }

    func discover() throws -> [Conversation] {
        let index = CodexSessionIndex(codexDirectory: codexDirectory)
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
            let indexEntry = index.entry(forSessionID: sessionID)
            let title = ConversationMetadata.cleanTitle(
                indexEntry?.threadName ?? CodexFirstUserPrompt.find(in: file),
                fallback: ConversationMetadata.untitledConversationTitle
            )
            let updatedAt = max(indexEntry?.updatedAt ?? .distantPast, ConversationMetadata.fileModificationDate(file))
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
        case .new: []
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
}
