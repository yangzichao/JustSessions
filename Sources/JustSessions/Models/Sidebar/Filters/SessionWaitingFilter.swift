import Foundation

/// Lists every session, or only those whose CLI waits on you: stopped for your answer, or done with a turn you have
/// not seen. Only CLIs that tell what they are doing can wait on you: Claude Code, Codex, Pi, and OpenCode on this Mac.
enum SessionWaitingFilter: Hashable {
    case all
    case waitingForYou

    func includes(_ conversation: Conversation, waiting: SessionsWaitingForYou) -> Bool {
        self == .all || waiting.conversationIDs.contains(conversation.id)
    }

    func includes(_ pendingNewSession: PendingNewSession, waiting: SessionsWaitingForYou) -> Bool {
        self == .all || waiting.terminalIDs.contains(pendingNewSession.terminalID)
    }
}
