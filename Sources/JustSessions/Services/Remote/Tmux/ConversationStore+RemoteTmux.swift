import Foundation

/// What only SSH hosts need of tmux: reconnecting a tab whose connection ended. A refresh lists the host's tmux
/// sessions through `RemoteHostStatusProbe`; the rest is shared with this Mac, see `ConversationStore+Tmux`.
extension ConversationStore {
    /// Opens a fresh connection for a remote tab whose connection ended, in its place in the tab bar, drawn by the
    /// engine the tab opened with. Returns the new tab's id, or nil when the tab isn't one that can reconnect.
    @discardableResult
    func reconnectRemoteTerminal(_ id: UUID) -> UUID? {
        guard let index = terminalSessions.firstIndex(where: { $0.id == id }),
              terminalSessions[index].host != .thisMac,
              terminalSessions[index].hasExited else { return nil }
        let ended = terminalSessions[index]
        let replacement = TerminalSession(
            engine: ended.engine,
            conversation: ended.conversation,
            provider: ended.provider,
            projectPath: ended.projectPath,
            action: ended.action,
            displayTitle: ended.displayTitle,
            command: reconnectCommand(for: ended),
            branchedFromSessionID: ended.branchedFromSessionID,
            host: ended.host,
            sessionIDsKnownAtLaunch: ended.sessionIDsKnownAtLaunch,
            tmuxSessionName: ended.tmuxSessionName,
            tmuxHistory: ended.isPlainTerminal
                ? ended.tmuxSessionName.flatMap { plainTerminalTmuxHistory(sessionName: $0, on: ended.host) }
                : nil
        )
        replacement.onProcessFinished = ended.onProcessFinished
        replaceTerminal(at: index, with: replacement)
        return replacement.id
    }

    /// A new session's or branch's tab that took its session's tmux name must attach under that name, not the
    /// one it started with. Attaching ignores the CLI arguments, so resume arguments are right whenever tmux still runs it.
    /// Either way the tab connects through the host's login open now, if any.
    private func reconnectCommand(for ended: TerminalSession) -> NativeCLICommand {
        guard let host = ended.host.sshDestination else { return ended.command }
        guard let conversation = ended.conversation,
              let tmuxName = ended.tmuxSessionName,
              tmuxName == TmuxSessionName.forConversation(conversation),
              let adapter = adapter(for: conversation.provider) else {
            return RemoteCLICommandBuilder().withCurrentLogin(ended.command, host: host)
        }
        return RemoteCLICommandBuilder().command(
            host: host,
            provider: conversation.provider,
            projectPath: conversation.projectPath,
            arguments: adapter.arguments(for: conversation, action: .resume),
            tmuxSessionName: tmuxName,
            usesHostTmuxPrefix: usesTmuxPrefix(on: ended.host),
            startCommand: customStartCommand(for: conversation.provider, on: ended.host)
        )
    }
}
