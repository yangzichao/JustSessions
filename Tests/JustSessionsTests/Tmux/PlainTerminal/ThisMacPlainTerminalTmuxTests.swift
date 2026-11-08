import Darwin
import Foundation
import Testing
@testable import JustSessions

/// A plain terminal's shell on this Mac runs in a tmux session of its tab's own: it outlives a quit, and ends with its
/// tab, with one of several windows, or with a quit that reopens no tabs. Runs the installed tmux in a sandbox server
/// with your login shell; see `ThisMacTmuxSandbox`.
@MainActor
struct ThisMacPlainTerminalTmuxTests {
    @Test func theShellRunsInATmuxSessionThatKeepsMoreHistoryAndEndsWithItsTab() async throws {
        guard let fixture = try PlainTerminalTmuxFixture.make() else { return }
        defer { fixture.tearDown() }
        let store = await fixture.makeStore()
        defer { store.closeAllTerminals() }

        let (tab, tmuxSessionName) = try await fixture.openPlainTerminal(in: store)

        #expect(TmuxSessionName.isPlainTerminal(named: tmuxSessionName))
        #expect(fixture.paneValue("#{history_limit}", of: tmuxSessionName) == "\(PlainTerminalTmuxHistoryLimit.lineCount)")
        // A CLI's session started later keeps tmux's default.
        #expect(fixture.sandbox.tmuxOutput(["show-options", "-gv", "history-limit"])
            == "\(PlainTerminalTmuxHistoryLimit.tmuxDefaultLineCount)\n")
        #expect(tab.closingNeed == .plainTerminal)
        #expect(!tab.canKeepCLIRunningAfterClose)

        store.closeTerminal(tab.id)

        #expect(await fixture.sandbox.waitUntil { fixture.sandbox.server.sessionNames().isEmpty })
    }

    @Test func theShellOutlivesAQuitAndTheReopenedTabAttachesToItRightAway() async throws {
        guard let fixture = try PlainTerminalTmuxFixture.make() else { return }
        defer { fixture.tearDown() }
        let store = await fixture.makeStore()
        let (_, tmuxSessionName) = try await fixture.openPlainTerminal(in: store)
        let shellProcessID = try #require(Int32(fixture.paneValue("#{pane_pid}", of: tmuxSessionName)))

        store.prepareTabsForTermination(reopensTabs: true)

        #expect(fixture.sandbox.server.sessionNames() == [tmuxSessionName])
        #expect(kill(shellProcessID, 0) == 0)
        let reopened = await fixture.makeStore()
        defer { reopened.closeAllTerminals() }
        let tab = try #require(reopened.terminalSessions.first)
        #expect(tab.isPlainTerminal)
        #expect(tab.tmuxSessionName == tmuxSessionName)
        #expect(!tab.isWaitingToBeShown)
        tab.startIfNeeded()
        #expect(await fixture.sandbox.waitUntil { fixture.clientCount(of: tmuxSessionName) == 1 })
        #expect(fixture.paneValue("#{pane_pid}", of: tmuxSessionName) == "\(shellProcessID)")
    }

    /// Nothing will reopen the tab, so nothing would attach to the shell again. A CLI keeps running, as its session
    /// can be resumed from the list.
    @Test func quittingWithReopenTabsOffEndsTheShellsButNotTheCLIs() async throws {
        guard let fixture = try PlainTerminalTmuxFixture.make() else { return }
        defer { fixture.tearDown() }
        try fixture.sandbox.writeExecutable(named: "codex", script: "#!/bin/sh\nexec /bin/sleep 600\n")
        let store = await fixture.makeStore()
        _ = try await fixture.openPlainTerminal(in: store)
        try store.launchNewSession(provider: .codex, in: fixture.projectLocation)
        let cliTab = try #require(store.terminalSessions.last)
        let cliTmuxSessionName = try #require(cliTab.tmuxSessionName)
        cliTab.startIfNeeded()
        try #require(await fixture.sandbox.waitUntil { fixture.sandbox.server.sessionNames().contains(cliTmuxSessionName) })

        store.prepareTabsForTermination(reopensTabs: false)

        #expect(fixture.sandbox.server.sessionNames() == [cliTmuxSessionName])
        #expect(store.terminalSessions.isEmpty)
    }

    @Test func closingOneOfSeveralWindowsEndsItsShellsAndClosingTheLastKeepsThem() async throws {
        guard let fixture = try PlainTerminalTmuxFixture.make() else { return }
        defer { fixture.tearDown() }
        let windowRegistry = WorkspaceWindowRegistry()
        let firstWindow = await fixture.makeStore(windowRegistry: windowRegistry)
        let lastWindow = await fixture.makeStore(windowRegistry: windowRegistry)
        defer { lastWindow.closeAllTerminals() }
        let (_, firstWindowsShell) = try await fixture.openPlainTerminal(in: firstWindow)
        let (_, lastWindowsShell) = try await fixture.openPlainTerminal(in: lastWindow)

        firstWindow.closeWorkspace(reopensTabs: true)
        #expect(await fixture.sandbox.waitUntil { fixture.sandbox.server.sessionNames() == [lastWindowsShell] })
        #expect(firstWindowsShell != lastWindowsShell)

        lastWindow.closeWorkspace(reopensTabs: true)
        #expect(fixture.sandbox.server.sessionNames() == [lastWindowsShell])
    }

    @Test func closingTheLastWindowWithReopenTabsOffEndsItsShells() async throws {
        guard let fixture = try PlainTerminalTmuxFixture.make() else { return }
        defer { fixture.tearDown() }
        let store = await fixture.makeStore()
        _ = try await fixture.openPlainTerminal(in: store)

        store.closeWorkspace(reopensTabs: false)

        #expect(await fixture.sandbox.waitUntil { fixture.sandbox.server.sessionNames().isEmpty })
    }
}

