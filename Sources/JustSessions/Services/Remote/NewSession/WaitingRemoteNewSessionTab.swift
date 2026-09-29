import Foundation

/// A "New session" or "Branch" tab on a remote host, copied out of its `TerminalSession` for matching.
struct WaitingRemoteNewSessionTab: Equatable {
    let terminalID: UUID
    let host: String
    let provider: ConversationProvider
    let projectPath: String
    let launchedAt: Date
    let sessionIDsKnownAtLaunch: Set<String>
}
