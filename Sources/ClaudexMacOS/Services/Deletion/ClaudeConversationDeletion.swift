import Foundation

struct ClaudeConversationDeletion {
    let configurationDirectory: URL
    let fileManager: FileManager
    let moveToTrash: (URL) throws -> Void

    init(
        configurationDirectory: URL,
        fileManager: FileManager = .default,
        moveToTrash: ((URL) throws -> Void)? = nil
    ) {
        self.configurationDirectory = configurationDirectory
        self.fileManager = fileManager
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
        try removeIndexEntry(for: conversation.sessionID, in: projectDirectory)
    }

    private func removeIndexEntry(for sessionID: String, in projectDirectory: URL) throws {
        let indexFile = projectDirectory.appendingPathComponent("sessions-index.json")
        guard fileManager.fileExists(atPath: indexFile.path) else { return }
        let data = try Data(contentsOf: indexFile)
        guard var index = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = index["entries"] as? [[String: Any]] else { return }
        let remainingEntries = entries.filter { $0["sessionId"] as? String != sessionID }
        guard remainingEntries.count != entries.count else { return }
        index["entries"] = remainingEntries
        let updatedData = try JSONSerialization.data(withJSONObject: index, options: [.prettyPrinted, .sortedKeys])
        try updatedData.write(to: indexFile, options: .atomic)
    }
}