/// A tmux sandbox with settings of its own, so tabs saved at a quit reopen in the next store it makes.
@MainActor
private struct PlainTerminalTmuxFixture {
    let sandbox: ThisMacTmuxSandbox
    let settings: IsolatedUserDefaults

    static func make() throws -> PlainTerminalTmuxFixture? {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return nil }
        // An empty startup file keeps a login zsh from asking a new user to set one up.
        try Data().write(to: sandbox.root.appendingPathComponent(".zshrc"))
        return PlainTerminalTmuxFixture(sandbox: sandbox, settings: try IsolatedUserDefaults())
    }

    var projectLocation: ProjectLocation { ProjectLocation(host: .thisMac, path: sandbox.project.path) }

    /// A window's store after its first refresh, with the tabs the last quit saved reopened.
    func makeStore(windowRegistry: WorkspaceWindowRegistry = WorkspaceWindowRegistry()) async -> ConversationStore {
        let store = ConversationStore(
            adapters: [],
            commandResolver: sandbox.resolver,
            userDefaults: settings.userDefaults,
            windowRegistry: windowRegistry,
            startsBackgroundPolling: false
        )
        store.reopenTabsFromLastQuit(from: OpenTabPersistence(), isEnabled: true)
        store.refreshThisMac()
        _ = await sandbox.waitUntil { !store.isScanningThisMac }
        return store
    }

    func openPlainTerminal(in store: ConversationStore) async throws -> (TerminalSession, String) {
        store.openPlainTerminal(in: projectLocation)
        let tab = try #require(store.terminalSessions.last)
        let tmuxSessionName = try #require(tab.tmuxSessionName)
        tab.startIfNeeded()
        try #require(
            await sandbox.waitUntil { sandbox.server.sessionNames().contains(tmuxSessionName) },
            "\(sandbox.launchDiagnostics(for: tab))"
        )
        return (tab, tmuxSessionName)
    }

    func paneValue(_ format: String, of tmuxSessionName: String) -> String {
        sandbox.tmuxOutput(["display-message", "-p", "-t", "=\(tmuxSessionName):", format])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func clientCount(of tmuxSessionName: String) -> Int {
        sandbox.tmuxOutput(["list-clients", "-t", "=\(tmuxSessionName)"]).split(separator: "\n").count
    }

    func tearDown() {
        sandbox.tearDown()
        settings.removeSuite()
    }
}
