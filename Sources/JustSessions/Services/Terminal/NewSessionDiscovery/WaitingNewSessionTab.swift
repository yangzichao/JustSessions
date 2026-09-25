import Foundation

/// A "New session" or "Branch" tab that has no conversation yet, copied off the main actor for the session file search.
struct WaitingNewSessionTab: Sendable {
    let terminalID: UUID
    let provider: ConversationProvider
    /// The CLI's process, or 0 while it is unknown.
    let processID: Int32
    /// The id the app asked the CLI to use (`claude --session-id`), when the CLI accepts one.
    let preassignedSessionID: String?
    /// For a Branch tab, the session it forked. The CLI reads it while starting the fork, but it is never
    /// the tab's own, so lookups skip it.
    let branchedFromSessionID: String?
    /// A process id is only evidence while the CLI runs; after it exits the id can belong to anything.
    let isRunning: Bool

    func couldBeOwnSession(_ sessionID: String) -> Bool {
        sessionID != branchedFromSessionID
    }
}

/// The session file a waiting tab's CLI is writing.
struct NewSessionFile: Sendable, Equatable {
    let sessionID: String
    let file: URL
    /// Includes a SQLite `-wal` companion, where Antigravity writes first.
    let lastModified: Date
}
