import AppKit
import Testing
@testable import JustSessions

/// The items of a terminal's right-click menu do what the same items of its tab's menu in the tab bar do.
@MainActor
struct TerminalContextMenuActionTests {
    @Test(arguments: TerminalEngine.allCases)
    func renameAndCloseTabAskTheWindowAsTheTabsMenuDoes(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let conversation = Conversation.fixture()
        let tab = fixture.openTab(engine: engine, conversation: conversation)
        let menu = fixture.menu(for: tab)

        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Rename", in: menu))
        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Close Tab…", in: menu))

        #expect(fixture.renamedConversations.map(\.id) == [conversation.id])
        #expect(fixture.tabsAskedToClose == [tab.id])
    }

    /// Close and end session closes the tab at once, without the close request's question.
    @Test(arguments: TerminalEngine.allCases)
    func closeAndEndSessionClosesTheTabWithoutAsking(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let other = fixture.openTab(engine: engine, title: "Other")
        let tab = fixture.openTab(engine: engine, conversation: .fixture())

        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Close and end session", in: fixture.menu(for: tab)))

        #expect(fixture.store.terminalSessions.map(\.id) == [other.id])
        #expect(fixture.tabsAskedToClose.isEmpty)
    }

    /// A session started with Delete the session when its tab closes offers Keep session and Close and delete session
    /// in place of the other closing items. Close and delete session asks to close the tab, as its × does, which
    /// deletes the session without asking; Keep session takes the choice back.
    @Test(arguments: TerminalEngine.allCases)
    func aTabWhoseSessionGoesWithItOffersKeepSessionAndCloseAndDelete(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let conversation = Conversation.fixture()
        let tab = fixture.openTab(engine: engine, conversation: conversation)
        fixture.store.setDeletedWhenTabCloses(true, conversationIDs: [conversation.id])
        let menu = fixture.menu(for: tab)

        #expect(TerminalContextMenuFixture.titles(of: menu).suffix(2) == ["Keep session", "Close and delete session"])
        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Close and delete session", in: menu))
        #expect(fixture.tabsAskedToClose == [tab.id])

        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Keep session", in: menu))
        #expect(!fixture.store.deletesSessionWhenClosed(tab))
        #expect(TerminalContextMenuFixture.titles(of: fixture.menu(for: tab)).suffix(3) == [
            "Close Tab…", "Close and end session", "Close and delete session…",
        ])
    }

    /// Close and delete session… asks the window to delete the tab's session, whose dialog confirms first; the tab
    /// stays open until then.
    @Test(arguments: TerminalEngine.allCases)
    func closeAndDeleteSessionAsksTheWindowToDeleteTheTabsSession(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let conversation = Conversation.fixture()
        let tab = fixture.openTab(engine: engine, conversation: conversation)

        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Close and delete session…", in: fixture.menu(for: tab)))

        #expect(fixture.conversationsAskedToDelete.map(\.id) == [conversation.id])
        #expect(fixture.store.terminalSessions.map(\.id) == [tab.id])
    }

    @Test(arguments: TerminalEngine.allCases)
    func choosingAnotherTabOpensItInANewSplitWithThisOne(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let tab = fixture.openTab(engine: engine, title: "This")
        let other = fixture.openTab(engine: engine, title: "Other")
        fixture.store.selectTerminal(tab.id)
        let submenu = try #require(
            TerminalContextMenuFixture.item("Split right", in: fixture.menu(for: tab)).submenu
        )

        try TerminalContextMenuFixture.choose(#require(submenu.items.last))

        let split = try #require(fixture.store.shownSplit)
        #expect(split.tabIDs == [tab.id, other.id])
        #expect(fixture.store.sides(of: split) == TerminalSplit.Sides(left: tab.id, right: other.id))
        #expect(fixture.store.orientation(ofSplitView: split.id) == .sideBySide)
        #expect(fixture.store.selectedTerminalID == tab.id)
    }

    @Test(arguments: TerminalEngine.allCases)
    func choosingAnotherTabInSplitDownOpensItBelowThisOne(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let other = fixture.openTab(engine: engine, title: "Other")
        let tab = fixture.openTab(engine: engine, title: "This")
        fixture.store.selectTerminal(tab.id)
        let submenu = try #require(
            TerminalContextMenuFixture.item("Split down", in: fixture.menu(for: tab)).submenu
        )

        try TerminalContextMenuFixture.choose(#require(submenu.items.last))

        let split = try #require(fixture.store.shownSplit)
        #expect(fixture.store.sides(of: split) == TerminalSplit.Sides(left: tab.id, right: other.id))
        #expect(fixture.store.orientation(ofSplitView: split.id) == .stacked)
    }

    @Test(arguments: TerminalEngine.allCases)
    func arrangingTheSplitReversesClosesOrSeparatesItsViews(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let left = fixture.openTab(engine: engine, title: "Left")
        let right = fixture.openTab(engine: engine, title: "Right")
        fixture.store.selectTerminal(left.id)
        fixture.store.splitSelectedTerminal(with: right.id)
        let split = try #require(fixture.store.shownSplit)
        func arrangeItem(_ title: String) throws -> NSMenuItem {
            let submenu = try #require(TerminalContextMenuFixture.item("Arrange split view", in: fixture.menu(for: right)).submenu)
            return try TerminalContextMenuFixture.item(title, in: submenu)
        }

        try TerminalContextMenuFixture.choose(arrangeItem("Reverse views"))
        #expect(fixture.store.sides(of: split) == TerminalSplit.Sides(left: right.id, right: left.id))

        try TerminalContextMenuFixture.choose(arrangeItem("Stack views"))
        #expect(fixture.store.orientation(ofSplitView: split.id) == .stacked)
        #expect(try TerminalContextMenuFixture.titles(of: #require(
            TerminalContextMenuFixture.item("Arrange split view", in: fixture.menu(for: right)).submenu
        )).contains("Close top view"))
        try TerminalContextMenuFixture.choose(arrangeItem("Place views side by side"))
        #expect(fixture.store.orientation(ofSplitView: split.id) == .sideBySide)

        // Closing a view goes through the close request, which asks what to do with its CLI.
        try TerminalContextMenuFixture.choose(arrangeItem("Close left view"))
        #expect(fixture.tabsAskedToClose == [right.id])

        try TerminalContextMenuFixture.choose(arrangeItem("Separate views"))
        #expect(fixture.store.terminalSplits.isEmpty)
        #expect(fixture.store.terminalSessions.count == 2)
    }
}
