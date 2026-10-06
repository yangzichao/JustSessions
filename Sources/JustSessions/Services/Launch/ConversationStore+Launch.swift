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

    /// The open tab whose CLI still runs the session, or starts it once shown, if any.
    func runningTerminal(for conversation: Conversation) -> TerminalSession? {
        terminalSessions.first { $0.conversation?.id == conversation.id && !$0.hasExited }
    }

    /// Shows the CLI that runs the session: its open tab, or else a new tab that reattaches to it in tmux. Returns
    /// whether a tab now shows it; false when no CLI runs the session or reattaching failed.
    @discardableResult
    func showRunningCLI(for conversation: Conversation) -> Bool {
        let hasRunningCLI = runningTerminal(for: conversation) != nil
            || (isRunningInTmux(conversation) && canLaunch(conversation, action: .resume))
        guard hasRunningCLI else { return false }
        launch(conversation, action: .resume)
        guard let shownTerminal = runningTerminal(for: conversation) else { return false }
        return shownTerminal.id == selectedTerminalID
    }

    func launch(_ conversation: Conversation, action: ConversationAction) {
        guard !isDeletionPending(for: conversation) else { return }
        guard action != .branch || conversation.provider.supportsBranchFromLauncher else { return }
        if action == .resume, let runningTerminal = runningTerminal(for: conversation) {
            selectTerminal(runningTerminal.id)
            return
        }
        do {
            guard let session = try makeTerminal(for: conversation, action: action) else { return }
            if action == .resume, let endedTab = endedTerminal(for: conversation) {
                restartEndedTerminal(endedTab, with: session)
            } else {
                openTerminal(session)
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    /// An open tab of the session whose CLI has ended, as one does when an SSH host's connection drops.
    private func endedTerminal(for conversation: Conversation) -> TerminalSession? {
        terminalSessions.first { $0.conversation?.id == conversation.id && $0.hasExited }
    }

    /// Resuming a session whose tab ended starts it again in that tab, keeping its place, its split, and the
    /// selection, rather than opening a second tab of the session beside it.
    private func restartEndedTerminal(_ endedTab: TerminalSession, with session: TerminalSession) {
        guard let index = terminalSessions.firstIndex(where: { $0.id == endedTab.id }) else { return }
        replaceTerminal(at: index, with: session)
        selectTerminal(session.id)
    }

    /// A tab that runs the session's CLI, not opened yet; nil when no adapter reads the session's tool.
    func makeTerminal(
        for conversation: Conversation,
        action: ConversationAction,
        startsOnceShown: Bool = false
    ) throws -> TerminalSession? {
        guard let adapter = adapter(for: conversation.provider) else { return nil }
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
            sessionIDsKnownAtLaunch: isBranch ? sessionIDsKnownAtLaunch(of: conversation.provider, on: conversation.host) : [],
            tmuxSessionName: tmuxSessionName,
            startsOnceShown: startsOnceShown
        )
        // A CLI that exits on its own leaves its tab open; list what it saved without waiting for the tab to close.
        session.onProcessFinished = { [weak self] in self?.refresh(conversation.host) }
        return session
    }

    /// On this Mac, the CLI itself, in tmux when it is installed; on an SSH host, `ssh` into the tmux session the
    /// CLI runs in. Also returns the name of the tmux session, if any.
    private func launchCommand(
        for conversation: Conversation,
        action: ConversationAction,
        adapter: any ConversationAdapter
    ) throws -> (command: NativeCLICommand, tmuxSessionName: String?) {
        let tmuxSessionName = tmuxSessionName(forLaunching: conversation, action: action)
        let startCommand = customStartCommand(for: conversation.provider, on: conversation.host)
        switch conversation.host {
        case .thisMac:
            let command = try commandResolver.resolve(
                conversation: conversation, action: action, adapter: adapter, startCommand: startCommand
            )
            return thisMacTabCommand(running: command, tmuxSessionName: tmuxSessionName)
        case .ssh(let destination):
            let command = RemoteCLICommandBuilder().command(
                host: destination,
                provider: conversation.provider,
                projectPath: conversation.projectPath,
                arguments: adapter.arguments(for: conversation, action: action),
                tmuxSessionName: tmuxSessionName,
                usesHostTmuxPrefix: usesTmuxPrefix(on: conversation.host),
                startCommand: startCommand
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
        let command = try commandResolver.resolveNewSession(
            provider: provider,
            projectPath: standardizedPath,
            startCommand: customStartCommand(for: provider, on: .thisMac)
        )
        // Before tmux wraps the command: the flag check runs the CLI, or the start command set for it.
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
            displayTitle: provider.newSessionTabTitle,
            command: tabCommand.command,
            preassignedSessionID: preassignment?.sessionID,
            sessionIDsKnownAtLaunch: sessionIDsKnownAtLaunch(of: provider, on: .thisMac),
            tmuxSessionName: tabCommand.tmuxSessionName
        )
        // A CLI that exits on its own leaves its tab open; list what it saved without waiting for the tab to close.
        session.onProcessFinished = { [weak self] in self?.refreshThisMac() }
        openTerminal(session)
    }
}
