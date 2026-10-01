import Foundation

/// Kiro deletes its own session files and internal records through its native CLI.
struct KiroConversationDeletion {
    let sessionsDirectory: URL
    let executableURL: URL?
    let fileManager: FileManager
    let timeout: TimeInterval

    init(sessionsDirectory: URL, executableURL: URL? = nil, fileManager: FileManager = .default, timeout: TimeInterval = 60) {
        self.sessionsDirectory = sessionsDirectory
        self.executableURL = executableURL
        self.fileManager = fileManager
        self.timeout = timeout
    }

    func delete(_ conversation: Conversation) throws {
        let sourceFile = conversation.sourceFile.standardizedFileURL
        let metadataFile = sourceFile.deletingPathExtension().appendingPathExtension("json")
        let resolvedSessionsPath = sessionsDirectory.resolvingSymlinksInPath().path
        guard conversation.provider == .kiro,
              conversation.host == .thisMac,
              sessionsDirectory.lastPathComponent == "cli",
              sessionsDirectory.deletingLastPathComponent().lastPathComponent == "sessions",
              ConversationProvider.kiro.isValidSessionID(conversation.sessionID),
              sourceFile.lastPathComponent == "\(conversation.sessionID).jsonl",
              sourceFile.deletingLastPathComponent().resolvingSymlinksInPath().path == resolvedSessionsPath,
              sourceFile.resolvingSymlinksInPath().deletingLastPathComponent().path == resolvedSessionsPath,
              metadataFile.resolvingSymlinksInPath().deletingLastPathComponent().path == resolvedSessionsPath
        else { throw ConversationDeletionError.invalidSource }
        guard fileManager.fileExists(atPath: sourceFile.path), fileManager.fileExists(atPath: metadataFile.path) else {
            throw ConversationDeletionError.missingSource
        }
        guard (try? sourceFile.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true,
              (try? metadataFile.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true,
              let metadata = KiroSessionMetadata(file: metadataFile),
              metadata.sessionID == conversation.sessionID,
              metadata.projectPath.hasPrefix("/"),
              metadata.projectPath == conversation.projectPath
        else { throw ConversationDeletionError.invalidSource }

        let resolver = NativeCLICommandResolver()
        guard let executablePath = executableURL?.path ?? resolver.executablePath(named: "kiro-cli") else {
            throw NativeCLICommandError.missingExecutable("kiro-cli")
        }
        let kiroDirectory = sessionsDirectory.deletingLastPathComponent().deletingLastPathComponent()
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = resolver.pathEnvironmentValue
        environment["KIRO_HOME"] = kiroDirectory.path
        var isProjectDirectory: ObjCBool = false
        let projectExists = fileManager.fileExists(atPath: conversation.projectPath, isDirectory: &isProjectDirectory)
            && isProjectDirectory.boolValue
        guard let result = BoundedProcessRunner.result(
            ofExecutable: executablePath,
            arguments: ["chat", "--delete-session", conversation.sessionID],
            environment: environment,
            workingDirectory: projectExists ? URL(fileURLWithPath: conversation.projectPath) : kiroDirectory,
            includesStandardError: true,
            timeout: timeout
        ) else { throw KiroConversationDeletionError.didNotFinish }
        let details = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.exitStatus == 0 else {
            throw KiroConversationDeletionError.failed(details.isEmpty ? "Exit code \(result.exitStatus)" : String(details.prefix(500)))
        }
        guard !fileManager.fileExists(atPath: sourceFile.path), !fileManager.fileExists(atPath: metadataFile.path) else {
            throw KiroConversationDeletionError.sourceStillPresent
        }
    }
}
