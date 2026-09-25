import Foundation

extension TerminalSession {
    /// A tab started with "New session" or "Branch" that is not linked to its conversation yet.
    var isNewSessionAwaitingConversation: Bool {
        action.startsNewSession && conversation == nil
    }

    var waitingNewSessionTab: WaitingNewSessionTab {
        WaitingNewSessionTab(
            terminalID: id,
            provider: provider,
            processID: cliProcessID,
            preassignedSessionID: preassignedSessionID,
            branchedFromSessionID: branchedFromSessionID,
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
