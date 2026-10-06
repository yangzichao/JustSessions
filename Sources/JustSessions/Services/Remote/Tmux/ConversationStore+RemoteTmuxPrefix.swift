import Foundation

/// Whether an SSH host's JustSessions tmux sessions use the host's own prefix keys, chosen in the host heading's
/// right-click menu; see `RemoteHostsUsingTmuxPrefix`. This Mac's sessions never do: its tmux server reads no
/// configuration, so it has no prefix of yours to use.
extension ConversationStore {
    func usesTmuxPrefix(on host: SessionHost) -> Bool {
        guard let destination = host.sshDestination else { return false }
        return remoteHostsUsingTmuxPrefix.usesTmuxPrefix(destination)
    }

    /// Saves the choice and applies it right away to every JustSessions session on the host, attached or not.
    func setUsesTmuxPrefix(
        _ usesTmuxPrefix: Bool,
        on host: String,
        remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()
    ) {
        guard remoteHostList.hosts.contains(host), self.usesTmuxPrefix(on: .ssh(host)) != usesTmuxPrefix else { return }
        remoteHostsUsingTmuxPrefix.setUsesTmuxPrefix(usesTmuxPrefix, for: host)
        remoteHostsUsingTmuxPrefix.save(to: userDefaults)
        remakeTabsWaitingToBeShown(on: .ssh(host))
        let command = RemoteTmuxCommands.setPrefixOptionsCommand(usingHostPrefix: usesTmuxPrefix)
        tmuxCommandQueues.run(on: .ssh(host)) { _ = remoteRunner.run(host, command, 30) }
    }

    /// A tab reopened from the last quit holds the command it was made with, which sets the old choice again when it
    /// attaches; it gets one made with the new choice, in its place in the tab bar.
    private func remakeTabsWaitingToBeShown(on host: SessionHost) {
        for index in terminalSessions.indices {
            let tab = terminalSessions[index]
            guard tab.host == host, tab.isWaitingToBeShown, tab.tmuxSessionName != nil,
                  let conversation = tab.conversation,
                  let replacement = try? makeTerminal(for: conversation, action: .resume, startsOnceShown: true)
            else { continue }
            replaceTerminal(at: index, with: replacement)
        }
    }
}
