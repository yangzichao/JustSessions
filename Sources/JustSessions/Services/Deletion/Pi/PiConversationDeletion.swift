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
        self.moveToTrash =
            moveToTrash ?? { url in
                try fileManager.trashItem(at: url, resultingItemURL: nil)
            }
    }

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
            let header = PiSessionFileHeader(firstLineOf: sourceFile),
            header.type == "session",
            header.id == conversation.sessionID
        else { throw ConversationDeletionError.sourceMismatch }

        let companionDirectory = sourceFile.deletingPathExtension()
        if itemType(at: companionDirectory) == .typeDirectory {
            try moveToTrash(companionDirectory)
        }
        try moveToTrash(sourceFile)
    }

    private func itemType(at url: URL) -> FileAttributeType? {
        (try? fileManager.attributesOfItem(atPath: url.path))?[.type] as? FileAttributeType
    }
}
