import Foundation

struct ClaudeConversationDeletion {
    let configurationDirectory: URL
    let fileManager: FileManager
    let moveToTrash: (URL) throws -> Void
    let indexBatch: ClaudeDeletionIndexBatch?

    init(
        configurationDirectory: URL,
        fileManager: FileManager = .default,
        moveToTrash: ((URL) throws -> Void)? = nil,
        indexBatch: ClaudeDeletionIndexBatch? = nil
    ) {
        self.configurationDirectory = configurationDirectory
        self.fileManager = fileManager
        self.indexBatch = indexBatch
        self.moveToTrash = moveToTrash ?? { url in
            try fileManager.trashItem(at: url, resultingItemURL: nil)
        }
    }

    func delete(_ conversation: Conversation) throws {
        let sourceFile = conversation.sourceFile.standardizedFileURL
        let projectDirectory = sourceFile.deletingLastPathComponent()
        let projectsDirectory = configurationDirectory.appendingPathComponent("projects").standardizedFileURL
        guard conversation.provider == .claude,
              ConversationMetadata.isValidSessionID(conversation.sessionID),
              sourceFile.lastPathComponent == "\(conversation.sessionID).jsonl",
              projectDirectory.deletingLastPathComponent().resolvingSymlinksInPath() == projectsDirectory.resolvingSymlinksInPath()
        else { throw ConversationDeletionError.invalidSource }
        guard fileManager.fileExists(atPath: sourceFile.path) else {
            throw ConversationDeletionError.missingSource
        }

        try moveToTrash(sourceFile)

        let companionDirectory = projectDirectory.appendingPathComponent(conversation.sessionID)
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: companionDirectory.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            try moveToTrash(companionDirectory)
        }
        if let indexBatch { indexBatch.record(conversation, in: projectDirectory) }
        else { try ClaudeConversationIndex.remove(sessionIDs: [conversation.sessionID], in: projectDirectory) }
    }
}
