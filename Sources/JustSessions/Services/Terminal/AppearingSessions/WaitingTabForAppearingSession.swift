import Foundation

struct WaitingTabForAppearingSession: Equatable {
    let terminalID: UUID
    let host: SessionHost
    let provider: ConversationProvider
    let projectPath: String
    let launchedAt: Date
    let sessionIDsKnownAtLaunch: Set<String>
}
