import Foundation

struct CodexAdapter: ConversationAdapter {
    let codexDirectory: URL
    let deletionExecutableURL: URL?
    var provider: ConversationProvider { .codex }

    static var defaultCodexDirectory: URL {
        standardCodexDirectory()
    }

    static func standardCodexDirectory(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory()
    ) -> URL {
        URL(fileURLWithPath: environment["CODEX_HOME"] ?? homeDirectory + "/.codex")
    }

    init(codexDirectory: URL = CodexAdapter.defaultCodexDirectory, deletionExecutableURL: URL? = nil) {
        self.codexDirectory = codexDirectory
        self.deletionExecutableURL = deletionExecutableURL
    }

    private static let rolloutHeads = SessionFileSummaryCache<CodexRolloutHead>(
        persistenceFile: SessionSummaryCacheLocation.file(named: "codex-heads", summaryLayoutVersion: 2))
    private static let firstUserPrompts = SessionFileSummaryCache<String>(
        persistenceFile: SessionSummaryCacheLocation.file(named: "codex-prompts", summaryLayoutVersion: 1))
    private static let models = SessionFileSummaryCache<SessionModel>(
        persistenceFile: SessionSummaryCacheLocation.file(named: "codex-models", summaryLayoutVersion: 1))

    func discover(cancellation: ConversationDiscoveryCancellation) throws -> [Conversation] {
        try cancellation.checkCancellation()
        let index = CodexSessionIndex(codexDirectory: codexDirectory)
        let sessionsDirectory = codexDirectory.appendingPathComponent("sessions")
        guard
            let enumerator = FileManager.default.enumerator(
                at: sessionsDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else { return [] }

        var rolloutFiles: [URL] = []
        var conversations: [Conversation] = []
        for case let file as URL in enumerator where file.pathExtension == "jsonl" && file.lastPathComponent.hasPrefix("rollout-") {
            try cancellation.checkCancellation()
            guard file.isPlainFileNotLinkOrPipe else { continue }
            rolloutFiles.append(file)
            guard let head = Self.rolloutHeads.summary(of: file, read: CodexRolloutHead.init(file:)) else { continue }
            let indexEntry = index.entry(forSessionID: head.sessionID)
            let title = ConversationMetadata.cleanTitle(
                indexEntry?.threadName
                    ?? head.spawnedAgentTitle
                    ?? Self.firstUserPrompts.summary(of: file, read: CodexFirstUserPrompt.find(in:)),
                fallback: ConversationMetadata.untitledConversationTitle
            )
            let updatedAt = max(indexEntry?.updatedAt ?? .distantPast, ConversationMetadata.fileModificationDate(file))
            conversations.append(
                Conversation(
                    provider: provider,
                    sessionID: head.sessionID,
                    projectPath: head.projectPath,
                    suggestedTitle: title,
                    updatedAt: updatedAt,
                    sourceFile: file,
                    parentSessionID: head.spawn?.parentThreadID,
                    model: Self.models.summary(of: file, read: CodexRolloutModel.latest(in:))
                ))
        }
        try cancellation.checkCancellation()
        Self.rolloutHeads.forgetFiles(in: sessionsDirectory, except: rolloutFiles)
        Self.firstUserPrompts.forgetFiles(in: sessionsDirectory, except: rolloutFiles)
        Self.models.forgetFiles(in: sessionsDirectory, except: rolloutFiles)
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
