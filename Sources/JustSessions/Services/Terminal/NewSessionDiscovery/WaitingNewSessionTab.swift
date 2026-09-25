import Foundation

/// A "new session" tab that has no conversation yet, copied off the main actor for the session file search.
struct WaitingNewSessionTab: Sendable {
    let terminalID: UUID
    let provider: ConversationProvider
    let processID: Int32
    /// The id the app asked the CLI to use (`claude --session-id`), when the CLI accepts one.
    let preassignedSessionID: String?
    /// A process id is only evidence while the CLI runs; after it exits the id can belong to anything.
    let isRunning: Bool
}

/// The session file a waiting tab's CLI is writing.
struct NewSessionFile: Sendable, Equatable {
    let sessionID: String
    let file: URL
    /// Includes a SQLite `-wal` companion, where Antigravity writes first.
    let lastModified: Date
}
