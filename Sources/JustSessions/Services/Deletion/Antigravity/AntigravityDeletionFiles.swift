import Foundation

enum AntigravityDeletionFiles {
    static func validated(for conversation: Conversation, configurationDirectory: URL) throws -> [URL] {
        let root = configurationDirectory.standardizedFileURL
        let source = conversation.sourceFile.standardizedFileURL
        let directory = root.appendingPathComponent("conversations")
        guard conversation.provider == .antigravity,
              ConversationProvider.antigravity.isValidSessionID(conversation.sessionID),
              source.lastPathComponent == "\(conversation.sessionID).db",
              source.deletingLastPathComponent().resolvingSymlinksInPath().path == directory.resolvingSymlinksInPath().path,
              source.resolvingSymlinksInPath().path == directory.resolvingSymlinksInPath().appendingPathComponent(source.lastPathComponent).path
        else { throw ConversationDeletionError.invalidSource }
        guard FileManager.default.fileExists(atPath: source.path) else { throw ConversationDeletionError.missingSource }
        guard let session = AntigravitySQLiteReader.localSession(at: source),
              session.sessionID == conversation.sessionID, session.projectPath == conversation.projectPath else {
            throw ConversationDeletionError.invalidSource
        }
        let candidates = databaseFiles(source) + [
            root.appendingPathComponent("brain/\(conversation.sessionID)"),
            root.appendingPathComponent("annotations/\(conversation.sessionID).pbtxt"),
        ]
        let resolvedRoot = root.resolvingSymlinksInPath().path + "/"
        for folderName in ["conversations", "brain", "annotations"] {
            let folder = root.appendingPathComponent(folderName)
            guard folder.resolvingSymlinksInPath().path == resolvedRoot + folderName else {
                throw ConversationDeletionError.invalidSource
            }
        }
        for file in candidates + databaseFiles(root.appendingPathComponent("conversation_summaries.db")) {
            guard file.resolvingSymlinksInPath().path == resolvedRoot + String(file.path.dropFirst(root.path.count + 1)) else {
                throw ConversationDeletionError.invalidSource
            }
        }
        return candidates.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func databaseFiles(_ database: URL) -> [URL] {
        [database, URL(fileURLWithPath: database.path + "-wal"), URL(fileURLWithPath: database.path + "-shm")]
    }
}
