import Foundation

extension TerminalSession {
    /// Whether the tab waits for a session that it can only recognize by its appearance; see `AppearingSessionMatcher`.
    var isWaitingForAppearingSession: Bool {
        isNewSessionAwaitingConversation && (host != .thisMac || provider.linksNewSessionsByAppearance)
    }

    var waitingTabForAppearingSession: WaitingTabForAppearingSession {
        WaitingTabForAppearingSession(
            terminalID: id,
            host: host,
            provider: provider,
            projectPath: projectPath,
            launchedAt: launchedAt,
            sessionIDsKnownAtLaunch: sessionIDsKnownAtLaunch
        )
    }
}
