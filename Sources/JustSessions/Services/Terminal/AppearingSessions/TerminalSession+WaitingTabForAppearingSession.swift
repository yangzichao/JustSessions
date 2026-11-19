import Foundation

extension TerminalSession {
    var isWaitingForAppearingSession: Bool {
        isNewSessionAwaitingConversation && preassignedSessionID == nil
            && (host != .thisMac || provider?.linksNewSessionsByAppearance == true)
    }

    var waitingTabForAppearingSession: WaitingTabForAppearingSession? {
        guard let provider else { return nil }
        return WaitingTabForAppearingSession(
            terminalID: id,
            host: host,
            provider: provider,
            projectPath: projectPath,
            launchedAt: launchedAt,
            sessionIDsKnownAtLaunch: sessionIDsKnownAtLaunch
        )
    }
}
