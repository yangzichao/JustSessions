import Foundation
import Testing
@testable import JustSessions

/// The app as it runs on this Mac, in a tmux sandbox: the real Claude Code, Codex, Pi, and OpenCode adapters list
/// sessions saved in the sandbox's home, tabs start their CLI in the sandbox's tmux server, Pi and OpenCode with the
/// app's reporting extension, and the CLIs are `StandInActivityCLI`s that report what they do as the real ones do.
/// Sessions are called by their title. `make()` returns nil where tmux is missing; see `ThisMacTmuxSandbox`.
@MainActor
final class UnseenTurnSandboxApp {
    let sandbox: ThisMacTmuxSandbox
    let store: ConversationStore
    let notifier = RecordingSessionNotifier()
    let liveSessionReporting: LiveSessionReporting
    private let settings: IsolatedUserDefaults
    private let claudeRegistry: ClaudeLiveSessionRegistry

    static func make() throws -> UnseenTurnSandboxApp? {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return nil }
        return try UnseenTurnSandboxApp(sandbox: sandbox)
    }

    private init(sandbox: ThisMacTmuxSandbox) throws {
        self.sandbox = sandbox
        try sandbox.writeExecutable(named: "claude", script: StandInActivityCLI.claude)
        try sandbox.writeExecutable(named: "codex", script: StandInActivityCLI.codex)
        try sandbox.writeExecutable(named: "pi", script: StandInActivityCLI.pi)
        try sandbox.writeExecutable(named: "opencode", script: StandInActivityCLI.opencode)
        try FileManager.default.createDirectory(at: sandbox.root.appendingPathComponent("turn-ends"), withIntermediateDirectories: true)
        settings = try IsolatedUserDefaults()
        claudeRegistry = ClaudeLiveSessionRegistry(configurationDirectory: sandbox.root.appendingPathComponent(".claude"))
        liveSessionReporting = LiveSessionReporting(directory: sandbox.root.appendingPathComponent("LiveSessionReporting"))
        notifier.isApplicationActive = true
        store = ConversationStore(
            adapters: [
                ClaudeAdapter(configurationDirectory: sandbox.root.appendingPathComponent(".claude")),
                CodexAdapter(codexDirectory: sandbox.root.appendingPathComponent(".codex")),
                PiAdapter(sessionsDirectory: sandbox.root.appendingPathComponent(Self.piSessionsFolder)),
                OpenCodeAdapter(databaseFile: sandbox.root.appendingPathComponent(Self.openCodeDatabaseFile)),
            ],
            commandResolver: NativeCLICommandResolver(
                searchDirectories: [sandbox.binaryDirectory.path],
                inheritedEnvironment: sandbox.environment,
                liveSessionReporting: liveSessionReporting
            ),
            userDefaults: settings.userDefaults,
            sessionNotifier: notifier,
            startsBackgroundPolling: false
        )
    }

    func tearDown() {
        store.closeAllTerminals()
        sandbox.tearDown()
        settings.removeSuite()
    }

    // MARK: Sessions

    func conversation(_ title: String) throws -> Conversation {
        try #require(listedConversation(title), "\"\(title)\" is not listed")
    }

    func listedConversation(_ title: String) -> Conversation? {
        store.conversations.first { store.title(for: $0) == title }
    }

    // MARK: Tabs

    /// Resumes the session in a new tab, which comes to the front, and waits until its CLI runs in tmux and the
    /// activity sync hears from it.
    @discardableResult
    func resume(_ title: String) async throws -> TerminalSession {
        store.launch(try conversation(title), action: .resume)
        return try await startShownTab(of: title)
    }

    /// Clicks the session's row, as the sidebar does: it shows the CLI that runs the session, reattaching a new tab
    /// to it in tmux when no tab is open.
    func clickRow(of title: String) async throws {
        try #require(store.showRunningCLI(for: try conversation(title)))
        try await startShownTab(of: title)
    }

    func tab(of title: String) throws -> TerminalSession {
        let conversationID = try conversation(title).id
        return try #require(store.terminalSessions.first { $0.conversation?.id == conversationID }, "No tab shows \"\(title)\"")
    }

    func select(_ title: String) throws {
        store.selectTerminal(try tab(of: title).id)
    }

    func closeTabKeepingItsCLIRunning(_ title: String) throws {
        store.closeTerminal(try tab(of: title).id, endingTmuxSession: false)
    }

    /// The tab view starts its terminal once shown; here nothing shows it.
    @discardableResult
    private func startShownTab(of title: String) async throws -> TerminalSession {
        let tab = try tab(of: title)
        #expect(store.selectedTerminalID == tab.id)
        tab.startIfNeeded()
        try #require(await sandbox.waitForPaneProcess(in: store, for: tab), "\(sandbox.launchDiagnostics(for: tab))")
        try #require(await followCLIs { tab.cliActivity != nil }, "The activity sync never heard from \"\(title)\": \(reportDiagnostics(of: tab))")
        return tab
    }

    // MARK: The CLIs

    /// Types a prompt in the session's tab, and waits until its CLI works on it.
    func sendPrompt(_ prompt: String, in title: String) async throws {
        let tab = try tab(of: title)
        tab.terminalView.send(txt: prompt + "\r")
        try #require(await followCLIs { tab.cliActivity == .working }, "\"\(title)\" never started its turn: \(reportDiagnostics(of: tab))")
    }

    /// The CLI finishes its turn, and the activity sync sees it.
    func finishTurn(of title: String) async throws {
        try await endTurn(of: title, as: "finished") { [self] in activity(of: title) == .idle }
    }

    /// The CLI stops in the middle of its turn for your answer, and the activity sync sees it.
    func stopForAnswer(in title: String) async throws {
        try await endTurn(of: title, as: "waiting") { [self] in
            if case .needsInput = activity(of: title) { return true }
            return false
        }
    }

    func quitCLI(in title: String) async throws {
        let tab = try tab(of: title)
        tab.terminalView.send(txt: "/exit\r")
        try #require(await sandbox.waitUntil { tab.hasExited }, "\"\(title)\"'s tab never ended")
        await followCLIsOnce()
    }

    /// The app does this every second.
    func followCLIsOnce() async {
        await store.synchronizeCLIActivity(claudeRegistry: claudeRegistry, liveSessionReporting: liveSessionReporting)
    }

    func bringAppToFront() async {
        notifier.isApplicationActive = true
        await followCLIsOnce()
    }

    private func endTurn(of title: String, as ending: String, until hasEnded: () -> Bool) async throws {
        let sessionID = try conversation(title).sessionID
        try ending.write(to: sandbox.root.appendingPathComponent("turn-ends/\(sessionID)"), atomically: true, encoding: .utf8)
        try #require(await followCLIs(until: hasEnded), "\"\(title)\"'s turn never ended as \(ending)")
    }

    /// Follows the CLIs as the app does every second, until `condition` holds or 120 seconds pass, as
    /// `expectEventually` allows for the release runner's busy start.
    private func followCLIs(until condition: () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(120)
        while clock.now < deadline {
            await followCLIsOnce()
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    /// What the session's CLI does, in its tab or in tmux with no tab open.
    private func activity(of title: String) -> CLIActivity? {
        guard let conversation = listedConversation(title) else { return nil }
        if let tab = store.runningTerminal(for: conversation), tab.isRunning { return tab.cliActivity }
        return store.detachedCLIActivities[conversation.id]
    }

    /// What the CLI reported and where it runs, to make a failed wait actionable.
    private func reportDiagnostics(of tab: TerminalSession) -> String {
        let registry = sandbox.root.appendingPathComponent(".claude/sessions")
        let entries = ((try? FileManager.default.contentsOfDirectory(atPath: registry.path)) ?? []).map { name in
            "\(name): " + ((try? String(contentsOf: registry.appendingPathComponent(name), encoding: .utf8)) ?? "unreadable")
        }
        let sessionFile = tab.conversation.flatMap { try? String(contentsOf: $0.sourceFile, encoding: .utf8) } ?? "none"
        let reports = liveSessionReporting.reportsDirectory
        let reportEntries = ((try? FileManager.default.contentsOfDirectory(atPath: reports.path)) ?? []).map { name in
            "\(name): " + ((try? String(contentsOf: reports.appendingPathComponent(name), encoding: .utf8)) ?? "unreadable")
        }
        let panes = sandbox.tmuxOutput(["list-panes", "-a", "-F", "#{pane_pid} #{pane_start_command}"])
        return "activity: \(String(describing: tab.cliActivity)); pane process: \(String(describing: tab.tmuxPaneProcessID)); "
            + "Claude Code registry: \(entries); Pi and OpenCode reports: \(reportEntries); "
            + "session file: \(sessionFile); panes: \(panes); "
            + sandbox.launchDiagnostics(for: tab)
    }

    // MARK: What the window shows

    /// The status at the end of the session's row in Projects.
    func rowStatus(of title: String) throws -> SessionRunStatus? {
        store.sessionRowStatusSource(of: try conversation(title))?.status
    }

    /// The status on the session's project row, the most pressing of its CLIs.
    func projectStatus(of title: String) throws -> SessionRunStatus? {
        store.activitySummary(forProjectDirectoryKey: try conversation(title).projectDirectoryKey).mostPressingStatus
    }

    /// The sessions Projects lists with Waiting for you on, and the count the filter menu shows beside it.
    var waitingForYou: (titles: [String], count: Int) {
        let projection = store.filteredSidebarProjection(
            providerFilter: .all, recencyFilter: .all, statusFilter: .waitingForYou, searchText: ""
        )
        return (projection.projects.flatMap(\.conversations).map(store.title(for:)), projection.waitingSessionCount)
    }

    /// The titles of the sessions that got a macOS notification, and why.
    var notifications: [(title: String, reason: SessionAttentionReason)] {
        notifier.notifications.map { ($0.sessionTitle, $0.reason) }
    }
}
