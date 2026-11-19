import Foundation

struct WaitingNewSessionTab: Sendable {
    let terminalID: UUID
    let provider: ConversationProvider
    let processID: Int32
    let preassignedSessionID: String?
    let branchedFromSessionID: String?
    /// A process id is only evidence while the CLI runs; after it exits the id can belong to anything.
    let isRunning: Bool

    func couldBeOwnSession(_ sessionID: String) -> Bool {
        sessionID != branchedFromSessionID
    }
}
