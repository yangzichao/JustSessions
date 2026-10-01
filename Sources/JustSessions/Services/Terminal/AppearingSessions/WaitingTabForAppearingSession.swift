import Foundation

/// A "New session" or "Branch" tab that is linked by appearance, copied out of its `TerminalSession` for matching.
struct WaitingTabForAppearingSession: Equatable {
    let terminalID: UUID
    let host: SessionHost
    let provider: ConversationProvider
    let projectPath: String
    let launchedAt: Date
    let sessionIDsKnownAtLaunch: Set<String>
}
