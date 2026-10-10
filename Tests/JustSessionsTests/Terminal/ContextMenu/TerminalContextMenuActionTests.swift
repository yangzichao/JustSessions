import AppKit
import Testing
@testable import JustSessions

/// The items of a terminal's right-click menu do what the same items of its tab's menu in the tab bar do.
@MainActor
struct TerminalContextMenuActionTests {
    @Test func renameAndEndSessionAskTheWindowAsTheTabsMenuDoes() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let conversation = Conversation.fixture()
        let tab = fixture.openTab(conversation: conversation)
        let menu = fixture.menu(for: tab)

        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Rename", in: menu))
        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("End session…", in: menu))

        #expect(fixture.renamedConversations.map(\.id) == [conversation.id])
        #expect(fixture.tabsAskedToClose == [tab.id])
    }

    @Test func choosingAnotherTabOpensItInANewSplitWithThisOne() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let tab = fixture.openTab(title: "This")
        let other = fixture.openTab(title: "Other")
        fixture.store.selectTerminal(tab.id)
        let submenu = try #require(
            TerminalContextMenuFixture.item("Add tab to new split view", in: fixture.menu(for: tab)).submenu
        )

        try TerminalContextMenuFixture.choose(#require(submenu.items.first))

        #expect(fixture.store.shownSplit?.tabIDs == [tab.id, other.id])
        #expect(fixture.store.selectedTerminalID == tab.id)
    }

    @Test func arrangingTheSplitReversesClosesOrSeparatesItsViews() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let left = fixture.openTab(title: "Left")
        let right = fixture.openTab(title: "Right")
        fixture.store.selectTerminal(left.id)
        fixture.store.splitSelectedTerminal(with: right.id)
        let split = try #require(fixture.store.shownSplit)
        func arrangeItem(_ title: String) throws -> NSMenuItem {
            let submenu = try #require(TerminalContextMenuFixture.item("Arrange split view", in: fixture.menu(for: right)).submenu)
            return try TerminalContextMenuFixture.item(title, in: submenu)
        }

        try TerminalContextMenuFixture.choose(arrangeItem("Reverse views"))
        #expect(fixture.store.sides(of: split) == TerminalSplit.Sides(left: right.id, right: left.id))

        // Closing a view goes through the close request, which asks what to do with its CLI.
        try TerminalContextMenuFixture.choose(arrangeItem("Close left view"))
        #expect(fixture.tabsAskedToClose == [right.id])

        try TerminalContextMenuFixture.choose(arrangeItem("Separate views"))
        #expect(fixture.store.terminalSplits.isEmpty)
        #expect(fixture.store.terminalSessions.count == 2)
    }
}
