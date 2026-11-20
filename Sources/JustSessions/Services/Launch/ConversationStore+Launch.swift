import Foundation

extension ConversationStore {
    func canLaunch(_ conversation: Conversation, action: ConversationAction) -> Bool {
        !conversation.isSubagent && conversation.isProjectAvailable && !isDeletionPending(for: conversation)
            && (action != .branch || conversation.provider.supportsBranchFromLauncher)
    }

    func launch(_ conversations: [Conversation], action: ConversationAction) {
        let launchable = conversations.filter { canLaunch($0, action: action) }
        let launchableHere =
            action == .resume
            ? launchable.filter { runningTerminalInAnotherWindow(for: $0) == nil }
            : launchable
        for conversation in launchableHere.isEmpty ? Array(launchable.suffix(1)) : launchableHere {
            launch(conversation, action: action)
        }
    }

    func runningTerminal(for conversation: Conversation) -> TerminalSession? {
        terminalSessions.first { $0.conversation?.id == conversation.id && !$0.hasExited }
    }

    @discardableResult
    func showRunningCLI(for conversation: Conversation) -> Bool {
        if runningTerminal(for: conversation) == nil {
            guard isRunningInTmux(conversation), canLaunch(conversation, action: .resume),
                runningTerminalInAnotherWindow(for: conversation) == nil
            else { return false }
        }
        launch(conversation, action: .resume)
        guard let shownTerminal = runningTerminal(for: conversation) else { return false }
        return shownTerminal.id == selectedTerminalID
    }

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
        if action == .resume, showRunningTerminalInAnotherWindow(for: conversation) { return }
        connectIfDisconnected(conversation.host)
        do {
            let endedTab = action == .resume ? endedTerminal(for: conversation) : nil
            guard
                let session = try makeTerminal(
                    for: conversation,
                    action: action,
                    engine: engine ?? endedTab?.engine,
                    appendedArguments: appendedArguments
                )
            else { return }
            if let endedTab {
                restartEndedTerminal(endedTab, with: session)
            } else {
                openTerminal(session)
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func endedTerminal(for conversation: Conversation) -> TerminalSession? {
        terminalSessions.first { $0.conversation?.id == conversation.id && $0.hasExited }
    }

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
                let current = self.conversation(withID: conversation.id), self.canLaunch(current, action: .resume)
            else { return }
            if let requestedTabID,
                !self.terminalSessions.contains(where: { $0.id == requestedTabID && $0.conversation?.id == conversation.id })
            {
                return
            }
            self.launch(current, action: .resume, engine: engine, appendedArguments: appendedArguments)
        }
    }

    private func restartEndedTerminal(_ endedTab: TerminalSession, with session: TerminalSession) {
        guard let keptSessionName = endedTab.tmuxSessionKeptForEndedCLI,
            let tmuxServer = commandResolver.thisMacTmuxServer()
        else {
            replaceEndedTerminal(endedTab, with: session)
            return
        }
        guard let conversationID = session.conversation?.id ?? endedTab.conversation?.id else { return }
        windowRegistry.terminalRestarts.replaceEndedTab(
            endedTab,
            of: conversationID,
            afterKillingItsTmuxSession: { tmuxServer.killSession(named: keptSessionName) },
            on: tmuxCommandQueues
        ) { [weak self] in
            guard let self, !self.isTearingDownWorkspace else { return }
            self.replaceEndedTerminal(endedTab, with: session)
        }
    }

    private func replaceEndedTerminal(_ endedTab: TerminalSession, with session: TerminalSession) {
        guard let index = terminalSessions.firstIndex(where: { $0.id == endedTab.id }),
            terminalSessions[index].conversation?.id == session.conversation?.id
        else { return }
        replaceTerminal(at: index, with: session)
        selectTerminal(session.id)
    }

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
        session.onProcessFinished = { [weak self] in self?.refresh(conversation.host) }
        return session
    }

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
        let preassignment =
            provider == .claude
            ? ClaudeSessionIDFlagSupport.shared.preassigningSessionID(to: command)
            : nil
        let promptArguments = initialPrompt.map(provider.initialPromptArguments) ?? []
        let cliCommand = (preassignment?.command ?? command).appendingArguments(
            CLIStartCommandLine.customCommand(startCommand) == nil
                ? promptArguments
                : provider.argumentsAfterCustomStartCommand(promptArguments)
        )
        let tabCommand =
            runsInTmux
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
        session.onProcessFinished = { [weak self] in self?.refreshThisMac() }
        openTerminal(session)
    }
}
