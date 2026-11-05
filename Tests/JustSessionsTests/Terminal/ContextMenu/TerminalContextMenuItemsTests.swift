import AppKit
import Testing
@testable import JustSessions

/// A right-click in a tab's terminal offers copying, pasting, and selecting its text, then what the tab's menu in the
/// tab bar offers, in the same order and in the app's language: Rename first, then the session's other items. Pinning
/// stays in the session's sidebar row, since a tab is not its session.
@MainActor
struct TerminalContextMenuItemsTests {
    @Test(arguments: TerminalEngine.allCases)
    func aSessionsTerminalOffersItsTextThenTheTabsItems(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        fixture.openTab(engine: engine, title: "Other")
        let tab = fixture.openTab(engine: engine, conversation: .fixture())

        #expect(TerminalContextMenuFixture.titles(of: fixture.menu(for: tab)) == [
            "Copy", "Paste", "Select All", "—",
            "Rename", "—",
            "Copy conversation", "Export conversation", "Copy session ID", "Reveal session file in Finder", "—",
            "Split right", "Split down", "—",
            "Close Tab…", "Close and end session", "Close and delete session…",
        ])
    }

    /// The Finder can't show a session file that is on an SSH host.
    @Test(arguments: TerminalEngine.allCases)
    func aSessionOnAnSSHHostIsNotRevealedInFinder(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let host = SessionHost.ssh("devbox")
        let tab = fixture.openTab(engine: engine, conversation: .fixture(host: host), host: host)

        let titles = TerminalContextMenuFixture.titles(of: fixture.menu(for: tab))

        #expect(titles.contains("Copy session ID"))
        #expect(!titles.contains("Reveal session file in Finder"))
    }

    @Test(arguments: TerminalEngine.allCases)
    func aPlainTerminalOffersItsTextThenSplitAndClose(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        fixture.openTab(engine: engine, title: "Other")
        let tab = fixture.openTab(engine: engine, isPlainTerminal: true)

        #expect(TerminalContextMenuFixture.titles(of: fixture.menu(for: tab)) == [
            "Copy", "Paste", "Select All", "—",
            "Split right", "Split down", "—",
            "Close terminal…",
        ])
    }

    /// As in the tab bar, a new session's tab can't be renamed or shared until it is linked to the session its CLI
    /// writes.
    @Test(arguments: TerminalEngine.allCases)
    func aTabNotYetLinkedToItsSessionCannotBeRenamedOrShared(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let tab = fixture.openTab(engine: engine)
        let menu = fixture.menu(for: tab)

        #expect(TerminalContextMenuFixture.titles(of: menu) == [
            "Copy", "Paste", "Select All", "—",
            "Rename", "—",
            "Split right", "Split down", "—",
            "Close Tab…", "Close and end session",
        ])
        #expect(try !TerminalContextMenuFixture.item("Rename", in: menu).isEnabled)
    }

    /// Once its CLI has ended, closing the tab stops nothing and asks nothing, so there is no session to end; the
    /// session can still be deleted.
    @Test(arguments: TerminalEngine.allCases)
    func aTabWhoseCLIEndedOffersNoCloseAndEndSession(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let tab = fixture.openTab(engine: engine, conversation: .fixture())
        tab.processFinished(exitCode: 0)

        let titles = TerminalContextMenuFixture.titles(of: fixture.menu(for: tab))

        #expect(titles.suffix(2) == ["Close Tab…", "Close and delete session…"])
    }

    @Test(arguments: TerminalEngine.allCases)
    func copyNeedsASelectionWhichSelectAllMakes(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let tab = fixture.openTab(engine: engine)
        // Ghostty selects only text, which its surface holds once in a window.
        fixture.showInWindow(tab)
        feedOutput("Terminal output", to: tab.terminalView)
        let menuBefore = fixture.menu(for: tab)
        #expect(try !TerminalContextMenuFixture.item("Copy", in: menuBefore).isEnabled)

        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Select All", in: menuBefore))

        #expect(tab.terminalView.selectionActive)
        #expect(try TerminalContextMenuFixture.item("Copy", in: fixture.menu(for: tab)).isEnabled)
    }

    /// Each lists a new session of the host's CLIs and a terminal, then the window's other tabs in no split.
    @Test(arguments: TerminalEngine.allCases)
    func splitRightAndSplitDownListNewTabsThenEveryOtherTabInNoSplit(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let onlyTab = fixture.openTab(engine: engine, title: "Only")
        let aloneItem = try TerminalContextMenuFixture.item("Split right", in: fixture.menu(for: onlyTab))
        #expect(aloneItem.submenu.map(TerminalContextMenuFixture.titles(of:))?.last == "Terminal")

        fixture.openTab(engine: engine, title: "Other")
        fixture.store.selectTerminal(onlyTab.id)
        let projectName = fixture.store.projectDisplayName(forProjectPath: TerminalContextMenuFixture.projectPath)
        for title in ["Split right", "Split down"] {
            let item = try TerminalContextMenuFixture.item(title, in: fixture.menu(for: onlyTab))
            let titles = try #require(item.submenu.map(TerminalContextMenuFixture.titles(of:)))
            #expect(titles.suffix(3) == ["Terminal", "—", "Other · \(projectName)"])
        }
    }

    @Test(arguments: TerminalEngine.allCases)
    func aSplitPanesTerminalArrangesItsSplit(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let left = fixture.openTab(engine: engine, title: "Left")
        let right = fixture.openTab(engine: engine, title: "Right")
        fixture.store.selectTerminal(left.id)
        fixture.store.splitSelectedTerminal(with: right.id)

        let item = try TerminalContextMenuFixture.item("Arrange split view", in: fixture.menu(for: right))

        #expect(item.submenu.map(TerminalContextMenuFixture.titles(of:)) == [
            "Separate views", "—", "Close left view", "Close right view", "—", "Reverse views", "Stack views",
        ])
    }

    /// macOS would otherwise add AutoFill's Contact…, Passwords…, and Credit Card… when it shows the menu.
    @Test(arguments: TerminalEngine.allCases)
    func macOSAddsNoAutoFillItems(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let tab = fixture.openTab(engine: engine)

        #expect(!fixture.menu(for: tab).allowsContextMenuPlugIns)
    }

    @Test(arguments: TerminalEngine.allCases)
    func theMenuIsInTheAppLanguage(engine: TerminalEngine) throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        fixture.openTab(engine: engine, title: "Other")
        let tab = fixture.openTab(engine: engine, conversation: .fixture())

        #expect(TerminalContextMenuFixture.titles(of: fixture.menu(for: tab, language: "zh-Hans")) == [
            "复制", "粘贴", "全选", "—",
            "重命名", "—",
            "复制对话", "导出对话", "复制会话 ID", "在 Finder 中显示会话文件", "—",
            "向右拆分", "向下拆分", "—",
            "关闭标签…", "关闭并结束会话", "关闭并删除会话…",
        ])
    }
}
