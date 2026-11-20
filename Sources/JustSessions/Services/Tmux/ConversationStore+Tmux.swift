import Foundation

extension ConversationStore {
    func tmuxSessionName(forLaunching conversation: Conversation, action: ConversationAction) -> String {
        action == .resume
            ? TmuxSessionName.forConversation(conversation)
            : TmuxSessionName.unique(for: conversation.provider)
    }

    func isRunningInTmux(_ conversation: Conversation) -> Bool {
        tmuxSessionNamesByHost[conversation.host]?.contains(TmuxSessionName.forConversation(conversation)) == true
    }

    func setTmuxSessionNames(_ names: Set<String>, on host: SessionHost) {
        guard hosts.contains(host), tmuxSessionNamesByHost[host] != names else { return }
        tmuxSessionNamesByHost[host] = names
    }

    func adoptSessionTmuxName(for session: TerminalSession, remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        guard let currentName = session.tmuxSessionName, let conversation = session.conversation else { return }
        let sessionName = TmuxSessionName.forConversation(conversation)
        guard currentName != sessionName else { return }
        session.tmuxSessionName = sessionName
        switch session.host {
        case .thisMac:
            guard let tmuxServer = commandResolver.thisMacTmuxServer() else { return }
            tmuxCommandQueues.runAfterEarlierCommands(on: .thisMac) { tmuxServer.renameSession(from: currentName, to: sessionName) }
        case .ssh(let host):
            tmuxCommandQueues.runAfterEarlierCommands(on: session.host) {
                _ = remoteRunner.run(host, RemoteTmuxCommands.renameSessionCommand(from: currentName, to: sessionName, on: host), 30)
            }
        }
    }

    func endTmuxSession(named name: String, on host: SessionHost, remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        tmuxSessionNamesByHost[host]?.remove(name)
        switch host {
        case .thisMac:
            thisMacTmuxPaneProcessIDs[name] = nil
            guard let tmuxServer = commandResolver.thisMacTmuxServer() else { return }
            tmuxCommandQueues.runAfterEarlierCommands(on: .thisMac) { tmuxServer.killSession(named: name) }
        case .ssh(let destination):
            tmuxCommandQueues.runAfterEarlierCommands(on: host) {
                _ = remoteRunner.run(destination, RemoteTmuxCommands.killSessionCommand(name, on: destination), 30)
            }
        }
    }

    func closeTerminal(_ id: UUID, endingTmuxSession: Bool) {
        guard let session = terminalSessions.first(where: { $0.id == id }) else { return }
        let host = session.host
        let tmuxName = session.tmuxSessionName
        let paneProcessID = session.tmuxPaneProcessID
        let canKeepCLIRunning = session.canKeepCLIRunningAfterClose
        closeTerminal(id)
        guard let tmuxName, !session.isPlainTerminal else { return }
        if endingTmuxSession {
            endTmuxSession(named: tmuxName, on: host)
        } else if canKeepCLIRunning {
            tmuxSessionNamesByHost[host, default: []].insert(tmuxName)
            if host == .thisMac, let paneProcessID { thisMacTmuxPaneProcessIDs[tmuxName] = paneProcessID }
        }
    }
}
