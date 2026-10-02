import Foundation

/// Pi keeps each session in `<sessions>/--<encoded cwd>--/<timestamp>_<session id>.jsonl`, or directly in a custom
/// sessions folder. The first line names the session and its folder.
struct PiAdapter: ConversationAdapter {
    let sessionsDirectory: URL
    /// Nil moves deleted sessions to the macOS Trash; tests pass their own.
    let moveToTrash: (@Sendable (URL) throws -> Void)?
    var provider: ConversationProvider { .pi }

    init(sessionsDirectory: URL = PiSessionsDirectory.standard(), moveToTrash: (@Sendable (URL) throws -> Void)? = nil) {
        self.sessionsDirectory = sessionsDirectory
        self.moveToTrash = moveToTrash
    }

    func discover() throws -> [Conversation] {
        PiSessionsDirectory.sessionFiles(in: sessionsDirectory).compactMap(conversation(in:))
    }

    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] {
        switch action {
        case .new: []
        // Pi looks the id up in the folder it starts in first, which is the session's own.
        case .resume: ["--session", conversation.sessionID]
        case .branch: ["--fork", conversation.sessionID]
        }
    }

    func delete(_ conversation: Conversation) throws {
        try PiConversationDeletion(sessionsDirectory: sessionsDirectory, moveToTrash: moveToTrash).delete(conversation)
    }

    private func conversation(in file: URL) -> Conversation? {
        guard let header = ConversationMetadata.firstLine(of: file),
              header["type"] as? String == "session",
              let sessionID = header["id"] as? String,
              provider.isValidSessionID(sessionID),
              file.deletingPathExtension().lastPathComponent.hasSuffix("_\(sessionID)"),
              let projectPath = header["cwd"] as? String, projectPath.hasPrefix("/") else { return nil }
        let title = ConversationMetadata.cleanTitle(
            PiSessionTitle.latestName(in: file) ?? PiSessionTitle.firstUserPrompt(in: file),
            fallback: ConversationMetadata.untitledConversationTitle
        )
        return Conversation(
            provider: provider,
            sessionID: sessionID,
            projectPath: projectPath,
            suggestedTitle: title,
            updatedAt: ConversationMetadata.fileModificationDate(file),
            sourceFile: file
        )
    }
}
