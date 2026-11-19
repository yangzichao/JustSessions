import Foundation

extension TerminalSession {
    var isNewSessionAwaitingConversation: Bool {
        startsNewSession && conversation == nil
    }

    var waitingNewSessionTab: WaitingNewSessionTab? {
        guard let provider else { return nil }
        return WaitingNewSessionTab(
            terminalID: id,
            provider: provider,
            processID: cliProcessID,
            preassignedSessionID: preassignedSessionID,
            branchedFromSessionID: branchedFromSessionID,
            isRunning: !hasExited
        )
    }

    var pendingNewSession: PendingNewSession? {
        guard isNewSessionAwaitingConversation, let provider else { return nil }
        return PendingNewSession(
            terminalID: id,
            provider: provider,
            projectDirectoryKey: projectDirectoryKey,
            title: displayTitle,
            startedAt: launchedAt
        )
    }
}
