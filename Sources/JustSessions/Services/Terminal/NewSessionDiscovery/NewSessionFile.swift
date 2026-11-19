import Foundation

struct NewSessionFile: Sendable, Equatable {
    let sessionID: String
    let file: URL
    /// Includes a SQLite `-wal` companion, where Antigravity writes first.
    let lastModified: Date
}
