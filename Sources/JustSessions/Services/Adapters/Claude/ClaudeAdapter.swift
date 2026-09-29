import Foundation

struct ClaudeAdapter: ConversationAdapter {
    let configurationDirectory: URL
    var provider: ConversationProvider { .claude }

    static var defaultConfigurationDirectory: URL {
        let configured = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"]
        return URL(fileURLWithPath: configured ?? NSHomeDirectory() + "/.claude")
    }

    init(configurationDirectory: URL = ClaudeAdapter.defaultConfigurationDirectory) {
        self.configurationDirectory = configurationDirectory
    }

    func discover() throws -> [Conversation] {
        let projectsDirectory = configurationDirectory.appendingPathComponent("projects")
        guard let projectDirectories = try? FileManager.default.contentsOfDirectory(
            at: projectsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return projectDirectories.flatMap { projectDirectory -> [Conversation] in
            let index = ClaudeSessionsIndex(projectDirectory: projectDirectory)
            let files = (try? FileManager.default.contentsOfDirectory(
                at: projectDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            return files.compactMap { conversation(in: $0, index: index) }
        }
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

    /// Nil for a file that is not a session transcript, for a sidechain session, or when no project folder is known.
    private func conversation(in file: URL, index: ClaudeSessionsIndex) -> Conversation? {
        let sessionID = file.deletingPathExtension().lastPathComponent
        guard file.pathExtension == "jsonl", ConversationMetadata.isValidSessionID(sessionID) else { return nil }
        let indexEntry = index.entry(forSessionID: sessionID)
        if indexEntry?.isSidechain == true { return nil }
        let head = ClaudeTranscriptHead(file: file)
        guard !head.isSidechain,
              let projectPath = indexEntry?.projectPath ?? head.workingDirectory ?? index.originalProjectPath else {
            return nil
        }
        let tail = ClaudeTranscriptTail(file: file)
        let title = ConversationMetadata.cleanTitle(
            tail.latestCustomTitle
                ?? indexEntry?.customTitle
                ?? head.customTitle
                ?? indexEntry?.firstPrompt
                ?? head.firstPrompt,
            fallback: ConversationMetadata.untitledConversationTitle
        )
        let updatedAt = [indexEntry?.modifiedAt, tail.latestTimestamp].compactMap { $0 }.max()
            ?? ConversationMetadata.fileModificationDate(file)
        return Conversation(
            provider: provider,
            sessionID: sessionID,
            projectPath: projectPath,
            suggestedTitle: title,
            updatedAt: updatedAt,
            sourceFile: file
        )
    }
}
