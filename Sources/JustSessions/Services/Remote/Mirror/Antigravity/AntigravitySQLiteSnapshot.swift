import Foundation
import SQLite3

enum AntigravitySQLiteSnapshot {
    /// SQLite's backup API includes committed WAL pages without copying shared-memory locks.
    static func copyDatabase(at source: URL, to destination: URL) throws {
        let original = try AntigravityDatabase.open(source)
        defer { sqlite3_close(original) }
        var copied: OpaquePointer?
        guard sqlite3_open(destination.path, &copied) == SQLITE_OK, let copied else {
            if let copied { sqlite3_close(copied) }
            throw AntigravityDatabaseError.unreadable
        }
        defer { sqlite3_close(copied) }
        guard let backup = sqlite3_backup_init(copied, "main", original, "main") else { throw AntigravityDatabaseError.unreadable }
        let deadline = Date().addingTimeInterval(10)
        var result = sqlite3_backup_step(backup, 128)
        while result == SQLITE_OK && Date() < deadline { result = sqlite3_backup_step(backup, 128) }
        let finishResult = sqlite3_backup_finish(backup)
        guard result == SQLITE_DONE, finishResult == SQLITE_OK else { throw AntigravityDatabaseError.unreadable }
        try AntigravityDatabase.execute("PRAGMA journal_mode=DELETE", in: copied)
        let updatedAt = max(ConversationMetadata.fileModificationDate(source),
                            ConversationMetadata.fileModificationDate(URL(fileURLWithPath: source.path + "-wal")))
        try FileManager.default.setAttributes([.modificationDate: updatedAt], ofItemAtPath: destination.path)
    }

    static func copySessionStore(at source: URL, to destination: URL) throws {
        let conversations = source.appendingPathComponent("conversations")
        let destinationConversations = destination.appendingPathComponent("conversations")
        try FileManager.default.createDirectory(at: destinationConversations, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: conversations, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "db"
            && ConversationMetadata.isValidSessionID(file.deletingPathExtension().lastPathComponent) {
            guard file.resolvingSymlinksInPath().path == conversations.resolvingSymlinksInPath().appendingPathComponent(file.lastPathComponent).path else {
                throw AntigravityDatabaseError.unreadable
            }
            try copyDatabase(at: file, to: destinationConversations.appendingPathComponent(file.lastPathComponent))
        }
        let index = source.appendingPathComponent("conversation_summaries.db")
        if FileManager.default.fileExists(atPath: index.path) {
            guard index.resolvingSymlinksInPath().path == source.resolvingSymlinksInPath().appendingPathComponent(index.lastPathComponent).path else {
                throw AntigravityDatabaseError.unreadable
            }
            try copyDatabase(at: index, to: destination.appendingPathComponent(index.lastPathComponent))
        }
    }
}
