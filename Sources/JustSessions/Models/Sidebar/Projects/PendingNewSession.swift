import Foundation

struct PendingNewSession: Identifiable, Equatable {
    let terminalID: UUID
    let provider: ConversationProvider
    let projectDirectoryKey: String
    let title: String
    let startedAt: Date

    var id: UUID { terminalID }
}
