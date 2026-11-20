import Foundation

struct ClaudeAdapter: ConversationAdapter {
    let configurationDirectory: URL
    var provider: ConversationProvider { .claude }

    static var defaultConfigurationDirectory: URL {
        standardConfigurationDirectory()
    }

    static func standardConfigurationDirectory(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory()
    ) -> URL {
        URL(fileURLWithPath: environment["CLAUDE_CONFIG_DIR"] ?? homeDirectory + "/.claude")
    }

    init(configurationDirectory: URL = ClaudeAdapter.defaultConfigurationDirectory) {
        self.configurationDirectory = configurationDirectory
    }

    private static let transcriptHeads = SessionFileSummaryCache<ClaudeTranscriptHead>(
        persistenceFile: SessionSummaryCacheLocation.file(named: "claude-heads", summaryLayoutVersion: 2))
    private static let transcriptTails = SessionFileSummaryCache<ClaudeTranscriptTail>(
        persistenceFile: SessionSummaryCacheLocation.file(named: "claude-tails", summaryLayoutVersion: 5))
    private static let subagentSessions = SessionFileSummaryCache<ClaudeSubagentSession>(
        persistenceFile: SessionSummaryCacheLocation.file(named: "claude-subagents", summaryLayoutVersion: 2))

    func discover(cancellation: ConversationDiscoveryCancellation) throws -> [Conversation] {
        try cancellation.checkCancellation()
        let projectsDirectory = configurationDirectory.appendingPathComponent("projects")
        guard
            let projectDirectories = try? FileManager.default.contentsOfDirectory(
                at: projectsDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else { return [] }

        var transcriptFiles: [URL] = []
        var subagentFiles: [URL] = []
        let conversations = projectDirectories.flatMap { projectDirectory -> [Conversation] in
            guard !cancellation.isCancelled else { return [] }
            let index = ClaudeSessionsIndex(projectDirectory: projectDirectory)
            let files =
                (try? FileManager.default.contentsOfDirectory(
                    at: projectDirectory,
                    includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                )) ?? []
            transcriptFiles += files
            return files.compactMap {
                cancellation.isCancelled ? nil : conversation(in: $0, index: index)
            }.flatMap { conversation -> [Conversation] in
                guard !cancellation.isCancelled else { return [] }
                let sessionSubagentFiles = ClaudeSubagentSessions.files(
                    ofSessionID: conversation.sessionID, inProjectDirectory: projectDirectory)
                subagentFiles += sessionSubagentFiles
                return [conversation] + sessionSubagentFiles.compactMap { subagentConversation(in: $0, startedBy: conversation) }
            }
        }
        try cancellation.checkCancellation()
        Self.transcriptHeads.forgetFiles(in: projectsDirectory, except: transcriptFiles)
        Self.transcriptTails.forgetFiles(in: projectsDirectory, except: transcriptFiles)
        Self.subagentSessions.forgetFiles(in: projectsDirectory, except: subagentFiles)
        return conversations
    }

    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] {
        switch action {
        case .new: []
        case .resume: ["--resume", conversation.sessionID]
        case .branch: ["--resume", conversation.sessionID, "--fork-session"]
        }
    }

    func delete(_ conversation: Conversation) throws {
        try ClaudeConversationDeletion(configurationDirectory: configurationDirectory).delete(conversation)
    }

    /// A session moved with `/cd` is listed under the folder it moved to, and one in a git worktree under the
    /// repository it entered the worktree from, as Claude Code lists them.
    private func conversation(in file: URL, index: ClaudeSessionsIndex) -> Conversation? {
        let sessionID = file.deletingPathExtension().lastPathComponent
        guard file.pathExtension == "jsonl", ConversationMetadata.isValidSessionID(sessionID) else { return nil }
        let indexEntry = index.entry(forSessionID: sessionID)
        if indexEntry?.isSidechain == true { return nil }
        guard let head = Self.transcriptHeads.summary(of: file, read: ClaudeTranscriptHead.init(file:)),
            !head.isSidechain,
            let tail = Self.transcriptTails.summary(of: file, read: ClaudeTranscriptTail.init(file:)),
            let projectPath = tail.movedProjectDirectory
                ?? indexEntry?.projectPath
                ?? head.workingDirectory
                ?? index.originalProjectPath
        else {
            return nil
        }
        let title = ConversationMetadata.cleanTitle(
            tail.latestCustomTitle
                ?? indexEntry?.customTitle
                ?? head.customTitle
                ?? tail.latestAITitle
                ?? head.aiTitle
                // The index can record a slash command's markup as the first prompt; the head skips it.
                ?? indexEntry?.firstPrompt.flatMap { ConversationMetadata.holdsTitle($0) ? $0 : nil }
                ?? head.firstPrompt,
            fallback: ConversationMetadata.untitledConversationTitle
        )
        let updatedAt =
            [indexEntry?.modifiedAt, tail.latestTimestamp].compactMap { $0 }.max()
            ?? ConversationMetadata.fileModificationDate(file)
        return Conversation(
            provider: provider,
            sessionID: sessionID,
            projectPath: projectPath,
            suggestedTitle: title,
            updatedAt: updatedAt,
            sourceFile: file,
            model: SessionModel(id: tail.latestModel)
        )
    }

    private func subagentConversation(in file: URL, startedBy parent: Conversation) -> Conversation? {
        guard let agentID = ClaudeSubagentSessions.agentID(of: file),
            let session = Self.subagentSessions.summary(of: file, read: ClaudeSubagentSession.init(file:))
        else { return nil }
        return Conversation(
            provider: provider,
            sessionID: agentID,
            projectPath: session.workingDirectory ?? parent.projectPath,
            suggestedTitle: session.title,
            updatedAt: ConversationMetadata.fileModificationDate(file),
            sourceFile: file,
            parentSessionID: parent.sessionID,
            model: SessionModel(id: session.model)
        )
    }
}
