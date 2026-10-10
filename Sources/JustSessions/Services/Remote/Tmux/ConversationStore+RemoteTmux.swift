import Foundation

/// What only SSH hosts need of tmux: reconnecting a tab whose connection ended. A refresh lists the host's tmux
/// sessions through `RemoteHostStatusProbe`; the rest is shared with this Mac, see `ConversationStore+Tmux`.
extension ConversationStore {
    /// Opens a fresh connection for a remote tab whose connection ended, in its place in the tab bar, drawn by the
    /// engine the tab opened with.
    func reconnectRemoteTerminal(_ id: UUID) {
        guard let index = terminalSessions.firstIndex(where: { $0.id == id }),
              terminalSessions[index].host != .thisMac,
              terminalSessions[index].hasExited else { return }
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
            tmuxSessionName: ended.tmuxSessionName
        )
        replacement.onProcessFinished = ended.onProcessFinished
        replaceTerminal(at: index, with: replacement)
    }

    /// A new session's or branch's tab that took its session's tmux name must attach under that name, not the
    /// one it started with. Attaching ignores the CLI arguments, so resume arguments are right whenever tmux still runs it.
    private func reconnectCommand(for ended: TerminalSession) -> NativeCLICommand {
        guard let host = ended.host.sshDestination,
              let conversation = ended.conversation,
              let tmuxName = ended.tmuxSessionName,
              tmuxName == TmuxSessionName.forConversation(conversation),
              let adapter = adapter(for: conversation.provider) else { return ended.command }
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
