import Foundation

/// Remote tabs run their CLI inside tmux on the host, so a dropped connection or a closed tab leaves it running.
/// Reopening the session reattaches; ending it from here stops the tmux session too.
extension ConversationStore {
    /// Resuming uses the session's own name, so it reattaches to a CLI still running there.
    func remoteTmuxSessionName(forLaunching conversation: Conversation, action: ConversationAction) -> String {
        action == .resume
            ? RemoteTmuxSessionName.forConversation(conversation)
            : RemoteTmuxSessionName.unique(for: conversation.provider)
    }

    /// Whether the session's CLI still runs in tmux on its host, as of the host's last copy.
    func isRunningInRemoteTmux(_ conversation: Conversation) -> Bool {
        guard let host = conversation.remoteHost else { return false }
        return remoteTmuxSessionNamesByHost[host]?.contains(RemoteTmuxSessionName.forConversation(conversation)) == true
    }

    /// Lists the tmux sessions JustSessions started on the host. Runs off the main actor.
    nonisolated static func listRemoteTmuxSessions(
        host: String,
        runner: RemoteHostCommandRunner = RemoteHostCommandRunner()
    ) -> Set<String>? {
        guard let result = runner.run(host, RemoteTmuxCommands.listSessionsCommand, 30),
              result.exitStatus != RemoteHostCommandRunner.connectionFailureExitStatus else { return nil }
        return RemoteTmuxCommands.appSessionNames(inListOutput: result.output)
    }

    func setRemoteTmuxSessionNames(_ names: Set<String>, host: String) {
        guard remoteHostList.hosts.contains(host) else { return }
        remoteTmuxSessionNamesByHost[host] = names
    }

    /// A new session's tab started under a temporary name; once its session is known, it takes the session's
    /// own name, so resuming that session later reattaches to it.
    func adoptSessionTmuxName(for session: TerminalSession, runner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        guard let host = session.remoteHost,
              let currentName = session.remoteTmuxSessionName,
              let conversation = session.conversation else { return }
        let sessionName = RemoteTmuxSessionName.forConversation(conversation)
        guard currentName != sessionName else { return }
        session.remoteTmuxSessionName = sessionName
        Task.detached(priority: .utility) {
            _ = runner.run(host, RemoteTmuxCommands.renameSessionCommand(from: currentName, to: sessionName), 30)
        }
    }

    /// Stops the session's CLI on its host, whether or not a tab shows it.
    func endRemoteTmuxSession(for conversation: Conversation) {
        guard let host = conversation.remoteHost else { return }
        for session in terminalSessions where session.conversation?.id == conversation.id {
            closeTerminal(session.id)
        }
        endRemoteTmuxSession(named: RemoteTmuxSessionName.forConversation(conversation), host: host)
    }

    func endRemoteTmuxSession(named name: String, host: String, runner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        remoteTmuxSessionNamesByHost[host]?.remove(name)
        Task.detached(priority: .utility) {
            _ = runner.run(host, RemoteTmuxCommands.killSessionCommand(name), 30)
        }
    }

    /// Closes the tab. With `endingRemoteSession`, a remote tab's tmux session stops too; without it, the CLI
    /// keeps running on the host and resuming reattaches.
    func closeTerminal(_ id: UUID, endingRemoteSession: Bool) {
        guard let session = terminalSessions.first(where: { $0.id == id }) else { return }
        let remoteHost = session.remoteHost
        let tmuxName = session.remoteTmuxSessionName
        closeTerminal(id)
        if endingRemoteSession, let remoteHost, let tmuxName {
            endRemoteTmuxSession(named: tmuxName, host: remoteHost)
        } else if let remoteHost, let tmuxName {
            remoteTmuxSessionNamesByHost[remoteHost, default: []].insert(tmuxName)
        }
    }

    /// Opens a fresh connection for a remote tab whose connection ended, in its place in the tab bar.
    func reconnectRemoteTerminal(_ id: UUID) {
        guard let index = terminalSessions.firstIndex(where: { $0.id == id }),
              terminalSessions[index].remoteHost != nil,
              terminalSessions[index].hasExited else { return }
        let ended = terminalSessions[index]
        let replacement = TerminalSession(
            conversation: ended.conversation,
            provider: ended.provider,
            projectPath: ended.projectPath,
            action: ended.action,
            displayTitle: ended.displayTitle,
            command: reconnectCommand(for: ended),
            remoteHost: ended.remoteHost,
            sessionIDsKnownAtLaunch: ended.sessionIDsKnownAtLaunch,
            remoteTmuxSessionName: ended.remoteTmuxSessionName
        )
        replacement.onProcessFinished = ended.onProcessFinished
        replaceTerminal(at: index, with: replacement)
    }

    /// A new session's tab that took its session's tmux name must attach under that name, not the one it
    /// started with. Attaching ignores the CLI arguments, so resume arguments are right whenever tmux still runs it.
    private func reconnectCommand(for ended: TerminalSession) -> NativeCLICommand {
        guard let host = ended.remoteHost,
              let conversation = ended.conversation,
              let tmuxName = ended.remoteTmuxSessionName,
              tmuxName == RemoteTmuxSessionName.forConversation(conversation),
              let adapter = adapter(for: conversation.provider) else { return ended.command }
        return RemoteCLICommandBuilder().command(
            host: host,
            provider: conversation.provider,
            projectPath: conversation.projectPath,
            arguments: adapter.arguments(for: conversation, action: .resume),
            tmuxSessionName: tmuxName
        )
    }
}
