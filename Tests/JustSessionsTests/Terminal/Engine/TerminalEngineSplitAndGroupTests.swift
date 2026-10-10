import Foundation
import Testing
@testable import JustSessions

/// Splitting and grouping only arrange tabs: each tab keeps its own terminal, drawn by the engine it opened with, so
/// a Ghostty tab and a SwiftTerm tab can share a split or a group.
@MainActor
struct TerminalEngineSplitAndGroupTests {
    /// `engine` draws the first tab; the second opens after switching to the other engine.
    @Test(arguments: TerminalEngine.allCases)
    func joiningTabsIntoASplitKeepsEachTabsTerminalAndEngine(_ engine: TerminalEngine) throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: engine)
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        let otherProject = sandbox.root.appendingPathComponent("other project")
        try FileManager.default.createDirectory(at: otherProject, withIntermediateDirectories: true)
        store.openPlainTerminal(in: sandbox.projectLocation)
        sandbox.engineStore.setEngine(engine.otherEngine)
        store.openPlainTerminal(in: ProjectLocation(host: .thisMac, path: otherProject.path))
        let tabs = TabTerminals(store)
        try #require(tabs.engines == [engine, engine.otherEngine])
        let (first, second) = (store.terminalSessions[0], store.terminalSessions[1])

        // The tab from the other project joins the selected tab's split, and its group.
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        let split = try #require(store.shownSplit)
        #expect(store.tabGroupKey(of: second) == store.tabGroupKey(of: first))
        tabs.expectKept(in: store)

        store.reverseSplit(split.id)
        tabs.expectKept(in: store)

        store.separateSplit(split.id)
        #expect(store.terminalSplits.isEmpty)
        tabs.expectKept(in: store)
    }

    /// `engine` draws the first tab of each project; the second tab of the first project opens after switching to the
    /// other engine, and joins its project's group.
    @Test(arguments: TerminalEngine.allCases)
    func groupingTabsKeepsEachTabsTerminalAndEngine(_ engine: TerminalEngine) throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: engine)
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        let otherProject = sandbox.root.appendingPathComponent("other project")
        try FileManager.default.createDirectory(at: otherProject, withIntermediateDirectories: true)
        let otherLocation = ProjectLocation(host: .thisMac, path: otherProject.path)
        store.openPlainTerminal(in: sandbox.projectLocation)
        store.openPlainTerminal(in: otherLocation)
        sandbox.engineStore.setEngine(engine.otherEngine)
        store.openPlainTerminal(in: sandbox.projectLocation)
        let tabs = TabTerminals(store)
        // The new tab joined its project's tabs, before the other project's.
        try #require(tabs.engines == [engine, engine.otherEngine, engine])
        let projectGroupKey = sandbox.projectLocation.key
        #expect(store.tabGroupKeys == [projectGroupKey, projectGroupKey, otherLocation.key])
        tabs.expectKept(in: store)

        store.moveTabGroup(otherLocation.key, toPlace: 0)
        #expect(store.tabGroupKeys == [otherLocation.key, projectGroupKey, projectGroupKey])
        tabs.expectKept(in: store)

        let movedTab = store.terminalSessions[2]
        store.moveTab(movedTab.id, toPlaceInGroup: 0)
        #expect(store.terminalSessions[1].id == movedTab.id)
        tabs.expectKept(in: store)
    }
}

/// Each open tab's terminal view and engine, by tab, to compare after the tabs are arranged.
@MainActor
private struct TabTerminals {
    private let terminalsByTabID: [UUID: (view: any TabTerminalView, engine: TerminalEngine)]
    /// In tab bar order when recorded.
    let engines: [TerminalEngine]

    init(_ store: ConversationStore) {
        terminalsByTabID = Dictionary(uniqueKeysWithValues: store.terminalSessions.map { ($0.id, ($0.terminalView, $0.engine)) })
        engines = store.terminalSessions.map(\.engine)
    }

    func expectKept(in store: ConversationStore, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(Set(store.terminalSessions.map(\.id)) == Set(terminalsByTabID.keys), sourceLocation: sourceLocation)
        for tab in store.terminalSessions {
            guard let recorded = terminalsByTabID[tab.id] else { continue }
            #expect(tab.terminalView === recorded.view, sourceLocation: sourceLocation)
            #expect(tab.engine == recorded.engine, sourceLocation: sourceLocation)
            #expect(recorded.engine.draws(tab.terminalView), sourceLocation: sourceLocation)
        }
    }
}
