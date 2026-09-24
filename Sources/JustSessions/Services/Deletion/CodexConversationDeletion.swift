import Foundation

struct CodexConversationDeletion {
    let codexDirectory: URL
    let executableURL: URL?
    let fileManager: FileManager

    init(codexDirectory: URL, executableURL: URL? = nil, fileManager: FileManager = .default) {
        self.codexDirectory = codexDirectory
        self.executableURL = executableURL
        self.fileManager = fileManager
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["delete", "--force", conversation.sessionID]
        process.currentDirectoryURL = codexDirectory
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = resolver.pathEnvironmentValue
        environment["CODEX_HOME"] = codexDirectory.path
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let details = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            throw ConversationDeletionError.codexFailed(details.isEmpty ? "Exit code \(process.terminationStatus)" : String(details.prefix(500)))
        }
        guard !fileManager.fileExists(atPath: sourceFile.path) else {
            throw ConversationDeletionError.sourceStillPresent
        }
    }
}
