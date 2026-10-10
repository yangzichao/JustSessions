import AppKit
import Foundation
import Testing
@testable import JustSessions

/// A tab dragged to another window goes there as it is: the same tab, its terminal and CLI still running, with nothing
/// closed or started again, so even a CLI that does not run in tmux moves. The window it left shows another tab, and
/// both windows save their tabs for the next launch. See `TabTerminalDraggingBetweenWindowsTests` for the terminal view
/// in its new window.
@MainActor
struct TabDraggingBetweenWindowsTests {
    @Test(arguments: TerminalEngine.allCases)
    func aTabMovesToAnotherWindowAsItIs(engine: TerminalEngine) throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let first = open(sandbox.first, makeTab(engine: engine, projectPath: "/tmp/app"))
        let moving = open(sandbox.first, makeTab(engine: engine, projectPath: "/tmp/app"))
        let tools = open(sandbox.second, makeTab(engine: engine, projectPath: "/tmp/tools"))

        let tabs = try #require(sandbox.first.takeOutTabsForAnotherWindow([moving.id]))
        sandbox.second.bringInTabsFromAnotherWindow(tabs, at: .asNewGroup(0), selecting: moving.id)

        #expect(sandbox.first.terminalSessions.map(\.id) == [first.id])
        #expect(sandbox.second.terminalSessions.map(\.id) == [moving.id, tools.id])
        #expect(sandbox.second.terminalSessions.first === moving)
        #expect(!moving.hasExited)
        #expect(sandbox.first.selectedTerminalID == first.id)
        #expect(sandbox.second.selectedTerminalID == moving.id)
        #expect(sandbox.first.reopenableTabs.count == 1)
        #expect(sandbox.second.reopenableTabs.map(\.projectDirectoryKey) == [moving.projectDirectoryKey, tools.projectDirectoryKey])
        expectSplitRules(sandbox.first)
        expectSplitRules(sandbox.second)
    }

    /// As when it closes: its group's next tab shows, and the groups keep their order.
    @Test(arguments: TerminalEngine.allCases)
    func aSelectedTabLeavesItsGroupsNextTabShowing(engine: TerminalEngine) throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let moving = open(sandbox.first, makeTab(engine: engine, projectPath: "/tmp/app"))
        let next = open(sandbox.first, makeTab(engine: engine, projectPath: "/tmp/app"))
        let tools = open(sandbox.first, makeTab(engine: engine, projectPath: "/tmp/tools"))
        sandbox.first.selectTerminal(moving.id)

        _ = try #require(sandbox.first.takeOutTabsForAnotherWindow([moving.id]))

        #expect(sandbox.first.terminalSessions.map(\.id) == [next.id, tools.id])
        #expect(sandbox.first.selectedTerminalID == next.id)
    }

    @Test(arguments: TerminalEngine.allCases)
    func aTabThatWasNotSelectedLeavesTheSelectionAsItIs(engine: TerminalEngine) throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let moving = open(sandbox.first, makeTab(engine: engine, projectPath: "/tmp/app"))
        let selected = open(sandbox.first, makeTab(engine: engine, projectPath: "/tmp/app"))

        _ = try #require(sandbox.first.takeOutTabsForAnotherWindow([moving.id]))

        #expect(sandbox.first.selectedTerminalID == selected.id)
    }

    @Test(arguments: TerminalEngine.allCases)
    func aWindowsLastTabLeavesItWithNoneSelected(engine: TerminalEngine) throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let moving = open(sandbox.first, makeTab(engine: engine, projectPath: "/tmp/app"))

        let tabs = try #require(sandbox.first.takeOutTabsForAnotherWindow([moving.id]))
        sandbox.second.bringInTabsFromAnotherWindow(tabs, at: .asNewGroup(0), selecting: moving.id)

        #expect(sandbox.first.terminalSessions.isEmpty)
        #expect(sandbox.first.selectedTerminalID == nil)
        #expect(sandbox.second.terminalSessions.map(\.id) == [moving.id])
    }

    @Test(arguments: TerminalEngine.allCases)
    func aSplitMovesWholeAndShowsInTheOtherWindow(engine: TerminalEngine) throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let left = open(sandbox.first, makeTab(engine: engine, projectPath: "/tmp/app"))
        let right = open(sandbox.first, makeTab(engine: engine, projectPath: "/tmp/tools"))
        let staying = open(sandbox.first, makeTab(engine: engine, projectPath: "/tmp/app"))
        sandbox.first.selectTerminal(left.id)
        sandbox.first.splitSelectedTerminal(with: right.id)
        let split = try #require(sandbox.first.shownSplit)

        let tabs = try #require(sandbox.first.takeOutTabsForAnotherWindow([left.id, right.id]))
        sandbox.second.bringInTabsFromAnotherWindow(tabs, at: .asNewGroup(0), selecting: left.id)

        #expect(sandbox.first.terminalSessions.map(\.id) == [staying.id])
        #expect(sandbox.first.terminalSplits.isEmpty)
        #expect(sandbox.first.selectedTerminalID == staying.id)
        #expect(sandbox.second.shownSplit == split)
        #expect(sandbox.second.sides(of: split) == TerminalSplit.Sides(left: left.id, right: right.id))
        expectSplitRules(sandbox.second)
    }

    /// Its CLI ending lists what it saved in the window it is in now.
    @Test(arguments: TerminalEngine.allCases)
    func aMovedTabsCLIEndingRefreshesItsNewWindow(engine: TerminalEngine) throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let moving = open(sandbox.first, makeTab(engine: engine, projectPath: "/tmp/app"))
        moving.onProcessFinished = { [weak first = sandbox.first] in first?.refresh(.thisMac) }

        let tabs = try #require(sandbox.first.takeOutTabsForAnotherWindow([moving.id]))
        sandbox.second.bringInTabsFromAnotherWindow(tabs, at: .asNewGroup(0), selecting: moving.id)
        moving.onProcessFinished?()

        #expect(sandbox.second.hostRefreshStatuses[.thisMac] == .refreshing)
        #expect(sandbox.first.hostRefreshStatuses[.thisMac] == nil)
    }

    // MARK: - Opening a window for the tab

    @Test func noWindowOpensBeforeAWorkspaceWindowHandsOverHowTo() {
        let registry = WorkspaceWindowRegistry()

        #expect(!registry.openWindow { _, _ in })
    }

    /// The window that opens next goes to the oldest hand-over, once SwiftUI has put it on screen; a window already
    /// open takes none, even as SwiftUI puts its views in it again.
    @Test func aNewWindowGoesToTheWaitingHandOver() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let registry = sandbox.windowRegistry
        let openWindow = NSWindow()
        openWindow.isReleasedWhenClosed = false
        registry.setWindow(openWindow, for: sandbox.first)
        var openedStores: [ConversationStore] = []
        registry.openWorkspaceWindow = { openedStores.append(sandbox.second) }
        var handedOver: [(ConversationStore, NSWindow)] = []

        #expect(registry.openWindow { handedOver.append(($0, $1)) })
        #expect(openedStores.count == 1)
        registry.setWindow(nil, for: sandbox.first)
        registry.setWindow(openWindow, for: sandbox.first)
        let newWindow = NSWindow()
        newWindow.isReleasedWhenClosed = false
        registry.setWindow(newWindow, for: sandbox.second)
        #expect(handedOver.isEmpty)

        try await expectEventually { !handedOver.isEmpty }
        #expect(handedOver.count == 1)
        #expect(handedOver.first?.0 === sandbox.second)
        #expect(handedOver.first?.1 === newWindow)
        #expect(registry.window(of: sandbox.second) === newWindow)
        #expect(registry.workspace(withWindowNumber: newWindow.windowNumber)?.store === sandbox.second)
    }

    // MARK: - Helpers

    private func open(_ store: ConversationStore, _ tab: TerminalSession) -> TerminalSession {
        store.openTerminal(tab)
        return tab
    }

    /// A plain terminal that runs nothing until its view starts it.
    private func makeTab(engine: TerminalEngine, projectPath: String) -> TerminalSession {
        TerminalSession(
            engine: engine,
            conversation: nil,
            provider: nil,
            projectPath: projectPath,
            action: nil,
            displayTitle: "Terminal in \(projectPath)",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: projectPath, environment: [])
        )
    }
}
