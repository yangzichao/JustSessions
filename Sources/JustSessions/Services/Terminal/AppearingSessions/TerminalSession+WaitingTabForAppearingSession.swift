import Foundation

extension TerminalSession {
    /// Whether the tab waits for a session that it can only recognize by its appearance; see `AppearingSessionMatcher`.
    /// A tab started with its session's id waits for that one instead.
    var isWaitingForAppearingSession: Bool {
        isNewSessionAwaitingConversation && preassignedSessionID == nil
            && (host != .thisMac || provider?.linksNewSessionsByAppearance == true)
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
