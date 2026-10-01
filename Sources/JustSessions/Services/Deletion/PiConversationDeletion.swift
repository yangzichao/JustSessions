import Foundation

/// Moves a Pi session to the Trash: the folder of the same name beside its `.jsonl` file, where extensions keep
/// subagent runs, forks, and artifacts, then the file itself. Pi's own delete leaves that folder behind.
struct PiConversationDeletion {
    let sessionsDirectory: URL
    let fileManager: FileManager
    let moveToTrash: (URL) throws -> Void

    init(
        sessionsDirectory: URL,
        fileManager: FileManager = .default,
        moveToTrash: ((URL) throws -> Void)? = nil
    ) {
        self.sessionsDirectory = sessionsDirectory
        self.fileManager = fileManager
        self.moveToTrash = moveToTrash ?? { url in
            try fileManager.trashItem(at: url, resultingItemURL: nil)
        }
    }

    /// Only a file Pi would list is deleted: one directly in the sessions folder or in one of its project folders,
    /// named for the session, and whose header names the same session.
    ///
    /// The folder goes first. If moving it fails, nothing has changed; if moving the file then fails, the session is
    /// still listed. Either way, deleting it again finishes the job.
    func delete(_ conversation: Conversation) throws {
        let sourceFile = conversation.sourceFile.standardizedFileURL
        let sessionsPath = sessionsDirectory.standardizedFileURL.resolvingSymlinksInPath().path
        let containingFolder = sourceFile.deletingLastPathComponent().resolvingSymlinksInPath()
        guard conversation.provider == .pi,
              conversation.provider.isValidSessionID(conversation.sessionID),
              sourceFile.lastPathComponent.hasSuffix("_\(conversation.sessionID).jsonl"),
              containingFolder.path == sessionsPath || containingFolder.deletingLastPathComponent().path == sessionsPath
        else { throw ConversationDeletionError.invalidSource }
        guard fileManager.fileExists(atPath: sourceFile.path) else {
            throw ConversationDeletionError.missingSource
        }
        guard itemType(at: sourceFile) == .typeRegular,
              let header = ConversationMetadata.firstLine(of: sourceFile),
              header["type"] as? String == "session",
              header["id"] as? String == conversation.sessionID
        else { throw ConversationDeletionError.sourceMismatch }

        let companionDirectory = sourceFile.deletingPathExtension()
        if itemType(at: companionDirectory) == .typeDirectory {
            try moveToTrash(companionDirectory)
        }
        try moveToTrash(sourceFile)
    }

    /// The item's own type, so a symbolic link is reported as one rather than as what it points to.
    private func itemType(at url: URL) -> FileAttributeType? {
        (try? fileManager.attributesOfItem(atPath: url.path))?[.type] as? FileAttributeType
    }
}
