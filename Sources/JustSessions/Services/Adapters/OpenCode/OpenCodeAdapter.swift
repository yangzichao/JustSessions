import Foundation

/// OpenCode keeps every session in one SQLite database, `opencode.db` in its data folder. Each listed session's
/// source file is that database.
struct OpenCodeAdapter: ConversationAdapter {
    let databaseFile: URL
    let deletionExecutableURL: URL?
    var provider: ConversationProvider { .opencode }

    /// `OPENCODE_DB` when it is an absolute path, or else `opencode.db` in `$XDG_DATA_HOME/opencode`
    /// (`~/.local/share/opencode`), as OpenCode's stable releases use.
    static func standardDatabaseFile(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory()
    ) -> URL {
        if let configured = environment["OPENCODE_DB"], configured.hasPrefix("/") {
            return URL(fileURLWithPath: configured)
        }
        let dataHome = environment["XDG_DATA_HOME"].flatMap { $0.hasPrefix("/") ? $0 : nil } ?? homeDirectory + "/.local/share"
        return URL(fileURLWithPath: dataHome).appendingPathComponent("opencode/opencode.db")
    }

    init(databaseFile: URL = OpenCodeAdapter.standardDatabaseFile(), deletionExecutableURL: URL? = nil) {
        self.databaseFile = databaseFile
        self.deletionExecutableURL = deletionExecutableURL
    }

    /// Every session, a subagent's under the session that started it.
    func discover() throws -> [Conversation] {
        OpenCodeSQLiteReader.sessions(in: databaseFile).compactMap { session in
            guard provider.isValidSessionID(session.sessionID), session.projectPath.hasPrefix("/"),
                  session.parentSessionID.map(provider.isValidSessionID) != false else { return nil }
            return Conversation(
                provider: provider,
                sessionID: session.sessionID,
                projectPath: session.projectPath,
                suggestedTitle: ConversationMetadata.cleanTitle(
                    session.title.flatMap { Self.isPlaceholderTitle($0) ? nil : $0 },
                    fallback: ConversationMetadata.untitledConversationTitle
                ),
                updatedAt: session.updatedAt,
                sourceFile: databaseFile,
                parentSessionID: session.parentSessionID
            )
        }
    }

    /// OpenCode titles a session `New session - <ISO 8601 time>` until it has written a title from the first prompt.
    static func isPlaceholderTitle(_ title: String) -> Bool {
        let prefix = "New session - "
        return title.hasPrefix(prefix) && ConversationMetadata.date(String(title.dropFirst(prefix.count))) != nil
    }

    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] {
        switch action {
        case .new: []
        case .resume: ["--session", conversation.sessionID]
        case .branch: ["--session", conversation.sessionID, "--fork"]
        }
    }

    func delete(_ conversation: Conversation) throws {
        try OpenCodeConversationDeletion(databaseFile: databaseFile, executableURL: deletionExecutableURL).delete(conversation)
    }
}
