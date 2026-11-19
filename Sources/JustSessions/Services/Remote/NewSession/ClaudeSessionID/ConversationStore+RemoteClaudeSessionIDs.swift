import Foundation

extension ConversationStore {
    func checkClaudeSessionIDFlagIfUnanswered(on host: String) {
        guard !isTearingDownWorkspace, remoteHostList.hosts.contains(host), !isDisconnected(host) else { return }
        let startCommand = customStartCommand(for: .claude, on: .ssh(host))
        guard
            installedProvidersByHost[.ssh(host)]?.contains(.claude) == true
                || CLIStartCommandLine.customCommand(startCommand) != nil
        else { return }
        if let task = remoteClaudeSessionIDFlagSupport.checkInBackgroundIfUnanswered(host: host, startCommand: startCommand) {
            remoteHostWork.keepAuxiliary(task, on: host)
        }
    }

    func linkWaitingTabsToPreassignedSessions(on host: SessionHost) {
        for session in terminalSessions where session.host == host && session.isNewSessionAwaitingConversation {
            guard let sessionID = session.preassignedSessionID else { continue }
            linkWaitingNewSessionTab(session, toSessionID: sessionID)
        }
    }
}
