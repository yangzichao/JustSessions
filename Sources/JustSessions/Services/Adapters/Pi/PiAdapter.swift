import Foundation

struct PiAdapter: ConversationAdapter {
    let sessionsDirectory: URL
    let moveToTrash: (@Sendable (URL) throws -> Void)?
    var provider: ConversationProvider { .pi }

    init(sessionsDirectory: URL = PiSessionsDirectory.standard(), moveToTrash: (@Sendable (URL) throws -> Void)? = nil) {
        self.sessionsDirectory = sessionsDirectory
        self.moveToTrash = moveToTrash
    }

    private static let subagentSessions = SessionFileSummaryCache<PiSubagentSession>(
        persistenceFile: SessionSummaryCacheLocation.file(named: "pi-subagents", summaryLayoutVersion: 1))
    private static let sessionNames = SessionFileSummaryCache<PiSessionNameScan>(
        persistenceFile: SessionSummaryCacheLocation.file(named: "pi-session-names", summaryLayoutVersion: 1))

    func discover(cancellation: ConversationDiscoveryCancellation) throws -> [Conversation] {
        try cancellation.checkCancellation()
        var subagentFiles: [URL] = []
        let sessionFiles = PiSessionsDirectory.sessionFiles(in: sessionsDirectory)
        let conversations = sessionFiles.flatMap { file -> [Conversation] in
            guard !cancellation.isCancelled, let conversation = conversation(in: file) else { return [] }
            let subagents = PiSubagentSessions.find(startedBy: file, sessionID: conversation.sessionID) { subagentFile in
                Self.subagentSessions.summary(of: subagentFile, read: PiSubagentSession.init(file:))
            }
            subagentFiles += subagents.map(\.file)
            return [conversation] + subagents.map(subagentConversation(_:))
        }
        try cancellation.checkCancellation()
        Self.subagentSessions.forgetFiles(in: sessionsDirectory, except: subagentFiles)
        Self.sessionNames.forgetFiles(in: sessionsDirectory, except: sessionFiles)
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
            let projectPath = header["cwd"] as? String, projectPath.hasPrefix("/")
        else { return nil }
        let title = ConversationMetadata.cleanTitle(
            Self.sessionNames.summary(ofGrowingFile: file) { PiSessionNameScan.scan($0, continuing: $1) }?.latestName
                ?? PiSessionTitle.firstUserPrompt(in: file),
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
