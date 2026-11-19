import Foundation

extension ConversationStore {
    @discardableResult
    func reconnectRemoteTerminal(_ id: UUID) -> UUID? {
        guard let index = terminalSessions.firstIndex(where: { $0.id == id }),
            terminalSessions[index].host != .thisMac,
            terminalSessions[index].hasExited
        else { return nil }
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

    private func reconnectCommand(for ended: TerminalSession) -> NativeCLICommand {
        guard let host = ended.host.sshDestination else { return ended.command }
        guard ended.hasTakenOverItsSessionsTmuxName,
            let conversation = ended.conversation,
            let tmuxName = ended.tmuxSessionName,
            let adapter = adapter(for: conversation.provider)
        else {
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

extension TerminalSession {
    fileprivate var hasTakenOverItsSessionsTmuxName: Bool {
        guard let conversation, let tmuxSessionName else { return false }
        return tmuxSessionName == TmuxSessionName.forConversation(conversation)
    }
}
