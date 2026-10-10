import AppKit
import Testing
@testable import JustSessions

/// A right-click in a tab's terminal offers copying, pasting, and selecting its text, then what the tab's menu in the
/// tab bar offers after New session, in the same order and in the app's language.
@MainActor
struct TerminalContextMenuItemsTests {
    @Test func aSessionsTerminalOffersItsTextThenTheTabsItems() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        fixture.openTab(title: "Other")
        let tab = fixture.openTab(conversation: .fixture())

        #expect(TerminalContextMenuFixture.titles(of: fixture.menu(for: tab)) == [
            "Copy", "Paste", "Select All", "—",
            "Rename", "—",
            "Copy conversation", "Export conversation", "—",
            "Add tab to new split view", "—",
            "End session…",
        ])
    }

    @Test func aPlainTerminalOffersItsTextThenSplitAndClose() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        fixture.openTab(title: "Other")
        let tab = fixture.openTab(isPlainTerminal: true)

        #expect(TerminalContextMenuFixture.titles(of: fixture.menu(for: tab)) == [
            "Copy", "Paste", "Select All", "—",
            "Add tab to new split view", "—",
            "Close terminal…",
        ])
    }

    /// As in the tab bar, a new session's tab can't be renamed or shared until it is linked to the session its CLI
    /// writes.
    @Test func aTabNotYetLinkedToItsSessionCannotBeRenamedOrShared() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let tab = fixture.openTab()
        let menu = fixture.menu(for: tab)

        #expect(TerminalContextMenuFixture.titles(of: menu) == [
            "Copy", "Paste", "Select All", "—",
            "Rename",
            "Add tab to new split view", "—",
            "End session…",
        ])
        #expect(try !TerminalContextMenuFixture.item("Rename", in: menu).isEnabled)
    }

    @Test func copyNeedsASelectionWhichSelectAllMakes() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let tab = fixture.openTab()
        let menuBefore = fixture.menu(for: tab)
        #expect(try !TerminalContextMenuFixture.item("Copy", in: menuBefore).isEnabled)

        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Select All", in: menuBefore))

        #expect(tab.terminalView.selectionActive)
        #expect(try TerminalContextMenuFixture.item("Copy", in: fixture.menu(for: tab)).isEnabled)
    }

    @Test func addTabToNewSplitViewListsEveryOtherTabInNoSplit() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let onlyTab = fixture.openTab(title: "Only")
        let aloneItem = try TerminalContextMenuFixture.item("Add tab to new split view", in: fixture.menu(for: onlyTab))
        #expect(!aloneItem.isEnabled)

        fixture.openTab(title: "Other")
        fixture.store.selectTerminal(onlyTab.id)
        let item = try TerminalContextMenuFixture.item("Add tab to new split view", in: fixture.menu(for: onlyTab))

        let projectName = fixture.store.projectDisplayName(forProjectPath: TerminalContextMenuFixture.projectPath)
        #expect(item.isEnabled)
        #expect(item.submenu.map(TerminalContextMenuFixture.titles(of:)) == ["Other · \(projectName)"])
    }

    @Test func aSplitPanesTerminalArrangesItsSplit() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let left = fixture.openTab(title: "Left")
        let right = fixture.openTab(title: "Right")
        fixture.store.selectTerminal(left.id)
        fixture.store.splitSelectedTerminal(with: right.id)

        let item = try TerminalContextMenuFixture.item("Arrange split view", in: fixture.menu(for: right))

        #expect(item.submenu.map(TerminalContextMenuFixture.titles(of:)) == [
            "Separate views", "—", "Close left view", "Close right view", "—", "Reverse views",
        ])
    }

    @Test func theMenuIsInTheAppLanguage() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        fixture.openTab(title: "Other")
        let tab = fixture.openTab(conversation: .fixture())

        #expect(TerminalContextMenuFixture.titles(of: fixture.menu(for: tab, language: "zh-Hans")) == [
            "复制", "粘贴", "全选", "—",
            "重命名", "—",
            "复制对话", "导出对话", "—",
            "向新拆分视图添加标签页", "—",
            "结束会话…",
        ])
    }
}
