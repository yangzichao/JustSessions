import Foundation

enum SessionStatusFilter: Hashable {
    case all
    case running
    case waitingForYou

    func includes(_ conversation: Conversation, running: SessionsRunning, waiting: SessionsWaitingForYou) -> Bool {
        switch self {
        case .all: true
        case .running: running.conversationIDs.contains(conversation.id)
        case .waitingForYou: waiting.conversationIDs.contains(conversation.id)
        }
    }

    func includes(_ pendingNewSession: PendingNewSession, running: SessionsRunning, waiting: SessionsWaitingForYou) -> Bool {
        switch self {
        case .all: true
        case .running: running.terminalIDs.contains(pendingNewSession.terminalID)
        case .waitingForYou: waiting.terminalIDs.contains(pendingNewSession.terminalID)
        }
    }
}
