import Foundation

/// Lists every session, only those whose CLI runs, or only those whose CLI waits on you.
///
/// A CLI runs in a tab of any window, or in tmux with no tab open, on this Mac or on an SSH host as of the host's
/// last refresh. One that waits on you stopped for your answer, or is done with a turn you have not seen; only CLIs
/// that tell what they are doing can wait on you: Claude Code, Codex, Pi, and OpenCode on this Mac.
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
