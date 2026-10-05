import Foundation

struct AntigravityAdapter: ConversationAdapter {
    let configurationDirectory: URL
    var provider: ConversationProvider { .antigravity }

    static var defaultConfigurationDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory() + "/.gemini/antigravity-cli")
    }

    init(configurationDirectory: URL = AntigravityAdapter.defaultConfigurationDirectory) {
        self.configurationDirectory = configurationDirectory
    }

    func discover() throws -> [Conversation] {
        let conversationsDirectory = configurationDirectory.appendingPathComponent("conversations")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: conversationsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let summaries = AntigravitySQLiteReader.summaries(
            at: configurationDirectory.appendingPathComponent("conversation_summaries.db")
        )
        return files.compactMap { file -> Conversation? in
            guard file.pathExtension == "db",
                  ConversationMetadata.isValidSessionID(file.deletingPathExtension().lastPathComponent),
                  let localSession = AntigravitySQLiteReader.localSession(at: file),
                  localSession.sessionID == file.deletingPathExtension().lastPathComponent else { return nil }

            let summary = summaries[localSession.sessionID]
            let fallbackTitle = "Antigravity session \(localSession.sessionID.prefix(8))"
            let title = ConversationMetadata.cleanTitle(
                summary?.title.flatMap { $0.isEmpty ? nil : $0 }
                    ?? summary?.preview.flatMap { $0.isEmpty ? nil : $0 }
                    ?? localSession.firstPrompt,
                fallback: fallbackTitle
            )
            let updatedAt = max(
                summary?.updatedAt ?? .distantPast,
                ConversationMetadata.fileModificationDate(file),
                ConversationMetadata.fileModificationDate(URL(fileURLWithPath: file.path + "-wal"))
            )
            return Conversation(
                provider: provider,
                sessionID: localSession.sessionID,
                projectPath: summary?.projectPath ?? localSession.projectPath,
                suggestedTitle: title,
                updatedAt: updatedAt,
                sourceFile: file,
                parentSessionID: summary?.parentConversationID.flatMap { $0 == localSession.sessionID ? nil : $0 }
            )
        }
    }

    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] {
        switch action {
        case .new: []
        case .resume, .branch: ["--conversation", conversation.sessionID]
        }
    }

    func delete(_ conversation: Conversation) throws {
        try AntigravityConversationDeletion(configurationDirectory: configurationDirectory).delete(conversation)
    }
}
