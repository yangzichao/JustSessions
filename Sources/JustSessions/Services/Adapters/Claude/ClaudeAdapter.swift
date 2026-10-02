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

    /// Shared by every Claude Code adapter, this Mac's and each SSH host's mirror, which keep their files apart.
    private static let transcriptHeads = SessionFileSummaryCache<ClaudeTranscriptHead>()
    private static let transcriptTails = SessionFileSummaryCache<ClaudeTranscriptTail>()

    func discover() throws -> [Conversation] {
        let projectsDirectory = configurationDirectory.appendingPathComponent("projects")
        guard let projectDirectories = try? FileManager.default.contentsOfDirectory(
            at: projectsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var transcriptFiles: [URL] = []
        let conversations = projectDirectories.flatMap { projectDirectory -> [Conversation] in
            let index = ClaudeSessionsIndex(projectDirectory: projectDirectory)
            let files = (try? FileManager.default.contentsOfDirectory(
                at: projectDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            transcriptFiles += files
            return files.compactMap { conversation(in: $0, index: index) }
        }
        Self.transcriptHeads.forgetFiles(in: projectsDirectory, except: transcriptFiles)
        Self.transcriptTails.forgetFiles(in: projectsDirectory, except: transcriptFiles)
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

    /// Nil for a file that is not a session transcript, for a sidechain session, or when no project folder is known.
    private func conversation(in file: URL, index: ClaudeSessionsIndex) -> Conversation? {
        let sessionID = file.deletingPathExtension().lastPathComponent
        guard file.pathExtension == "jsonl", ConversationMetadata.isValidSessionID(sessionID) else { return nil }
        let indexEntry = index.entry(forSessionID: sessionID)
        if indexEntry?.isSidechain == true { return nil }
        guard let head = Self.transcriptHeads.summary(of: file, read: ClaudeTranscriptHead.init(file:)),
              !head.isSidechain,
              let projectPath = indexEntry?.projectPath ?? head.workingDirectory ?? index.originalProjectPath else {
            return nil
        }
        guard let tail = Self.transcriptTails.summary(of: file, read: ClaudeTranscriptTail.init(file:)) else { return nil }
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
