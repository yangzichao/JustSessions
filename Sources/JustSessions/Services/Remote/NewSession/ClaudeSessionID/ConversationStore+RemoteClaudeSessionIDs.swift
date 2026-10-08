import Foundation

/// New Claude Code tabs on SSH hosts that start their CLI with a session id of their own; see
/// `RemoteClaudeSessionIDFlagSupport`.
extension ConversationStore {
    /// After a refresh reached the host: checks its CLI, unless that has an answer, so the next new session there
    /// can use the flag.
    func checkClaudeSessionIDFlagIfUnanswered(on host: String) {
        guard remoteHostList.hosts.contains(host) else { return }
        let startCommand = customStartCommand(for: .claude, on: .ssh(host))
        guard installedProvidersByHost[.ssh(host)]?.contains(.claude) == true
            || CLIStartCommandLine.customCommand(startCommand) != nil else { return }
        remoteClaudeSessionIDFlagSupport.checkInBackgroundIfUnanswered(host: host, startCommand: startCommand)
    }

    /// Links waiting tabs on the host to the sessions they started with, once the host lists them. Runs before
    /// `linkWaitingTabsByAppearance`, so a tab waiting for any new session does not take one of these.
    func linkWaitingTabsToPreassignedSessions(on host: SessionHost) {
        for session in terminalSessions where session.host == host && session.isNewSessionAwaitingConversation {
            guard let sessionID = session.preassignedSessionID else { continue }
            linkWaitingNewSessionTab(session, toSessionID: sessionID)
        }
    }
}
