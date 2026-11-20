import Foundation

struct WaitingNewSessionTab: Sendable {
    let terminalID: UUID
    let provider: ConversationProvider
    let runningCLIProcessID: Int32?
    let preassignedSessionID: String?
    let branchedFromSessionID: String?

    func couldBeOwnSession(_ sessionID: String) -> Bool {
        sessionID != branchedFromSessionID
    }
}
