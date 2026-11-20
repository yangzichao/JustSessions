import Foundation

/// Kiro deletes its own session files and internal records through its native CLI: `kiro-cli chat --delete-session`
/// takes a V2 session's id or a V3 session's `sess_` id, and removes a V3 session's whole folder (Kiro CLI 2.16.2).
/// A session a running CLI holds (`KiroSessionLock`) isn't handed to Kiro, which would keep it or write it again. Kiro
/// leaves `sessions/cli/<id>.history`, the prompts typed in the session, and a V2 session's lock when its CLI ended
/// without removing it; they go once Kiro has deleted the rest.
struct KiroConversationDeletion {
    let sessionsDirectory: URL
    let v3SessionsDirectory: URL?
    let executableURL: URL?
    let fileManager: FileManager
    let timeout: TimeInterval
    /// How long a held lock may take to go: Close and delete waits for the tab's process, and Kiro's lock is held by a
    /// process below it that may still be ending (`KiroSessionLock`).
    let lockReleaseTimeout: TimeInterval

    init(
        sessionsDirectory: URL, v3SessionsDirectory: URL? = nil, executableURL: URL? = nil, fileManager: FileManager = .default,
        timeout: TimeInterval = 60, lockReleaseTimeout: TimeInterval = 2
    ) {
        self.sessionsDirectory = sessionsDirectory
        self.v3SessionsDirectory = v3SessionsDirectory
        self.executableURL = executableURL
        self.fileManager = fileManager
        self.timeout = timeout
        self.lockReleaseTimeout = lockReleaseTimeout
    }

    func delete(_ conversation: Conversation) throws {
        if KiroV3Session.isSessionID(conversation.sessionID) {
            try deleteV3(conversation)
            return
        }
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
        guard sourceFile.isPlainFileNotLinkOrPipe,
            metadataFile.isPlainFileNotLinkOrPipe,
            let metadata = KiroSessionMetadata(file: metadataFile),
            metadata.sessionID == conversation.sessionID,
            metadata.projectPath.hasPrefix("/"),
            metadata.projectPath == conversation.projectPath
        else { throw ConversationDeletionError.invalidSource }
        try waitForLockRelease(of: sourceFile)

        try runDeletion(of: conversation)
        guard !fileManager.fileExists(atPath: sourceFile.path), !fileManager.fileExists(atPath: metadataFile.path) else {
            throw KiroConversationDeletionError.sourceStillPresent
        }
        removeLeftovers(of: conversation, named: ["history", "lock"])
    }

    private func deleteV3(_ conversation: Conversation) throws {
        let sourceFile = conversation.sourceFile.standardizedFileURL
        let sessionFolder = sourceFile.deletingLastPathComponent()
        let metadataFile = sessionFolder.appendingPathComponent(KiroV3Session.metadataFileName)
        guard conversation.provider == .kiro,
            conversation.host == .thisMac,
            let v3SessionsDirectory,
            sessionsDirectory.lastPathComponent == "cli",
            v3SessionsDirectory.standardizedFileURL
                == KiroV3Session.sessionsRoot(besideClassicDirectory: sessionsDirectory)
                .standardizedFileURL,
            sourceFile.lastPathComponent == KiroV3Session.messagesFileName,
            sessionFolder.lastPathComponent == conversation.sessionID,
            sessionFolder.resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent().path
                == v3SessionsDirectory.resolvingSymlinksInPath().path,
            sessionFolder.deletingLastPathComponent().lastPathComponent != sessionsDirectory.lastPathComponent
        else { throw ConversationDeletionError.invalidSource }
        guard fileManager.fileExists(atPath: sourceFile.path), fileManager.fileExists(atPath: metadataFile.path) else {
            throw ConversationDeletionError.missingSource
        }
        guard sourceFile.isPlainFileNotLinkOrPipe,
            let metadata = KiroV3SessionMetadata(file: metadataFile),
            metadata.sessionID == conversation.sessionID,
            metadata.projectPath == conversation.projectPath,
            metadata.projectPath.hasPrefix("/")
        else { throw ConversationDeletionError.invalidSource }
        try waitForLockRelease(of: sourceFile)
        try runDeletion(of: conversation)
        guard !fileManager.fileExists(atPath: sourceFile.path), !fileManager.fileExists(atPath: metadataFile.path) else {
            throw KiroConversationDeletionError.sourceStillPresent
        }
        removeLeftovers(of: conversation, named: ["history"])
    }

    private func waitForLockRelease(of sourceFile: URL) throws {
        let deadline = Date.now.addingTimeInterval(lockReleaseTimeout)
        while KiroSessionLock.heldLock(forSessionFile: sourceFile) != nil {
            guard Date.now < deadline else { throw KiroConversationDeletionError.stillRunning }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    private func removeLeftovers(of conversation: Conversation, named fileExtensions: [String]) {
        for fileExtension in fileExtensions {
            let file = sessionsDirectory.appendingPathComponent("\(conversation.sessionID).\(fileExtension)")
            guard file.isPlainFileNotLinkOrPipe else { continue }
            try? fileManager.removeItem(at: file)
        }
    }

    /// `kiro-cli chat --delete-session <id>` in the session's folder, as Kiro scopes a session to it, with `KIRO_HOME`
    /// the home the session was read from.
    private func runDeletion(of conversation: Conversation) throws {
        let resolver = NativeCLICommandResolver()
        guard let executablePath = executableURL?.path ?? resolver.executablePath(named: "kiro-cli") else {
            throw NativeCLICommandError.missingExecutable("kiro-cli")
        }
        let kiroDirectory = sessionsDirectory.deletingLastPathComponent().deletingLastPathComponent()
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = resolver.pathEnvironmentValue
        environment["KIRO_HOME"] = kiroDirectory.path
        var isProjectDirectory: ObjCBool = false
        let projectExists =
            fileManager.fileExists(atPath: conversation.projectPath, isDirectory: &isProjectDirectory)
            && isProjectDirectory.boolValue
        guard
            let result = BoundedProcessRunner.result(
                ofExecutable: executablePath,
                arguments: ["chat", "--delete-session", conversation.sessionID],
                environment: environment,
                workingDirectory: projectExists ? URL(fileURLWithPath: conversation.projectPath) : kiroDirectory,
                includesStandardError: true,
                timeout: timeout
            )
        else { throw KiroConversationDeletionError.didNotFinish }
        let details = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.exitStatus == 0 else {
            throw KiroConversationDeletionError.failed(details.isEmpty ? "Exit code \(result.exitStatus)" : String(details.prefix(500)))
        }
    }
}
