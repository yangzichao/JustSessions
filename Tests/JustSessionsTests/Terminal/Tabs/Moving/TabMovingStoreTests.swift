import Foundation
import Testing
@testable import JustSessions

/// Dropping a dragged tab or group reorders the store's tabs, keeps the selection and the shown split, and saves the
/// new order for the next launch.
@MainActor
struct TabMovingStoreTests {
    @Test func droppingATabReordersItsGroupAndKeepsTheSelection() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab(projectPath: "/tmp/app"))
        let second = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))
        store.selectTerminal(second.id)

        store.moveTab(first.id, toPlaceInGroup: 1)

        #expect(store.terminalSessions.map(\.id) == [second.id, first.id, tools.id])
        #expect(store.selectedTerminalID == second.id)
        expectSplitRules(store)
    }

    @Test func droppingASplitTabKeepsTheSplitShowing() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab(projectPath: "/tmp/app"))
        let second = open(store, makeTab(projectPath: "/tmp/app"))
        let third = open(store, makeTab(projectPath: "/tmp/app"))
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        let split = try #require(store.shownSplit)

        store.moveTab(second.id, toPlaceInGroup: 1)

        #expect(store.terminalSessions.map(\.id) == [third.id, first.id, second.id])
        #expect(store.shownSplit == split)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: first.id, right: second.id))
        expectSplitRules(store)
    }

    @Test func droppingAGroupSavesTheNewOrderForTheNextLaunch() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))

        store.moveTabGroup(tools.projectDirectoryKey, toPlace: 0)

        #expect(store.terminalSessions.map(\.id) == [tools.id, app.id])
        #expect(store.reopenableTabs.map(\.projectDirectoryKey) == [tools.projectDirectoryKey, app.projectDirectoryKey])
        expectSplitRules(store)
    }

    // MARK: - Helpers

    private func makeStore() throws -> (ConversationStore, () -> Void) {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        return (store, {
            store.closeAllTerminals()
            isolatedUserDefaults.removeSuite()
        })
    }

    private func open(_ store: ConversationStore, _ tab: TerminalSession) -> TerminalSession {
        store.openTerminal(tab)
        return tab
    }

    /// A plain terminal, which the next launch reopens without a session to resume.
    private func makeTab(projectPath: String) -> TerminalSession {
        TerminalSession(
            conversation: nil,
            provider: nil,
            projectPath: projectPath,
            action: nil,
            displayTitle: "Terminal in \(projectPath)",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: projectPath, environment: [])
        )
    }
}
