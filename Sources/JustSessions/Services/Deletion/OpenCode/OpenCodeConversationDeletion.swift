import Foundation

/// OpenCode deletes a session through its native CLI, which also deletes the session's subagent sessions and
/// every message and part of them. `OPENCODE_DB` points the CLI at the database the session was listed from.
struct OpenCodeConversationDeletion {
    let databaseFile: URL
    let executableURL: URL?
    let timeout: TimeInterval

    init(databaseFile: URL, executableURL: URL? = nil, timeout: TimeInterval = 60) {
        self.databaseFile = databaseFile
        self.executableURL = executableURL
        self.timeout = timeout
    }

    func delete(_ conversation: Conversation) throws {
        guard conversation.provider == .opencode,
              conversation.host == .thisMac,
              ConversationProvider.opencode.isValidSessionID(conversation.sessionID),
              conversation.sourceFile.standardizedFileURL.path == databaseFile.standardizedFileURL.path
        else { throw ConversationDeletionError.invalidSource }
        guard try OpenCodeDatabase.containsSession(conversation.sessionID, in: databaseFile) else {
            throw ConversationDeletionError.missingSource
        }
        guard try OpenCodeDatabase.containsTopLevelSession(
            conversation.sessionID, projectPath: conversation.projectPath, in: databaseFile
        ) else { throw ConversationDeletionError.sourceMismatch }

        let resolver = NativeCLICommandResolver()
        guard let executablePath = executableURL?.path ?? resolver.executablePath(named: "opencode") else {
            throw NativeCLICommandError.missingExecutable("opencode")
        }
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = resolver.pathEnvironmentValue
        environment["OPENCODE_DB"] = databaseFile.path
        // Its data folder, not the project, so a project's own OpenCode configuration plays no part.
        guard let result = BoundedProcessRunner.result(
            ofExecutable: executablePath,
            arguments: ["session", "delete", conversation.sessionID],
            environment: environment,
            workingDirectory: databaseFile.deletingLastPathComponent(),
            includesStandardError: true,
            timeout: timeout
        ) else { throw OpenCodeConversationDeletionError.didNotFinish }
        guard result.exitStatus == 0 else {
            let details = TerminalEscapeSequences.removed(from: result.output).trimmingCharacters(in: .whitespacesAndNewlines)
            throw OpenCodeConversationDeletionError.failed(details.isEmpty ? "Exit code \(result.exitStatus)" : String(details.prefix(500)))
        }
        guard try !OpenCodeDatabase.containsSession(conversation.sessionID, in: databaseFile) else {
            throw OpenCodeConversationDeletionError.sessionStillPresent
        }
    }
}
