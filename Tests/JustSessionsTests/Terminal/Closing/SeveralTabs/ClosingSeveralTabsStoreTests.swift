import Foundation
import Testing

@testable import JustSessions

/// Close all tabs in group…, or closing the tabs selected in Open tabs, closes only those tabs, and a tab left open
/// shows next.
@MainActor
struct ClosingSeveralTabsStoreTests {
    @MainActor
    private struct Fixture {
        let store: ConversationStore
        private let settings: IsolatedUserDefaults

        init() throws {
            settings = try IsolatedUserDefaults()
            store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        }

        @discardableResult
        func openTab(_ title: String, in projectPath: String) -> TerminalSession {
            let tab = makeTab(title, in: projectPath, startsOnceShown: false)
            store.openTerminal(tab)
            return tab
        }

        /// A tab whose CLI tmux can keep running on `host`. Nothing starts, since no terminal is shown.
        func openTmuxTab(_ title: String, on host: SessionHost) -> TerminalSession {
            let tab = TerminalSession(
                engine: .swiftTerm,
                conversation: nil,
                provider: .claude,
                projectPath: "/tmp/justsessions-tests/app",
                action: .resume,
                displayTitle: title,
                command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/tmp", environment: []),
                host: host,
                tmuxSessionName: "justsessions-closing-several-tabs-test-\(title)"
            )
            store.openTerminal(tab)
            return tab
        }

        /// A tab reopened at launch and not selected yet, which has started nothing.
        func reopenTabWaitingToBeShown(_ title: String, in projectPath: String) -> TerminalSession {
            let tab = makeTab(title, in: projectPath, startsOnceShown: true)
            store.insertReopenedTerminal(tab, at: store.terminalSessions.count, selecting: false)
            return tab
        }

        private func makeTab(_ title: String, in projectPath: String, startsOnceShown: Bool) -> TerminalSession {
            TerminalSession(
                engine: .swiftTerm,
                conversation: nil,
                provider: .claude,
                projectPath: projectPath,
                action: .resume,
                displayTitle: title,
                command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: projectPath, environment: []),
                startsOnceShown: startsOnceShown
            )
        }

        func tearDown() {
            store.closeAllTerminals()
            settings.removeSuite()
        }
    }

    @Test func closingAGroupsTabsShowsATabLeftOpen() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let store = fixture.store
        let first = fixture.openTab("First", in: "/tmp/justsessions-tests/app")
        let second = fixture.openTab("Second", in: "/tmp/justsessions-tests/app")
        let other = fixture.openTab("Other", in: "/tmp/justsessions-tests/tools")
        store.selectTerminal(first.id)

        store.closeTabs([first.id, second.id], endingTmuxSessions: true)

        #expect(store.terminalSessions.map(\.id) == [other.id])
        #expect(store.selectedTerminalID == other.id)
    }

    @Test func closingAnotherGroupsTabsKeepsTheSelectedTab() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let store = fixture.store
        let first = fixture.openTab("First", in: "/tmp/justsessions-tests/app")
        let second = fixture.openTab("Second", in: "/tmp/justsessions-tests/app")
        let other = fixture.openTab("Other", in: "/tmp/justsessions-tests/tools")
        store.selectTerminal(other.id)

        store.closeTabs([first.id, second.id], endingTmuxSessions: false)

        #expect(store.terminalSessions.map(\.id) == [other.id])
        #expect(store.selectedTerminalID == other.id)
    }

    /// Tabs selected in Open tabs can come from several groups; only they close, and the shown one closes last.
    @Test func closingTabsSelectedAcrossGroupsShowsATabLeftOpen() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let store = fixture.store
        let app = fixture.openTab("App", in: "/tmp/justsessions-tests/app")
        let secondApp = fixture.openTab("Second app", in: "/tmp/justsessions-tests/app")
        let tools = fixture.openTab("Tools", in: "/tmp/justsessions-tests/tools")
        let docs = fixture.openTab("Docs", in: "/tmp/justsessions-tests/docs")
        store.selectTerminal(tools.id)

        store.closeTabs([docs.id, tools.id, app.id], endingTmuxSessions: true)

        #expect(store.terminalSessions.map(\.id) == [secondApp.id])
        #expect(store.selectedTerminalID == secondApp.id)
    }

    /// Tabs not yet shown have started nothing, so closing them asks nothing.
    @Test func tabsNotYetShownCloseWithoutAsking() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let store = fixture.store
        let first = fixture.reopenTabWaitingToBeShown("First", in: "/tmp/justsessions-tests/app")
        let second = fixture.reopenTabWaitingToBeShown("Second", in: "/tmp/justsessions-tests/app")
        try #require(first.isWaitingToBeShown && second.isWaitingToBeShown)

        let question = store.closingQuestion(
            forTabs: [first.id, second.id], tabCloseChoices: TabCloseChoicesByHost(), plainTerminalCloseChoice: .askEachTime
        )

        #expect(question == .closeWithoutAsking)
    }

    /// Each tab's CLI in tmux reads the choice saved for its own host.
    @Test func eachTabReadsItsOwnHostsChoice() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let store = fixture.store
        let thisMacTab = fixture.openTmuxTab("Local", on: .thisMac)
        let devboxTab = fixture.openTmuxTab("Remote", on: .ssh("devbox"))
        let tabIDs = [thisMacTab.id, devboxTab.id]
        try #require(thisMacTab.closingNeed == .canKeepCLIRunning && devboxTab.closingNeed == .canKeepCLIRunning)

        let bothSaved = TabCloseChoicesByHost(thisMacChoice: .endSession, sshHostChoices: ["devbox": .keepRunning])
        #expect(
            store.closingQuestion(forTabs: tabIDs, tabCloseChoices: bothSaved, plainTerminalCloseChoice: .askEachTime)
                == .closeWithoutAsking)

        let devboxAsks = TabCloseChoicesByHost(thisMacChoice: .endSession, sshHostChoices: ["buildbox": .keepRunning])
        #expect(
            store.closingQuestion(forTabs: tabIDs, tabCloseChoices: devboxAsks, plainTerminalCloseChoice: .askEachTime)
                == .keepOrEndCLIs(alsoStopsOthers: false))
    }
}
