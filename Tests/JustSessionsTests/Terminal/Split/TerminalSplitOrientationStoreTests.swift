import Foundation
import Testing
@testable import JustSessions

/// A split lays its two views out side by side or stacked, one above the other; either way it stays two tabs, the first
/// in the tab bar on the left or on top. A tab dropped on the top or bottom edge opens below or above the selected tab,
/// a split's pane dragged to an edge moves its tab there, and a new session can open straight into a new split.
@MainActor
struct TerminalSplitOrientationStoreTests {
    @Test func aSplitIsSideBySideUntilStacked() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        let split = try #require(store.shownSplit)
        #expect(store.orientation(ofSplitView: split.id) == .sideBySide)

        store.setOrientation(.stacked, ofSplitView: split.id)

        #expect(store.shownSplitOrientation == .stacked)
        // Each tab keeps its side: the left one is now on top.
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: first.id, right: second.id))
        #expect(store.selectedTerminalID == first.id)

        store.setOrientation(.sideBySide, ofSplitView: split.id)
        #expect(store.shownSplitOrientation == .sideBySide)
    }

    @Test func aTabDroppedOnTheBottomEdgeShowsBelowTheSelectedTab() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(second.id)

        store.showDroppedTab(first.id, at: .split(.right, .stacked))

        let split = try #require(store.shownSplit)
        #expect(store.orientation(ofSplitView: split.id) == .stacked)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: second.id, right: first.id))
        #expect(store.selectedTerminalID == first.id)
        expectSplitRules(store)
    }

    @Test func aTabDroppedOnAStackedSplitTakesThatPaneAndTheSplitStaysStacked() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        let third = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id, orientation: .stacked)
        let split = try #require(store.shownSplit)

        store.showDroppedTab(third.id, at: .split(.left, .stacked))

        let swapped = try #require(store.shownSplit)
        #expect(swapped.id == split.id)
        #expect(store.orientation(ofSplitView: split.id) == .stacked)
        #expect(store.sides(of: swapped)?.left == third.id)
        expectSplitRules(store)
    }

    @Test func aPaneDraggedToAnotherEdgeMovesItsTabThere() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        let split = try #require(store.shownSplit)

        store.rearrangeShownSplit(placing: second.id, at: .split(.right, .stacked))
        #expect(store.orientation(ofSplitView: split.id) == .stacked)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: first.id, right: second.id))
        #expect(store.selectedTerminalID == second.id)

        store.rearrangeShownSplit(placing: second.id, at: .split(.left, .stacked))
        #expect(store.sides(of: try #require(store.shownSplit)) == TerminalSplit.Sides(left: second.id, right: first.id))

        store.rearrangeShownSplit(placing: second.id, at: .split(.right, .sideBySide))
        #expect(store.orientation(ofSplitView: split.id) == .sideBySide)
        #expect(store.sides(of: try #require(store.shownSplit)) == TerminalSplit.Sides(left: first.id, right: second.id))
        expectSplitRules(store)
    }

    @Test func aPaneDraggedToTheMiddleShowsOnItsOwn() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id, orientation: .stacked)

        store.rearrangeShownSplit(placing: second.id, at: .wholeArea)

        #expect(store.terminalSplits.isEmpty)
        #expect(store.selectedTerminalID == second.id)
        #expect(store.stackedSplitViewIDs.isEmpty)
    }

    @Test func aSeparatedSplitForgetsItWasStacked() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id, orientation: .stacked)
        let split = try #require(store.shownSplit)

        store.separateSplit(split.id)
        store.splitSelectedTerminal(with: second.id)

        #expect(store.shownSplitOrientation == .sideBySide)
        #expect(store.stackedSplitViewIDs.isEmpty)
    }

    @Test func aNewTabOpensStraightIntoANewSplitBelowTheSelectedTab() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let other = open(store, makeTab())
        store.selectTerminal(first.id)
        let newTab = makeTab()

        store.openTabInNewSplit(on: .right, orientation: .stacked) { store.openTerminal(newTab) }

        let split = try #require(store.shownSplit)
        #expect(store.orientation(ofSplitView: split.id) == .stacked)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: first.id, right: newTab.id))
        #expect(store.selectedTerminalID == newTab.id)
        #expect(store.split(containing: other.id) == nil)
        expectSplitRules(store)
    }

    @Test func aNewTabOpensOnItsOwnWhileTheSelectedTabIsInASplit() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        let newTab = makeTab()

        store.openTabInNewSplit(on: .right, orientation: .stacked) { store.openTerminal(newTab) }

        #expect(store.selectedTerminalID == newTab.id)
        #expect(store.split(containing: newTab.id) == nil)
    }

    @Test func theSplitMenuNamesTheSplitsLayout() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        let third = open(store, makeTab())
        store.selectTerminal(first.id)

        guard case .addTabToNewSplit(let candidates, _, _) = store.splitMenu(forTab: first.id) else {
            Issue.record("The selected tab in no split offers new splits")
            return
        }
        #expect(candidates.map(\.id) == [second.id, third.id])

        store.performSplitAction(.addToNewSplit(third.id, .stacked), fromTab: first.id) { _ in }
        let split = try #require(store.shownSplit)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: first.id, right: third.id))
        guard case .arrangeSplit(.stacked) = store.splitMenu(forTab: first.id) else {
            Issue.record("A stacked split's tab arranges it stacked")
            return
        }
        guard case .moveIntoShownSplit(.stacked) = store.splitMenu(forTab: second.id) else {
            Issue.record("A tab off screen moves into the stacked split")
            return
        }

        store.performSplitAction(.setOrientation(.sideBySide), fromTab: third.id) { _ in }
        #expect(store.shownSplitOrientation == .sideBySide)
    }

    @Test func aTabOffScreenOpensBelowTheSelectedTabFromItsMenu() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(second.id)

        store.performSplitAction(.newSplitWithSelectedTab(.stacked), fromTab: first.id) { _ in }

        let split = try #require(store.shownSplit)
        #expect(store.orientation(ofSplitView: split.id) == .stacked)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: second.id, right: first.id))
        expectSplitRules(store)
    }

    @Test func aSplitChoosersLayoutCarriesOverToTheSplitItMakes() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(first.id)
        store.openSplitChooser()
        let chooser = try #require(store.shownSplitChooser)

        store.performSplitAction(.setOrientation(.stacked), fromTab: first.id) { _ in }
        #expect(store.shownSplitOrientation == .stacked)
        store.chooseTab(second.id, inSplitChooser: chooser.id)

        let split = try #require(store.shownSplit)
        #expect(split.id == chooser.id)
        #expect(store.orientation(ofSplitView: split.id) == .stacked)
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
