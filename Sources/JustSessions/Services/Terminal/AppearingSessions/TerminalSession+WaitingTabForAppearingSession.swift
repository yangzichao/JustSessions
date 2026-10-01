import Foundation

extension TerminalSession {
    /// Whether the tab waits for a session that it can only recognize by its appearance; see `AppearingSessionMatcher`.
    var isWaitingForAppearingSession: Bool {
        isNewSessionAwaitingConversation && (host != .thisMac || provider?.linksNewSessionsByAppearance == true)
    }

    /// Nil for a plain terminal.
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
