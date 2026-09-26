import Foundation

/// Opening tabs: resuming or branching a listed session, or starting a new one in a folder.
extension ConversationStore {
    func canLaunch(_ conversation: Conversation, action: ConversationAction) -> Bool {
        conversation.isProjectAvailable && !isDeletionPending(for: conversation)
            && (action != .branch || conversation.provider.supportsBranchFromLauncher)
    }

    /// Opens one terminal tab per launchable conversation, in list order; the last one ends up selected.
    func launch(_ conversations: [Conversation], action: ConversationAction) {
        for conversation in conversations where canLaunch(conversation, action: action) {
            launch(conversation, action: action)
        }
    }

    func launch(_ conversation: Conversation, action: ConversationAction) {
        guard !isDeletionPending(for: conversation) else { return }
        guard action != .branch || conversation.provider.supportsBranchFromLauncher else { return }
        if action == .resume,
           let runningSession = terminalSessions.first(where: {
               $0.conversation?.id == conversation.id && !$0.hasExited
           }) {
            selectTerminal(runningSession.id)
            return
        }
        guard let adapter = adapter(for: conversation.provider) else { return }
        do {
            let (command, tmuxSessionName) = try launchCommand(for: conversation, action: action, adapter: adapter)
            // A branch runs a fork with a session id of its own, so its tab waits for that session like a
            // new session's tab does; see new session discovery.
            let isBranch = action == .branch
            let session = TerminalSession(
                conversation: isBranch ? nil : conversation,
                provider: conversation.provider,
                projectPath: conversation.projectPath,
                action: action,
                displayTitle: title(for: conversation),
                command: command,
                branchedFromSessionID: isBranch ? conversation.sessionID : nil,
                host: conversation.host,
                sessionIDsKnownAtLaunch: isBranch ? sessionIDsListed(on: conversation.host) : [],
                tmuxSessionName: tmuxSessionName
            )
            // A CLI that exits on its own leaves its tab open; list what it saved without waiting for the tab to close.
            session.onProcessFinished = { [weak self] in self?.refresh(conversation.host) }
            openTerminal(session)
        } catch {
            showError(error.localizedDescription)
        }
    }

    /// On this Mac, the CLI itself, in tmux when it is installed; on an SSH host, `ssh` into the tmux session the
    /// CLI runs in. Also returns the name of the tmux session, if any.
    private func launchCommand(
        for conversation: Conversation,
        action: ConversationAction,
        adapter: any ConversationAdapter
    ) throws -> (command: NativeCLICommand, tmuxSessionName: String?) {
        let tmuxSessionName = tmuxSessionName(forLaunching: conversation, action: action)
        switch conversation.host {
        case .thisMac:
            let command = try commandResolver.resolve(conversation: conversation, action: action, adapter: adapter)
            return thisMacTabCommand(running: command, tmuxSessionName: tmuxSessionName)
        case .ssh(let destination):
            let command = RemoteCLICommandBuilder().command(
                host: destination,
                provider: conversation.provider,
                projectPath: conversation.projectPath,
                arguments: adapter.arguments(for: conversation, action: action),
                tmuxSessionName: tmuxSessionName
            )
            return (command, tmuxSessionName)
        }
    }

    /// Opens a tab running a new session of the tool in the folder, on the folder's host.
    func launchNewSession(provider: ConversationProvider, in location: ProjectLocation) throws {
        switch location.host {
        case .thisMac:
            try launchNewSessionOnThisMac(provider: provider, projectPath: location.path)
        case .ssh(let destination):
            launchNewRemoteSession(provider: provider, host: destination, projectPath: location.path)
        }
    }

    /// From a project's + menu; `projectPath` is the project's key.
    func launchNewSessionFromProject(provider: ConversationProvider, projectPath: String) {
        do {
            try launchNewSession(provider: provider, in: ProjectLocation(key: projectPath))
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func launchNewSessionOnThisMac(provider: ConversationProvider, projectPath: String) throws {
        let expandedPath = (projectPath as NSString).expandingTildeInPath
        let standardizedPath = URL(fileURLWithPath: expandedPath).standardizedFileURL.path
        let command = try commandResolver.resolveNewSession(provider: provider, projectPath: standardizedPath)
        // Before tmux wraps the command: the flag check looks at the CLI's own executable.
        let preassignment = provider == .claude
            ? ClaudeSessionIDFlagSupport.shared.preassigningSessionID(to: command)
            : nil
        // A session whose id is known up front gets its own tmux name right away.
        let tabCommand = thisMacTabCommand(
            running: preassignment?.command ?? command,
            tmuxSessionName: preassignment.map { TmuxSessionName.forSession(provider: provider, sessionID: $0.sessionID) }
                ?? TmuxSessionName.unique(for: provider)
        )
        let session = TerminalSession(
            conversation: nil,
            provider: provider,
            projectPath: standardizedPath,
            action: .new,
            displayTitle: "New \(provider.rawValue) session",
            command: tabCommand.command,
            preassignedSessionID: preassignment?.sessionID,
            tmuxSessionName: tabCommand.tmuxSessionName
        )
        // A CLI that exits on its own leaves its tab open; list what it saved without waiting for the tab to close.
        session.onProcessFinished = { [weak self] in self?.refreshThisMac() }
        openTerminal(session)
    }
}
