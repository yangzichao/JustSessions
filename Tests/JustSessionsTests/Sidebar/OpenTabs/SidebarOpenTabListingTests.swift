import Foundation
import Testing

@testable import JustSessions

@MainActor
struct SidebarOpenTabListingTests {
    @Test func eachTabOfASplitAcrossProjectsListsUnderItsOwnProjectWithItsSide() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app"))
        let secondApp = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))
        let secondTools = open(store, makeTab(projectPath: "/tmp/tools"))
        store.selectTerminal(app.id)
        store.splitSelectedTerminal(with: secondTools.id)
        let split = try #require(store.shownSplit)
        try #require(split.spansProjects)
        try #require(store.tabGroupKeys == [app.projectDirectoryKey, split.groupKey, split.groupKey, tools.projectDirectoryKey])

        let groups = TerminalTabGroup.groups(of: store.terminalSessions, projectDirectoryKey: \.projectDirectoryKey)

        #expect(groups.map(\.projectDirectoryKey) == [app.projectDirectoryKey, tools.projectDirectoryKey])
        #expect(groups.map { $0.tabs.map(\.id) } == [[secondApp.id, app.id], [secondTools.id, tools.id]])
        #expect(store.tabProjectKeysInOrder == [app.projectDirectoryKey, tools.projectDirectoryKey])
        #expect(splitSide(of: app, in: store) == .left)
        #expect(splitSide(of: secondTools, in: store) == .right)
        #expect(splitSide(of: secondApp, in: store) == nil)
        #expect(splitSide(of: tools, in: store) == nil)
    }

    @Test func aProjectWhoseOnlyTabIsInASplitAcrossProjectsStillHeadsItsOwnGroup() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))
        let docs = open(store, makeTab(projectPath: "/tmp/docs"))
        store.selectTerminal(app.id)
        store.splitSelectedTerminal(with: docs.id)
        try #require(store.shownSplit?.spansProjects == true)

        let groups = TerminalTabGroup.groups(of: store.terminalSessions, projectDirectoryKey: \.projectDirectoryKey)

        #expect(groups.map(\.projectDirectoryKey) == [app, docs, tools].map(\.projectDirectoryKey))
        #expect(groups.map { $0.tabs.map(\.id) } == [[app.id], [docs.id], [tools.id]])
        #expect(
            Set(TabGroupPalette.colorsByProjectKey(store.tabProjectKeysInOrder).keys) == Set([app, docs, tools].map(\.projectDirectoryKey)))
    }

    @Test func aSplitOfOneProjectsTabsListsBothUnderThatProjectWithTheirSides() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app"))
        let secondApp = open(store, makeTab(projectPath: "/tmp/app"))
        store.selectTerminal(secondApp.id)
        store.splitSelectedTerminal(with: app.id)

        let groups = TerminalTabGroup.groups(of: store.terminalSessions, projectDirectoryKey: \.projectDirectoryKey)

        #expect(groups.map { $0.tabs.map(\.id) } == [[app.id, secondApp.id]])
        #expect(splitSide(of: app, in: store) == .left)
        #expect(splitSide(of: secondApp, in: store) == .right)
    }

    private func splitSide(of tab: TerminalSession, in store: ConversationStore) -> TerminalSplit.Side? {
        store.split(containing: tab.id).flatMap { store.sides(of: $0)?.side(of: tab.id) }
    }

    private func makeStore() throws -> (ConversationStore, () -> Void) {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        return (
            store,
            {
                store.closeAllTerminals()
                isolatedUserDefaults.removeSuite()
            }
        )
    }

    private func open(_ store: ConversationStore, _ tab: TerminalSession) -> TerminalSession {
        store.openTerminal(tab)
        return tab
    }

    private func makeTab(projectPath: String) -> TerminalSession {
        TerminalSession(
            engine: .swiftTerm,
            conversation: nil,
            provider: .claude,
            projectPath: projectPath,
            action: .resume,
            displayTitle: "Tab in \(projectPath)",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: projectPath, environment: [])
        )
    }
}
