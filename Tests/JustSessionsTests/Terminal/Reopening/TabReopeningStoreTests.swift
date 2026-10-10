import Foundation
import Testing
@testable import JustSessions

/// The tabs open when the app quit open again at launch, as each host lists its sessions, in their saved order.
@MainActor
struct TabReopeningStoreTests {
    @Test func savesSessionTabsAndPlainTerminalsButNotNewSessionsWhoseSessionIsUnknown() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let conversation = sandbox.conversation()
        store.replaceConversations(on: .thisMac, with: [conversation])

        store.openTerminal(TerminalSession(
            engine: .swiftTerm,
            conversation: nil,
            provider: .claude,
            projectPath: sandbox.project.path,
            action: .new,
            displayTitle: "New session",
            command: NativeCLICommand(executablePath: "/bin/sh", arguments: [], workingDirectory: sandbox.project.path, environment: [])
        ))
        store.launch(conversation, action: .resume)
        store.openPlainTerminal(in: sandbox.projectLocation)

        #expect(store.reopenableTabs == [
            .session(conversation),
            .plainTerminal(in: sandbox.projectLocation, wasSelected: true),
        ])
    }

    @Test func reopensEachTabInItsSavedPlaceOnceItsHostListsItsSessions() throws {
        let sandbox = try TabReopeningSandbox(remoteHosts: ["devbox"])
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let first = sandbox.conversation(title: "First")
        let remote = sandbox.conversation(title: "Remote", host: .ssh("devbox"))
        let last = sandbox.conversation(title: "Last")

        store.beginReopening([
            .session(first),
            .session(remote),
            .plainTerminal(in: sandbox.projectLocation),
            .session(last, wasSelected: true),
        ])
        // A plain terminal needs no listing.
        #expect(store.terminalSessions.map(\.displayTitle) == ["Terminal · project"])

        store.replaceConversations(on: .ssh("devbox"), with: [remote])
        store.replaceConversations(on: .thisMac, with: [first, last])

        #expect(store.terminalSessions.map(\.displayTitle) == ["First", "Remote", "Terminal · project", "Last"])
        let selectedTab = try #require(store.selectedTerminal)
        #expect(selectedTab.conversation?.id == last.id)
        #expect(!selectedTab.isWaitingToBeShown)
        let otherTabs = store.terminalSessions.filter { $0.id != selectedTab.id }
        #expect(otherTabs.allSatisfy { $0.isWaitingToBeShown })
        #expect(store.terminalSessions.allSatisfy { $0.action == .resume || $0.isPlainTerminal })
        #expect(store.pendingTabReopening.waitingTabs.isEmpty)
    }

    @Test func leavesOutSessionsThatAreGoneAndHostsNoLongerListed() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let deleted = sandbox.conversation()
        let onRemovedHost = sandbox.conversation(host: .ssh("oldbox"))

        store.beginReopening([.session(deleted), .session(onRemovedHost)])
        store.replaceConversations(on: .thisMac, with: [])

        #expect(store.terminalSessions.isEmpty)
        #expect(store.pendingTabReopening.waitingTabs.isEmpty)
    }

    @Test func aCLIStillRunningInTmuxOnThisMacReattachesRightAway() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let running = sandbox.conversation(title: "Running")
        let ended = sandbox.conversation(title: "Ended")
        store.setTmuxSessionNames([TmuxSessionName.forConversation(running)], on: .thisMac)

        store.beginReopening([.session(running), .session(ended)])
        store.replaceConversations(on: .thisMac, with: [running, ended])

        let tabs = store.terminalSessions
        #expect(tabs.map(\.displayTitle) == ["Running", "Ended"])
        #expect(tabs.map(\.isWaitingToBeShown) == [false, true])
        #expect(store.selectedTerminalID == nil)
    }

    @Test func aSessionOpenedSinceLaunchKeepsItsOnlyTab() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let conversation = sandbox.conversation()
        store.replaceConversations(on: .thisMac, with: [conversation])
        store.launch(conversation, action: .resume)
        let openedTab = try #require(store.terminalSessions.first)

        store.beginReopening([.session(conversation, wasSelected: true)])
        store.replaceConversations(on: .thisMac, with: [conversation])

        #expect(store.terminalSessions.map(\.id) == [openedTab.id])
        #expect(store.selectedTerminalID == openedTab.id)
    }

    @Test func tabsStillWaitingForTheirHostAreSavedAgainAtQuit() throws {
        let sandbox = try TabReopeningSandbox(remoteHosts: ["devbox"])
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let remote = sandbox.conversation(host: .ssh("devbox"))

        store.beginReopening([.session(remote, wasSelected: true)])
        store.saveTabsForNextLaunch(to: OpenTabPersistence())

        #expect(TerminalTabsToReopen.load(from: sandbox.userDefaults).tabs == [.session(remote, wasSelected: true)])
    }

    @Test func reopensNothingWhenTurnedOffInSettings() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        TerminalTabsToReopen(tabs: [.plainTerminal(in: sandbox.projectLocation)]).save(to: sandbox.userDefaults)

        store.reopenTabsFromLastQuit(from: OpenTabPersistence(), isEnabled: false)

        #expect(store.terminalSessions.isEmpty)
        #expect(store.pendingTabReopening.waitingTabs.isEmpty)
    }

    @Test func reopensWhatTheLastQuitSaved() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        TerminalTabsToReopen(tabs: [.plainTerminal(in: sandbox.projectLocation)]).save(to: sandbox.userDefaults)

        store.reopenTabsFromLastQuit(from: OpenTabPersistence(), isEnabled: true)

        let tab = try #require(store.terminalSessions.first)
        #expect(tab.isPlainTerminal)
        #expect(tab.isWaitingToBeShown)
    }
}
