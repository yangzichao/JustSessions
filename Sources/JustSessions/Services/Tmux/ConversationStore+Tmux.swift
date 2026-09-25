import Foundation

/// A tab runs its CLI inside tmux when the host has it, this Mac included, so a closed tab, a dropped connection,
/// or a quit app leaves the CLI running. Reopening the session reattaches; ending it from here stops the tmux
/// session too.
extension ConversationStore {
    /// Resuming uses the session's own name, so it reattaches to a CLI still running there.
    func tmuxSessionName(forLaunching conversation: Conversation, action: ConversationAction) -> String {
        action == .resume
            ? TmuxSessionName.forConversation(conversation)
            : TmuxSessionName.unique(for: conversation.provider)
    }

    /// Whether the session's CLI still runs in tmux on its host, as of the host's last refresh.
    func isRunningInTmux(_ conversation: Conversation) -> Bool {
        tmuxSessionNamesByHost[conversation.host]?.contains(TmuxSessionName.forConversation(conversation)) == true
    }

    func setTmuxSessionNames(_ names: Set<String>, on host: SessionHost) {
        guard hosts.contains(host) else { return }
        tmuxSessionNamesByHost[host] = names
    }

    /// A new session's or branch's tab started under a temporary name; once its session is known, it takes the
    /// session's own name, so resuming that session later reattaches to it.
    func adoptSessionTmuxName(for session: TerminalSession, remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        guard let currentName = session.tmuxSessionName, let conversation = session.conversation else { return }
        let sessionName = TmuxSessionName.forConversation(conversation)
        guard currentName != sessionName else { return }
        session.tmuxSessionName = sessionName
        switch session.host {
        case .thisMac:
            guard let tmuxServer = commandResolver.thisMacTmuxServer() else { return }
            Task.detached(priority: .utility) { tmuxServer.renameSession(from: currentName, to: sessionName) }
        case .ssh(let host):
            Task.detached(priority: .utility) {
                _ = remoteRunner.run(host, RemoteTmuxCommands.renameSessionCommand(from: currentName, to: sessionName), 30)
            }
        }
    }

    /// Stops the session's CLI on its host, whether or not a tab shows it.
    func endTmuxSession(for conversation: Conversation) {
        for session in terminalSessions where session.conversation?.id == conversation.id {
            closeTerminal(session.id)
        }
        endTmuxSession(named: TmuxSessionName.forConversation(conversation), on: conversation.host)
    }

    func endTmuxSession(named name: String, on host: SessionHost, remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        tmuxSessionNamesByHost[host]?.remove(name)
        switch host {
        case .thisMac:
            guard let tmuxServer = commandResolver.thisMacTmuxServer() else { return }
            Task.detached(priority: .utility) { tmuxServer.killSession(named: name) }
        case .ssh(let destination):
            Task.detached(priority: .utility) {
                _ = remoteRunner.run(destination, RemoteTmuxCommands.killSessionCommand(name), 30)
            }
        }
    }

    /// Closes the tab. With `endingTmuxSession`, the tmux session its CLI runs in stops too; without it, the CLI
    /// keeps running and resuming reattaches.
    func closeTerminal(_ id: UUID, endingTmuxSession: Bool) {
        guard let session = terminalSessions.first(where: { $0.id == id }) else { return }
        let host = session.host
        let tmuxName = session.tmuxSessionName
        let canKeepCLIRunning = session.canKeepCLIRunningAfterClose
        closeTerminal(id)
        guard let tmuxName else { return }
        if endingTmuxSession {
            endTmuxSession(named: tmuxName, on: host)
        } else if canKeepCLIRunning {
            tmuxSessionNamesByHost[host, default: []].insert(tmuxName)
        }
    }
}
