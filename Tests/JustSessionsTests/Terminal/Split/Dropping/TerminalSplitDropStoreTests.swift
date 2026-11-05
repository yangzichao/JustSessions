import Foundation
import Testing
@testable import JustSessions

/// A tab dropped on a side of the terminals shows there in a split view, selected: beside the selected tab in a new
/// split, or in place of the shown split's tab on that side. Dropped in the middle, it shows on its own, selected. Only
/// one tab in no split, other than the selected one, can drop there.
@MainActor
struct TerminalSplitDropStoreTests {
    @Test func aTabDroppedOnTheRightShowsBesideTheSelectedTabOnTheRight() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(second.id)

        store.showDroppedTabInSplit(first.id, on: .right)

        let split = try #require(store.shownSplit)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: second.id, right: first.id))
        #expect(ids(store) == [second.id, first.id])
        #expect(store.selectedTerminalID == first.id)
        expectSplitRules(store)
    }

    @Test func aTabDroppedOnTheLeftShowsBesideTheSelectedTabOnTheLeft() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        let third = open(store, makeTab())
        store.selectTerminal(first.id)

        store.showDroppedTabInSplit(third.id, on: .left)

        let split = try #require(store.shownSplit)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: third.id, right: first.id))
        #expect(ids(store) == [third.id, first.id, second.id])
        #expect(store.selectedTerminalID == third.id)
        expectSplitRules(store)
    }

    @Test func aTabDroppedOnAShownSplitTakesThePlaceOfThatSidesTab() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        let third = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        let split = try #require(store.shownSplit)

        store.showDroppedTabInSplit(third.id, on: .right)

        let swapped = try #require(store.shownSplit)
        #expect(swapped.id == split.id)
        #expect(store.sides(of: swapped) == TerminalSplit.Sides(left: first.id, right: third.id))
        #expect(store.split(containing: second.id) == nil)
        #expect(store.selectedTerminalID == third.id)
        expectSplitRules(store)
    }

    @Test func aTabFromAnotherProjectDropsIntoASplitAcrossProjects() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))
        store.selectTerminal(app.id)

        store.showDroppedTabInSplit(tools.id, on: .left)

        let split = try #require(store.shownSplit)
        #expect(split.spansProjects)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: tools.id, right: app.id))
        #expect(store.selectedTerminalID == tools.id)
        expectSplitRules(store)
    }

    @Test func aTabDroppedOnTheWholeAreaShowsOnItsOwnWithTheShownTabStillOpen() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(second.id)

        store.showDroppedTab(first.id, at: .wholeArea)

        #expect(store.selectedTerminalID == first.id)
        #expect(ids(store) == [first.id, second.id])
        #expect(store.terminalSplits.isEmpty)

        store.showDroppedTab(second.id, at: .split(.left, .sideBySide))
        let split = try #require(store.shownSplit)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: second.id, right: first.id))
        #expect(store.selectedTerminalID == second.id)
        expectSplitRules(store)
    }

    @Test func onlyOneTabInNoSplitBesidesTheSelectedOneDrops() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        let third = open(store, makeTab())
        let fourth = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        store.selectTerminal(third.id)

        #expect(store.canShowDroppedTabs([fourth.id]))
        // The selected tab itself, a split's tab, and a split's two tabs together.
        #expect(!store.canShowDroppedTabs([third.id]))
        #expect(!store.canShowDroppedTabs([first.id]))
        #expect(!store.canShowDroppedTabs([first.id, second.id]))

        let orderBefore = ids(store)
        let splitsBefore = store.terminalSplits
        store.showDroppedTabInSplit(first.id, on: .left)
        store.showDroppedTab(first.id, at: .wholeArea)
        #expect(ids(store) == orderBefore)
        #expect(store.terminalSplits == splitsBefore)
        #expect(store.selectedTerminalID == third.id)
    }

    @Test func nothingDropsWhileNoTabIsSelected() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        _ = open(store, makeTab())
        store.selectTerminal(nil)

        #expect(!store.canShowDroppedTabs([first.id]))
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

    private func ids(_ store: ConversationStore) -> [UUID] {
        store.terminalSessions.map(\.id)
    }

    private func makeTab(projectPath: String = "/tmp/app") -> TerminalSession {
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
