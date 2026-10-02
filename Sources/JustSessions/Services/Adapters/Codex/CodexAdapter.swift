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

    /// Shared by every Codex adapter, this Mac's and each SSH host's mirror, which keep their files apart.
    private static let rolloutHeads = SessionFileSummaryCache<CodexRolloutHead>()
    private static let firstUserPrompts = SessionFileSummaryCache<String>()

    func discover() throws -> [Conversation] {
        let index = CodexSessionIndex(codexDirectory: codexDirectory)
        let sessionsDirectory = codexDirectory.appendingPathComponent("sessions")
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var rolloutFiles: [URL] = []
        var conversations: [Conversation] = []
        for case let file as URL in enumerator where file.pathExtension == "jsonl" && file.lastPathComponent.hasPrefix("rollout-") {
            rolloutFiles.append(file)
            guard let head = Self.rolloutHeads.summary(of: file, read: CodexRolloutHead.init(file:)) else { continue }
            let indexEntry = index.entry(forSessionID: head.sessionID)
            let title = ConversationMetadata.cleanTitle(
                indexEntry?.threadName ?? Self.firstUserPrompts.summary(of: file, read: CodexFirstUserPrompt.find(in:)),
                fallback: ConversationMetadata.untitledConversationTitle
            )
            let updatedAt = max(indexEntry?.updatedAt ?? .distantPast, ConversationMetadata.fileModificationDate(file))
            conversations.append(Conversation(
                provider: provider,
                sessionID: head.sessionID,
                projectPath: head.projectPath,
                suggestedTitle: title,
                updatedAt: updatedAt,
                sourceFile: file
            ))
        }
        Self.rolloutHeads.forgetFiles(in: sessionsDirectory, except: rolloutFiles)
        Self.firstUserPrompts.forgetFiles(in: sessionsDirectory, except: rolloutFiles)
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
