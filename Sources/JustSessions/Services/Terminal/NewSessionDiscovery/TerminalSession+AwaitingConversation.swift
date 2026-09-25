import Foundation

extension TerminalSession {
    /// A tab started with "New session" that is not linked to its conversation yet.
    var isNewSessionAwaitingConversation: Bool {
        action == .new && conversation == nil
    }

    var waitingNewSessionTab: WaitingNewSessionTab {
        WaitingNewSessionTab(
            terminalID: id,
            provider: provider,
            processID: processID,
            preassignedSessionID: preassignedSessionID,
            isRunning: !hasExited
        )
    }

    var pendingNewSession: PendingNewSession? {
        guard isNewSessionAwaitingConversation else { return nil }
        return PendingNewSession(
            terminalID: id,
            provider: provider,
            projectDirectoryKey: projectDirectoryKey,
            title: displayTitle,
            startedAt: launchedAt
        )
    }
}
