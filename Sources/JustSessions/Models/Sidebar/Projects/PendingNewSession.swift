import Foundation

/// A tab started with "New session" or "Branch" whose CLI has not written a session the sidebar can list yet.
/// The sidebar shows it under its project right away, so a new session or branch never seems to be missing.
struct PendingNewSession: Identifiable, Equatable {
    let terminalID: UUID
    let provider: ConversationProvider
    let projectDirectoryKey: String
    let title: String
    let startedAt: Date

    var id: UUID { terminalID }
}
