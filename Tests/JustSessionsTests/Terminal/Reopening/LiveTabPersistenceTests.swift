import Foundation
import Testing
@testable import JustSessions

@MainActor
struct LiveTabPersistenceTests {
    @Test func reopeningWithoutANormalQuitUsesTheLatestOpenSelectedAndClosedTabs() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        store.reopenTabsFromLastQuit(from: OpenTabPersistence(), isEnabled: true)
        let first = sandbox.conversation(title: "First")
        let second = sandbox.conversation(title: "Second")
        store.replaceConversations(on: .thisMac, with: [first, second])
        store.launch(first, action: .resume)
        store.launch(second, action: .resume)
        let firstID = try #require(store.terminalSessions.first?.id)
        store.selectTerminal(firstID)
        #expect(savedTabs(in: sandbox) == [.session(first, wasSelected: true), .session(second)])

        store.closeTerminal(try #require(store.terminalSessions.last?.id))
        #expect(savedTabs(in: sandbox) == [.session(first, wasSelected: true)])
        // A new launch reads the snapshot without any save-at-quit callback from the previous process.
        let restarted = sandbox.makeStore()
        defer { restarted.closeAllTerminals() }
        restarted.reopenTabsFromLastQuit(from: OpenTabPersistence(), isEnabled: true)
        restarted.replaceConversations(on: .thisMac, with: [first, second])
        #expect(restarted.terminalSessions.map { $0.conversation?.id } == [first.id])
        #expect(restarted.selectedTerminal?.conversation?.id == first.id)
        restarted.closeTerminal(try #require(restarted.terminalSessions.first?.id))
        #expect(savedTabs(in: sandbox).isEmpty)
    }

    @Test func normalTerminationAndViewDisappearanceDoNotSaveTheTeardownAsAnEmptyWorkspace() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        store.reopenTabsFromLastQuit(from: OpenTabPersistence(), isEnabled: true)
        store.openPlainTerminal(in: sandbox.projectLocation)
        let snapshot = savedTabs(in: sandbox)
        #expect(snapshot.count == 1)

        store.prepareTabsForTermination()
        store.closeWorkspace()
        store.reopenWaitingTabs(on: .thisMac)
        #expect(store.terminalSessions.isEmpty)
        #expect(savedTabs(in: sandbox) == snapshot)
    }

    @Test func anEmptySecondWindowAndRepeatedUpdatesCannotEraseAnotherWindowsTabs() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let persistence = OpenTabPersistence()
        let firstWindow = sandbox.makeStore()
        let secondWindow = sandbox.makeStore()
        defer { firstWindow.closeAllTerminals(); secondWindow.closeAllTerminals() }
        firstWindow.reopenTabsFromLastQuit(from: persistence, isEnabled: true)
        firstWindow.openPlainTerminal(in: sandbox.projectLocation)
        secondWindow.reopenTabsFromLastQuit(from: persistence, isEnabled: true)
        #expect(savedTabs(in: sandbox).count == 1)

