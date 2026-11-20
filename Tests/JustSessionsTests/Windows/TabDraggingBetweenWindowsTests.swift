import AppKit
import Foundation
import Testing

@testable import JustSessions

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

    @Test func aStackedSplitStaysStackedInTheOtherWindow() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let top = open(sandbox.first, makeTab(engine: .swiftTerm, projectPath: "/tmp/app"))
        let bottom = open(sandbox.first, makeTab(engine: .swiftTerm, projectPath: "/tmp/app"))
        sandbox.first.selectTerminal(top.id)
        sandbox.first.splitSelectedTerminal(with: bottom.id, on: .right, orientation: .stacked)
        let split = try #require(sandbox.first.shownSplit)

        let tabs = try #require(sandbox.first.takeOutTabsForAnotherWindow([top.id, bottom.id]))
        sandbox.second.bringInTabsFromAnotherWindow(tabs, at: .asNewGroup(0), selecting: top.id)

        #expect(sandbox.second.shownSplit == split)
        #expect(sandbox.second.orientation(ofSplitView: split.id) == .stacked)
        #expect(sandbox.second.sides(of: split) == TerminalSplit.Sides(left: top.id, right: bottom.id))
        #expect(sandbox.first.stackedSplitViewIDs.isEmpty)
    }

    @Test(arguments: TerminalEngine.allCases)
    func aWholeGroupMovesToAnotherWindowWithItsSplit(engine: TerminalEngine) throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let left = open(sandbox.first, makeTab(engine: engine, projectPath: "/tmp/app"))
        let right = open(sandbox.first, makeTab(engine: engine, projectPath: "/tmp/app"))
        let third = open(sandbox.first, makeTab(engine: engine, projectPath: "/tmp/app"))
        let staying = open(sandbox.first, makeTab(engine: engine, projectPath: "/tmp/tools"))
        let tools = open(sandbox.second, makeTab(engine: engine, projectPath: "/tmp/tools"))
        sandbox.first.selectTerminal(left.id)
        sandbox.first.splitSelectedTerminal(with: right.id)
        let split = try #require(sandbox.first.shownSplit)

        let tabs = try #require(sandbox.first.takeOutTabsForAnotherWindow([left.id, right.id, third.id]))
        sandbox.second.bringInTabsFromAnotherWindow(tabs, at: .asNewGroup(1), selecting: left.id)

        #expect(sandbox.first.terminalSessions.map(\.id) == [staying.id])
        #expect(sandbox.first.terminalSplits.isEmpty)
        #expect(sandbox.first.selectedTerminalID == staying.id)
        #expect(sandbox.second.terminalSessions.map(\.id) == [tools.id, left.id, right.id, third.id])
        #expect(sandbox.second.shownSplit == split)
        #expect(sandbox.second.sides(of: split) == TerminalSplit.Sides(left: left.id, right: right.id))
        #expect(sandbox.first.reopenableTabs.count == 1)
        #expect(sandbox.second.reopenableTabs.count == 4)
        expectSplitRules(sandbox.first)
        expectSplitRules(sandbox.second)
    }

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

    @Test func noWindowOpensBeforeAWorkspaceWindowHandsOverHowTo() {
        let registry = WorkspaceWindowRegistry()

        #expect(!registry.openWindow { _, _ in })
    }

    @Test func aNewWindowGoesToTheWaitingHandOver() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let registry = sandbox.windowRegistry
        let openWindow = NSWindow()
        openWindow.isReleasedWhenClosed = false
        registry.setWindowHandingOverItsFirstWindow(openWindow, for: sandbox.first)
        var openedStores: [ConversationStore] = []
        registry.openWorkspaceWindow = { openedStores.append(sandbox.second) }
        var handedOver: [(ConversationStore, NSWindow)] = []

        #expect(registry.openWindow { handedOver.append(($0, $1)) })
        #expect(openedStores.count == 1)
        registry.setWindowHandingOverItsFirstWindow(nil, for: sandbox.first)
        registry.setWindowHandingOverItsFirstWindow(openWindow, for: sandbox.first)
        let newWindow = NSWindow()
        newWindow.isReleasedWhenClosed = false
        newWindow.animationBehavior = .documentWindow
        registry.setWindowHandingOverItsFirstWindow(newWindow, for: sandbox.second)
        #expect(handedOver.isEmpty)
        #expect(newWindow.alphaValue == 0)
        #expect(newWindow.animationBehavior == .none)
        #expect(openWindow.alphaValue == 1)

        try await expectEventually { !handedOver.isEmpty }
        #expect(handedOver.count == 1)
        #expect(newWindow.animationBehavior == .documentWindow)
        #expect(handedOver.first?.0 === sandbox.second)
        #expect(handedOver.first?.1 === newWindow)
        #expect(registry.window(of: sandbox.second) === newWindow)
        #expect(registry.workspace(withWindowNumber: newWindow.windowNumber)?.store === sandbox.second)
    }

    private func open(_ store: ConversationStore, _ tab: TerminalSession) -> TerminalSession {
        store.openTerminal(tab)
        return tab
    }

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
