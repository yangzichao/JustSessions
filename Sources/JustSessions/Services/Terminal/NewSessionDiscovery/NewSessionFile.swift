import Foundation

/// The session file a waiting tab's CLI is writing.
struct NewSessionFile: Sendable, Equatable {
    let sessionID: String
    let file: URL
    /// Includes a SQLite `-wal` companion, where Antigravity writes first.
    let lastModified: Date
}
