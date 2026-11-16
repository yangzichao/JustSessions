import Foundation

/// Opening tabs: resuming or branching a listed session, or starting a new one in a folder.
extension ConversationStore {
    /// A subagent's session is only read; its CLI ran it for the session that started it.
    func canLaunch(_ conversation: Conversation, action: ConversationAction) -> Bool {
        !conversation.isSubagent && conversation.isProjectAvailable && !isDeletionPending(for: conversation)
            && (action != .branch || conversation.provider.supportsBranchFromLauncher)
    }

    /// Opens one terminal tab per launchable conversation, in list order; the last one ends up selected. Resuming
    /// leaves a session whose tab is in another window there, and brings that window forward only when every
    /// session is in one.
    func launch(_ conversations: [Conversation], action: ConversationAction) {
        let launchable = conversations.filter { canLaunch($0, action: action) }
        let launchableHere = action == .resume
            ? launchable.filter { runningTerminalInAnotherWindow(for: $0) == nil }
            : launchable
        for conversation in launchableHere.isEmpty ? Array(launchable.suffix(1)) : launchableHere {
            launch(conversation, action: action)
        }
    }

    /// The open tab whose CLI still runs the session, or starts it once shown, if any.
    func runningTerminal(for conversation: Conversation) -> TerminalSession? {
        terminalSessions.first { $0.conversation?.id == conversation.id && !$0.hasExited }
    }

    /// Shows the CLI that runs the session: its open tab, or else a new tab that reattaches to it in tmux. Returns
    /// whether a tab now shows it; false when no CLI runs the session, when a tab in another window runs it, or when
    /// reattaching failed.
    @discardableResult
    func showRunningCLI(for conversation: Conversation) -> Bool {
        if runningTerminal(for: conversation) == nil {
            // Clicking a session whose tab is in another window shows its preview here, which says where the tab is.
            guard isRunningInTmux(conversation), canLaunch(conversation, action: .resume),
                  runningTerminalInAnotherWindow(for: conversation) == nil else { return false }
        }
        launch(conversation, action: .resume)
        guard let shownTerminal = runningTerminal(for: conversation) else { return false }
        return shownTerminal.id == selectedTerminalID
    }