        secondWindow.openPlainTerminal(in: sandbox.projectLocation)
        firstWindow.persistOpenTabs()
        #expect(savedTabs(in: sandbox).count == 2)
        firstWindow.closeWorkspace()
        #expect(savedTabs(in: sandbox).count == 1)
        secondWindow.prepareTabsForTermination()
        #expect(savedTabs(in: sandbox).count == 1)
    }

    @Test func closingTheLastWindowKeepsItsTabsForTheNextWindowToReopen() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let persistence = OpenTabPersistence()
        let closedWindow = sandbox.makeStore()
        closedWindow.reopenTabsFromLastQuit(from: persistence, isEnabled: true)
        closedWindow.openPlainTerminal(in: sandbox.projectLocation)
        let snapshot = savedTabs(in: sandbox)
        #expect(snapshot.count == 1)

        closedWindow.closeWorkspace()
        #expect(closedWindow.terminalSessions.isEmpty)
        #expect(savedTabs(in: sandbox) == snapshot)

        // Clicking the Dock icon opens a new window in the same launch.
        let reopenedWindow = sandbox.makeStore()
        defer { reopenedWindow.closeAllTerminals() }
        reopenedWindow.reopenTabsFromLastQuit(from: persistence, isEnabled: true)
        #expect(reopenedWindow.terminalSessions.count == 1)
        #expect(reopenedWindow.selectedTerminal != nil)
        #expect(savedTabs(in: sandbox) == snapshot)
    }

    @Test func aPartialHostRefreshKeepsWaitingTabsAndTheirOriginalOrder() throws {
        let sandbox = try TabReopeningSandbox(remoteHosts: ["devbox"])
        defer { sandbox.tearDown() }
        let remote = sandbox.conversation(title: "Remote", host: .ssh("devbox"))
        let local = sandbox.conversation(title: "Local")
        let original: [ReopenableTerminalTab] = [.session(remote), .session(local)]
        TerminalTabsToReopen(tabs: original).save(to: sandbox.userDefaults)
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        store.reopenTabsFromLastQuit(from: OpenTabPersistence(), isEnabled: true)
        #expect(savedTabs(in: sandbox) == original)
        store.replaceConversations(on: .thisMac, with: [], discardMissingReopeningTabs: false)
        #expect(savedTabs(in: sandbox) == original)
        store.replaceConversations(on: .thisMac, with: [local])
        #expect(savedTabs(in: sandbox) == original)
        #expect(store.pendingTabReopening.waitingTabs.count == 1)

        let restarted = sandbox.makeStore()
        defer { restarted.closeAllTerminals() }
        restarted.reopenTabsFromLastQuit(from: OpenTabPersistence(), isEnabled: true)
        restarted.replaceConversations(on: .ssh("devbox"), with: [remote])
        restarted.replaceConversations(on: .thisMac, with: [local])
        #expect(restarted.terminalSessions.map { $0.conversation?.id } == [remote.id, local.id])
    }

    @Test func linkingANewSessionImmediatelyMakesItsTabRecoverable() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        store.reopenTabsFromLastQuit(from: OpenTabPersistence(), isEnabled: true)
        let conversation = sandbox.conversation()
        store.replaceConversations(on: .thisMac, with: [conversation])
        let tab = TerminalSession(
            engine: .swiftTerm,
            conversation: nil, provider: .claude, projectPath: sandbox.project.path,
            action: .new, displayTitle: "New session",
            command: NativeCLICommand(executablePath: "/bin/sh", arguments: [], workingDirectory: sandbox.project.path, environment: [])
        )
        store.openTerminal(tab)
        #expect(savedTabs(in: sandbox).isEmpty)
        #expect(store.linkWaitingNewSessionTab(tab, toSessionID: conversation.sessionID))
        #expect(savedTabs(in: sandbox) == [.session(conversation, wasSelected: true)])
    }

    @Test func aFailedAdapterDoesNotBlockOtherTabsOnTheSameHost() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let found = sandbox.conversation(title: "Found")
        let missing = sandbox.conversation(title: "Not loaded")
        let original: [ReopenableTerminalTab] = [.session(missing), .session(found)]
        TerminalTabsToReopen(tabs: original).save(to: sandbox.userDefaults)
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        store.reopenTabsFromLastQuit(from: OpenTabPersistence(), isEnabled: true)
        store.replaceConversations(on: .thisMac, with: [found], discardMissingReopeningTabs: false)
        #expect(store.terminalSessions.map { $0.conversation?.id } == [found.id])
        #expect(savedTabs(in: sandbox) == original)
        store.replaceConversations(on: .thisMac, with: [found, missing])
        #expect(store.terminalSessions.map { $0.conversation?.id } == [missing.id, found.id])
    }

    @Test func anUnavailableCLIDoesNotEraseTheTabBeforeALaterSuccessfulRefresh() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let conversation = sandbox.conversation()
        let original: [ReopenableTerminalTab] = [.session(conversation)]
        TerminalTabsToReopen(tabs: original).save(to: sandbox.userDefaults)
        let executable = sandbox.binaryDirectory.appendingPathComponent("claude")
        try FileManager.default.removeItem(at: executable)
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        store.reopenTabsFromLastQuit(from: OpenTabPersistence(), isEnabled: true)
        store.replaceConversations(on: .thisMac, with: [conversation])
        #expect(store.terminalSessions.isEmpty)
        #expect(savedTabs(in: sandbox) == original)
        #expect(store.pendingTabReopening.waitingTabs.count == 1)

        try writeExecutableScript("#!/bin/sh\nexec sleep 30\n", to: executable)
        store.replaceConversations(on: .thisMac, with: [conversation])
        #expect(store.terminalSessions.map { $0.conversation?.id } == [conversation.id])
        #expect(store.pendingTabReopening.waitingTabs.isEmpty)
        #expect(savedTabs(in: sandbox) == original)
    }

    @Test func aLaunchCheckCannotOverwriteTheUsersRecoverySnapshot() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let original: [ReopenableTerminalTab] = [.plainTerminal(in: sandbox.projectLocation, wasSelected: true)]
        TerminalTabsToReopen(tabs: original).save(to: sandbox.userDefaults)
        let originalArguments = sandbox.userDefaults.volatileDomain(forName: UserDefaults.argumentDomain)
        defer { sandbox.userDefaults.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain) }
        sandbox.userDefaults.setVolatileDomain(
            [TabReopeningSettingsStore.userDefaultsKey: false], forName: UserDefaults.argumentDomain
        )
        let store = sandbox.makeStore()
        store.reopenTabsFromLastQuit(from: OpenTabPersistence(), isEnabled: false)
        store.prepareTabsForTermination()
        store.closeWorkspace()
        #expect(savedTabs(in: sandbox) == original)
    }

    private func savedTabs(in sandbox: TabReopeningSandbox) -> [ReopenableTerminalTab] {
        TerminalTabsToReopen.load(from: sandbox.userDefaults).tabs
    }
}
