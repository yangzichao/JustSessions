import Foundation

/// Deletes a Codex session through `codex delete`, which also drops it from Codex's own index.
struct CodexConversationDeletion {
    let codexDirectory: URL
    let executableURL: URL?
    let fileManager: FileManager
    /// How long `codex delete` may take before it is stopped and the deletion reported as failed.
    let timeout: TimeInterval

    init(codexDirectory: URL, executableURL: URL? = nil, fileManager: FileManager = .default, timeout: TimeInterval = 60) {
        self.codexDirectory = codexDirectory
        self.executableURL = executableURL
        self.fileManager = fileManager
        self.timeout = timeout
    }

    func delete(_ conversation: Conversation) throws {
        let sourceFile = conversation.sourceFile.standardizedFileURL
        let sessionsDirectory = codexDirectory.appendingPathComponent("sessions").standardizedFileURL
        guard conversation.provider == .codex,
              ConversationMetadata.isValidSessionID(conversation.sessionID),
              sourceFile.pathExtension == "jsonl",
              sourceFile.lastPathComponent.hasPrefix("rollout-"),
              sourceFile.resolvingSymlinksInPath().path.hasPrefix(sessionsDirectory.resolvingSymlinksInPath().path + "/")
        else { throw ConversationDeletionError.invalidSource }
        guard fileManager.fileExists(atPath: sourceFile.path) else {
            throw ConversationDeletionError.missingSource
        }
        guard
              let metadata = ConversationMetadata.firstLine(of: sourceFile),
              let payload = metadata["payload"] as? [String: Any],
              payload["id"] as? String == conversation.sessionID
        else { throw ConversationDeletionError.invalidSource }

        let resolver = NativeCLICommandResolver()
        guard let executablePath = executableURL?.path ?? resolver.executablePath(named: "codex") else {
            throw NativeCLICommandError.missingExecutable("codex")
        }
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = resolver.pathEnvironmentValue
        environment["CODEX_HOME"] = codexDirectory.path
        guard let result = BoundedProcessRunner.result(
            ofExecutable: executablePath,
            arguments: ["delete", "--force", conversation.sessionID],
            environment: environment,
            workingDirectory: codexDirectory,
            includesStandardError: true,
            timeout: timeout
        ) else { throw ConversationDeletionError.codexDidNotFinish }
        let details = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.exitStatus == 0 else {
            throw ConversationDeletionError.codexFailed(details.isEmpty ? "Exit code \(result.exitStatus)" : String(details.prefix(500)))
        }
        guard !fileManager.fileExists(atPath: sourceFile.path) else {
            throw ConversationDeletionError.sourceStillPresent
        }
    }
}