    /// A new tab opens with `engine` rather than the engine chosen now when given, as a tab moving here from another
    /// window keeps the engine it had there. A session started again in its ended tab keeps that tab's engine.
    /// `appendedArguments` go after the action's own, as Move to's first message does; a tab that already runs the
    /// session is shown without them.
    func launch(
        _ conversation: Conversation,
        action: ConversationAction,
        engine: TerminalEngine? = nil,
        appendedArguments: [String] = []
    ) {
        guard !isDeletionPending(for: conversation) else { return }
        guard action != .branch || conversation.provider.supportsBranchFromLauncher else { return }
        if action == .resume, let runningTerminal = runningTerminal(for: conversation) {
            selectTerminal(runningTerminal.id)
            return
        }
        if action == .resume, deferResumeWhileCleaningUp(conversation, engine: engine, appendedArguments: appendedArguments) { return }
        // A session runs in one tab across the app's windows, so another window's tab comes forward instead.
        if action == .resume, showRunningTerminalInAnotherWindow(for: conversation) { return }
        connectIfDisconnected(conversation.host)
        do {
            let endedTab = action == .resume ? endedTerminal(for: conversation) : nil
            guard let session = try makeTerminal(
                for: conversation,
                action: action,
                engine: engine ?? endedTab?.engine,
                appendedArguments: appendedArguments
            ) else { return }
            if let endedTab {
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

    /// Repeated Resume selects the tab already being restarted. If that tab closed before a later Resume request,
    /// the request waits until cleanup finishes, also when it came from another window. A repeat made before Close
    /// doesn't leave a delayed request that would reopen a tab the user then closed.
    private func deferResumeWhileCleaningUp(_ conversation: Conversation, engine: TerminalEngine?, appendedArguments: [String]) -> Bool {
        let restarts = windowRegistry.terminalRestarts
        guard let ownerTabID = restarts.tabBeingCleanedUp(for: conversation.id) else { return false }
        for store in [self] + otherWindowStores {
            if let tab = store.terminalSessions.first(where: { $0.id == ownerTabID }) {
                store.selectTerminal(tab.id)
                if store !== self { windowRegistry.bringForward(store) }
                return true
            }
        }
        let lifecycle = hostLifecycleGeneration(on: conversation.host)
        let requestedTabID = endedTerminal(for: conversation)?.id
        return restarts.deferResume(for: conversation.id) { [weak self] in
            guard let self, self.isCurrentHostLifecycle(lifecycle, on: conversation.host),
                  let current = self.conversation(withID: conversation.id), self.canLaunch(current, action: .resume) else { return }
            if let requestedTabID, !self.terminalSessions.contains(where: { $0.id == requestedTabID && $0.conversation?.id == conversation.id }) { return }
            self.launch(current, action: .resume, engine: engine, appendedArguments: appendedArguments)
        }
    }

    /// Resuming a session whose tab ended starts it again in that tab, keeping its place, its split, and the
    /// selection, rather than opening a second tab of the session beside it. A tab still showing a failed CLI's tmux
    /// session first lets that session go, since the new CLI's client would otherwise attach to its dead pane.
    private func restartEndedTerminal(_ endedTab: TerminalSession, with session: TerminalSession) {
        guard let keptSessionName = endedTab.tmuxSessionKeptForEndedCLI,
              let tmuxServer = commandResolver.thisMacTmuxServer() else {
            replaceEndedTerminal(endedTab, with: session)
            return
        }
        let restarts = windowRegistry.terminalRestarts
        let conversationID = session.conversation?.id ?? endedTab.conversation?.id
        guard let conversationID, restarts.beginCleanup(for: conversationID, tabID: endedTab.id) else { return }
        endedTab.close()
        tmuxCommandQueues.run(on: .thisMac) { [weak self] in
            tmuxServer.killSession(named: keptSessionName)
            Task { @MainActor [weak self] in
                restarts.finishCleanup(for: conversationID) {
                    guard let self, !self.isTearingDownWorkspace else { return }
                    self.replaceEndedTerminal(endedTab, with: session)
                }
            }
        }
    }

    private func replaceEndedTerminal(_ endedTab: TerminalSession, with session: TerminalSession) {
        guard let index = terminalSessions.firstIndex(where: { $0.id == endedTab.id }),
              terminalSessions[index].conversation?.id == session.conversation?.id else { return }
        replaceTerminal(at: index, with: session)
        selectTerminal(session.id)
    }

    /// A tab that runs the session's CLI, not opened yet; nil when no adapter reads the session's tool. It opens with
    /// `engine`, or else the engine chosen now. `appendedArguments` go after the action's own.
    func makeTerminal(
        for conversation: Conversation,
        action: ConversationAction,
        startsOnceShown: Bool = false,
        engine: TerminalEngine? = nil,
        appendedArguments: [String] = []
    ) throws -> TerminalSession? {
        guard let adapter = adapter(for: conversation.provider) else { return nil }
        let (command, tmuxSessionName) = try launchCommand(
            for: conversation,
            action: action,
            adapter: adapter,
            appendedArguments: appendedArguments
        )
        // A branch runs a fork with a session id of its own, so its tab waits for that session like a
        // new session's tab does; see new session discovery.
        let isBranch = action == .branch
        let session = TerminalSession(
            engine: engine ?? terminalEngineStore.engine,
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
        adapter: any ConversationAdapter,
        appendedArguments: [String]
    ) throws -> (command: NativeCLICommand, tmuxSessionName: String?) {
        let tmuxSessionName = tmuxSessionName(forLaunching: conversation, action: action)
        let startCommand = customStartCommand(for: conversation.provider, on: conversation.host)
        switch conversation.host {
        case .thisMac:
            let command = try commandResolver.resolve(
                conversation: conversation, action: action, adapter: adapter, startCommand: startCommand
            ).appendingArguments(appendedArguments)
            return thisMacTabCommand(running: command, tmuxSessionName: tmuxSessionName)
        case .ssh(let destination):
            let command = RemoteCLICommandBuilder().command(
                host: destination,
                provider: conversation.provider,
                projectPath: conversation.projectPath,
                arguments: adapter.arguments(for: conversation, action: action) + appendedArguments,
                tmuxSessionName: tmuxSessionName,
                usesHostTmuxPrefix: usesTmuxPrefix(on: conversation.host),
                startCommand: startCommand
            )
            return (command, tmuxSessionName)
        }
    }

    /// Opens a tab running a new session of the tool in the folder, on the folder's host. `initialPrompt` is sent as
    /// the session's first message; with `runsInTmux` off, the CLI runs in the tab's terminal itself, so it doesn't
    /// depend on tmux working, as the agent that fixes a host's tmux needs. With `deletesSessionWhenClosed`, closing
    /// the tab deletes the session; see `SessionsDeletedWhenTabCloses`.
    func launchNewSession(
        provider: ConversationProvider,
        in location: ProjectLocation,
        initialPrompt: String? = nil,
        runsInTmux: Bool = true,
        deletesSessionWhenClosed: Bool = false
    ) throws {
        switch location.host {
        case .thisMac:
            try launchNewSessionOnThisMac(
                provider: provider,
                projectPath: location.path,
                initialPrompt: initialPrompt,
                runsInTmux: runsInTmux,
                deletesSessionWhenClosed: deletesSessionWhenClosed
            )
        case .ssh(let destination):
            launchNewRemoteSession(
                provider: provider,
                host: destination,
                projectPath: location.path,
                initialPrompt: initialPrompt,
                runsInTmux: runsInTmux,
                deletesSessionWhenClosed: deletesSessionWhenClosed
            )
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

    private func launchNewSessionOnThisMac(
        provider: ConversationProvider,
        projectPath: String,
        initialPrompt: String?,
        runsInTmux: Bool,
        deletesSessionWhenClosed: Bool
    ) throws {
        let expandedPath = (projectPath as NSString).expandingTildeInPath
        let standardizedPath = URL(fileURLWithPath: expandedPath).standardizedFileURL.path
        let startCommand = customStartCommand(for: provider, on: .thisMac)
        let command = try commandResolver.resolveNewSession(
            provider: provider,
            projectPath: standardizedPath,
            startCommand: startCommand
        )
        // Before tmux wraps the command: the flag check runs the CLI, or the start command set for it. The first
        // message goes after it, so the check's answer holds for every new session.
        let preassignment = provider == .claude
            ? ClaudeSessionIDFlagSupport.shared.preassigningSessionID(to: command)
            : nil
        let promptArguments = initialPrompt.map(provider.initialPromptArguments) ?? []
        let cliCommand = (preassignment?.command ?? command).appendingArguments(
            CLIStartCommandLine.customCommand(startCommand) == nil
                ? promptArguments
                : provider.argumentsAfterCustomStartCommand(promptArguments)
        )
        // A session whose id is known up front gets its own tmux name right away.
        let tabCommand = runsInTmux
            ? thisMacTabCommand(
                running: cliCommand,
                tmuxSessionName: preassignment.map { TmuxSessionName.forSession(provider: provider, sessionID: $0.sessionID) }
                    ?? TmuxSessionName.unique(for: provider)
            )
            : (command: cliCommand, tmuxSessionName: nil)
        let session = TerminalSession(
            engine: terminalEngineStore.engine,
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
        session.deletesSessionWhenClosed = deletesSessionWhenClosed
        // A CLI that exits on its own leaves its tab open; list what it saved without waiting for the tab to close.
        session.onProcessFinished = { [weak self] in self?.refreshThisMac() }
        openTerminal(session)
    }
}
