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

    /// Shared by every Pi adapter, this Mac's and each SSH host's mirror, which keep their files apart. Subagents' files
    /// can be large and are rarely written to once their run ends.
    private static let subagentSessions = SessionFileSummaryCache<PiSubagentSession>(persistenceFile: SessionSummaryCacheLocation.file(named: "pi-subagents"))

    /// Each session, then the sessions its subagents ran in.
    func discover() throws -> [Conversation] {
        var subagentFiles: [URL] = []
        let conversations = PiSessionsDirectory.sessionFiles(in: sessionsDirectory).flatMap { file -> [Conversation] in
            guard let conversation = conversation(in: file) else { return [] }
            let subagents = PiSubagentSessions.find(startedBy: file, sessionID: conversation.sessionID) { subagentFile in
                Self.subagentSessions.summary(of: subagentFile, read: PiSubagentSession.init(file:))
            }
            subagentFiles += subagents.map(\.file)
            return [conversation] + subagents.map(subagentConversation(_:))
        }
        Self.subagentSessions.forgetFiles(in: sessionsDirectory, except: subagentFiles)
        return conversations
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

    private func subagentConversation(_ found: PiSubagentSessions.Found) -> Conversation {
        Conversation(
            provider: provider,
            sessionID: found.session.sessionID,
            projectPath: found.session.projectPath,
            suggestedTitle: found.session.title,
            updatedAt: ConversationMetadata.fileModificationDate(found.file),
            sourceFile: found.file,
            parentSessionID: found.parentSessionID
        )
    }
}
