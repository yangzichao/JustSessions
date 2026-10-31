import Foundation
import Testing
@testable import JustSessions

/// Add Tab to New Split View (⌘⌥N) as Chrome's NewSplitTab and split view new tab page: the selected tab shows on the
/// left beside a chooser, which has the keyboard and lists the window's other tabs off screen and in no split, the one
/// selected last first. The tab chosen there makes a split with it on the chooser's side and is selected. The chooser
/// counts as a split's other view: the split entries arrange and close it, a tab moved or dropped on its side takes its
/// place, and its tab joins no other split.
@MainActor
struct TerminalSplitChooserStoreTests {
    // MARK: - Opening

    @Test func aChooserShowsBesideTheSelectedTabAndTakesTheKeyboard() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(first.id)
        #expect(store.canOpenSplitChooser)

        store.openSplitChooser()

        let chooser = try #require(store.shownSplitChooser)
        #expect(chooser.tabID == first.id)
        #expect(chooser.side == .right)
        #expect(chooser.tabSide == .left)
        #expect(store.selectsShownSplitChooser)
        #expect(store.isSplitViewShown)
        #expect(store.terminalSplits.isEmpty)
        #expect(ids(store) == [first.id, second.id])
        #expect(!store.canOpenSplitChooser)
        expectChooserRules(store)
    }

    @Test func aChooserNeedsASelectedTabInNoSplitNorBesideAChooser() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        store.openSplitChooser()
        #expect(store.terminalSplitChoosers.isEmpty)

        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        #expect(!store.canOpenSplitChooser)
        store.openSplitChooser()
        #expect(store.terminalSplitChoosers.isEmpty)

        let third = open(store, makeTab())
        store.openSplitChooser()
        store.openSplitChooser()
        #expect(store.terminalSplitChoosers.map(\.tabID) == [third.id])
        expectChooserRules(store)
    }

    // MARK: - The list

    @Test func theChooserListsTabsOffScreenInNoSplitTheOneSelectedLastFirst() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let a = open(store, makeTab())
        let b = open(store, makeTab())
        let c = open(store, makeTab())
        let d = open(store, makeTab())
        let e = open(store, makeTab())
        store.selectTerminal(b.id)
        store.selectTerminal(c.id)
        store.splitSelectedTerminal(with: d.id)
        store.selectTerminal(a.id)
        store.openSplitChooser()

        // a shows, c and d are in a split; b was selected after e.
        #expect(store.splitChooserCandidates.map(\.id) == [b.id, e.id])

        // A tab reopened without being shown was never selected, so it comes last.
        let reopened = makeTab()
        store.insertReopenedTerminal(reopened, at: 0, selecting: false)
        #expect(store.splitChooserCandidates.map(\.id) == [b.id, e.id, reopened.id])
        expectChooserRules(store)
    }

    @Test func aChooserListsNothingWhileHidden() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(first.id)
        store.openSplitChooser()
        #expect(store.splitChooserCandidates.map(\.id) == [second.id])

        store.selectTerminal(second.id)

        #expect(store.shownSplitChooser == nil)
        #expect(store.splitChooserCandidates.isEmpty)
    }

    // MARK: - Choosing

    @Test func choosingATabSplitsItOnTheChoosersSideAndSelectsIt() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let a = open(store, makeTab())
        let b = open(store, makeTab())
        let c = open(store, makeTab())
        store.selectTerminal(a.id)
        store.openSplitChooser()
        let chooser = try #require(store.shownSplitChooser)

        store.chooseTab(c.id, inSplitChooser: chooser.id)

        let split = try #require(store.shownSplit)
        // The split keeps the chooser's id, so its panes keep their widths.
        #expect(split.id == chooser.id)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: a.id, right: c.id))
        #expect(ids(store) == [a.id, c.id, b.id])
        #expect(store.selectedTerminalID == c.id)
        #expect(store.terminalSplitChoosers.isEmpty)
        #expect(!store.selectsShownSplitChooser)
        expectSplitRules(store)
        expectChooserRules(store)
    }

    @Test func aTabFromBeforeTheChoosersTabStillLandsOnTheChoosersSide() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let a = open(store, makeTab())
        let b = open(store, makeTab())
        let c = open(store, makeTab())
        store.openSplitChooser()
        let chooser = try #require(store.shownSplitChooser)

        store.chooseTab(a.id, inSplitChooser: chooser.id)

        let split = try #require(store.shownSplit)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: c.id, right: a.id))
        #expect(ids(store) == [b.id, c.id, a.id])
        expectSplitRules(store)
    }

    @Test func aTabFromAnotherProjectMakesASplitAcrossProjects() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))
        store.selectTerminal(app.id)
        store.openSplitChooser()
        let chooser = try #require(store.shownSplitChooser)

        store.chooseTab(tools.id, inSplitChooser: chooser.id)

        let split = try #require(store.shownSplit)
        #expect(split.spansProjects)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: app.id, right: tools.id))
        expectSplitRules(store)
    }

    @Test func onlyATabOffScreenInNoSplitCanBeChosen() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let a = open(store, makeTab())
        let b = open(store, makeTab())
        let c = open(store, makeTab())
        store.selectTerminal(b.id)
        store.splitSelectedTerminal(with: c.id)
        store.selectTerminal(a.id)
        store.openSplitChooser()
        let chooser = try #require(store.shownSplitChooser)

        store.chooseTab(a.id, inSplitChooser: chooser.id)
        store.chooseTab(c.id, inSplitChooser: chooser.id)
        store.chooseTab(UUID(), inSplitChooser: chooser.id)

        #expect(store.terminalSplitChoosers == [chooser])
        #expect(store.terminalSplits.count == 1)
        expectChooserRules(store)
    }

    // MARK: - Closing, reversing, and selecting

    @Test func closingTheChooserLeavesItsTabFullWidthWithTheKeyboard() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let a = open(store, makeTab())
        _ = open(store, makeTab())
        store.selectTerminal(a.id)
        store.openSplitChooser()
        let chooser = try #require(store.shownSplitChooser)

        store.closeSplitChooser(chooser.id)

        #expect(store.terminalSplitChoosers.isEmpty)
        #expect(!store.isSplitViewShown)
        #expect(store.selectedTerminalID == a.id)
        #expect(!store.selectsShownSplitChooser)
    }

    @Test func reversingPutsTheChooserOnTheLeftAndTheChosenTabThere() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let a = open(store, makeTab())
        let b = open(store, makeTab())
        store.selectTerminal(a.id)
        store.openSplitChooser()
        let chooser = try #require(store.shownSplitChooser)

        store.reverseSplitChooser(chooser.id)
        #expect(store.shownSplitChooser?.side == .left)
        #expect(store.shownSplitChooser?.tabSide == .right)

        store.chooseTab(b.id, inSplitChooser: chooser.id)

        let split = try #require(store.shownSplit)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: b.id, right: a.id))
        expectSplitRules(store)
    }

    @Test func theChooserOutlivesTheSelectionAndGivesTheKeyboardBackToTabs() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let a = open(store, makeTab())
        let b = open(store, makeTab())
        store.selectTerminal(a.id)
        store.openSplitChooser()
        let chooser = try #require(store.shownSplitChooser)

        store.selectTerminal(b.id)
        #expect(store.shownSplitChooser == nil)
        #expect(store.terminalSplitChoosers == [chooser])
        #expect(!store.selectsShownSplitChooser)

        // Coming back to its tab shows it, with the keyboard in the tab.
        store.selectTerminal(a.id)
        #expect(store.shownSplitChooser == chooser)
        #expect(!store.selectsShownSplitChooser)

        store.selectSplitChooser(beside: a.id)
        #expect(store.selectsShownSplitChooser)

        // A click in the tab's terminal takes the keyboard back.
        store.selectTerminal(a.id)
        #expect(!store.selectsShownSplitChooser)
    }

    @Test func closingTheTabClosesItsChooser() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let a = open(store, makeTab())
        let b = open(store, makeTab())
        store.selectTerminal(a.id)
        store.openSplitChooser()

        store.closeTerminal(a.id)

        #expect(store.terminalSplitChoosers.isEmpty)
        #expect(store.selectedTerminalID == b.id)
        #expect(!store.selectsShownSplitChooser)
        expectChooserRules(store)
    }

    @Test func aReplacedTabKeepsItsChooser() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let a = open(store, makeTab())
        _ = open(store, makeTab())
        store.selectTerminal(a.id)
        store.openSplitChooser()
        let chooser = try #require(store.shownSplitChooser)
        let replacement = makeTab()

        store.replaceTerminal(at: 0, with: replacement)

        #expect(store.terminalSplitChoosers == [TerminalSplitChooser(id: chooser.id, tabID: replacement.id)])
        #expect(store.shownSplitChooser?.tabID == replacement.id)
        #expect(store.selectsShownSplitChooser)
        expectChooserRules(store)
    }

    @Test func closingEveryTabClosesEveryChooser() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        _ = open(store, makeTab())
        store.openSplitChooser()

        store.closeAllTerminals()

        #expect(store.terminalSplitChoosers.isEmpty)
        #expect(!store.selectsShownSplitChooser)
    }

    // MARK: - Split entries

    @Test func theSplitEntriesArrangeTheChooser() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let a = open(store, makeTab())
        let b = open(store, makeTab())
        store.selectTerminal(a.id)
        store.openSplitChooser()
        var closedTabIDs: [UUID] = []
        let perform = { (action: TerminalTabSplitAction) in
            store.performSplitAction(action, fromTab: a.id) { closedTabIDs.append($0) }
        }

        guard case .arrangeSplit = store.splitMenu(forTab: a.id) else {
            Issue.record("The chooser's tab arranges its split view")
            return
        }
        guard case .moveIntoShownSplit = store.splitMenu(forTab: b.id) else {
            Issue.record("Another tab can move into the shown split view")
            return
        }

        perform(.reverseViews)
        #expect(store.shownSplitChooser?.side == .left)

        // The chooser's own view closes at once; the tab's view closes as its × does.
        perform(.closeView(.right))
        #expect(closedTabIDs == [a.id])
        #expect(store.shownSplitChooser != nil)
        perform(.closeView(.left))
        #expect(store.terminalSplitChoosers.isEmpty)

        store.openSplitChooser()
        perform(.separateViews)
        #expect(store.terminalSplitChoosers.isEmpty)
        #expect(closedTabIDs == [a.id])
    }

    @Test func aTabBesideAChooserIsOfferedForNoNewSplit() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let a = open(store, makeTab())
        let b = open(store, makeTab())
        let c = open(store, makeTab())
        store.selectTerminal(a.id)
        store.openSplitChooser()
        store.selectTerminal(b.id)

        guard case .addTabToNewSplit(let candidates, _, _) = store.splitMenu(forTab: b.id) else {
            Issue.record("The selected tab offers tabs for a new split")
            return
        }
        #expect(candidates.map(\.id) == [c.id])

        store.splitSelectedTerminal(with: a.id)
        #expect(store.terminalSplits.isEmpty)
        #expect(!store.canShowDroppedTabs([a.id]))

        // Nor can it swap into a split.
        store.splitSelectedTerminal(with: c.id)
        store.moveIntoShownSplit(a.id, swappingWith: .left)
        #expect(store.split(containing: a.id) == nil)
        expectSplitRules(store)
        expectChooserRules(store)
    }

    @Test func aTabMovedIntoTheChoosersSideIsChosen() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let a = open(store, makeTab())
        _ = open(store, makeTab())
        let c = open(store, makeTab())
        store.selectTerminal(a.id)
        store.openSplitChooser()

        store.performSplitAction(.moveIntoShownSplit(swappingWith: .right), fromTab: c.id) { _ in }

        let split = try #require(store.shownSplit)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: a.id, right: c.id))
        #expect(store.selectedTerminalID == c.id)
        expectSplitRules(store)
    }

    @Test func aTabMovedIntoTheOtherSideTakesTheChooserFromItsTab() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let a = open(store, makeTab())
        let b = open(store, makeTab())
        let c = open(store, makeTab())
        store.selectTerminal(a.id)
        store.openSplitChooser()
        let chooser = try #require(store.shownSplitChooser)

        store.performSplitAction(.moveIntoShownSplit(swappingWith: .left), fromTab: c.id) { _ in }

        #expect(store.terminalSplitChoosers == [TerminalSplitChooser(id: chooser.id, tabID: c.id)])
        #expect(store.selectedTerminalID == c.id)
        #expect(store.selectsShownSplitChooser)
        #expect(ids(store) == [a.id, b.id, c.id])
        expectChooserRules(store)
    }

    // MARK: - Dropping

    @Test func aTabDroppedOnTheChoosersSideIsChosenAndOnTheOtherTakesTheChooser() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let a = open(store, makeTab())
        let b = open(store, makeTab())
        let c = open(store, makeTab())
        store.selectTerminal(a.id)
        store.openSplitChooser()

        store.showDroppedTabInSplit(b.id, on: .left)
        #expect(store.shownSplitChooser?.tabID == b.id)
        #expect(store.selectedTerminalID == b.id)

        store.showDroppedTabInSplit(c.id, on: .right)
        let split = try #require(store.shownSplit)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: b.id, right: c.id))
        #expect(store.selectedTerminalID == c.id)
        #expect(store.terminalSplitChoosers.isEmpty)
        expectSplitRules(store)
        expectChooserRules(store)
    }

    // MARK: - New Session…

    @Test func aTabStartedFromTheChoosersNewSessionTakesItsPlace() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let a = open(store, makeTab())
        store.openSplitChooser()
        let chooser = try #require(store.shownSplitChooser)
        #expect(store.splitChooserCandidates.isEmpty)

        store.awaitNewTab(inSplitChooser: chooser.id)
        let started = open(store, makeTab())

        let split = try #require(store.shownSplit)
        #expect(split.id == chooser.id)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: a.id, right: started.id))
        #expect(store.selectedTerminalID == started.id)

        // Only that one tab.
        let next = open(store, makeTab())
        #expect(store.split(containing: next.id) == nil)
        expectSplitRules(store)
    }

    @Test func aTabOpenedOnceTheSheetClosedOpensOnItsOwn() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let a = open(store, makeTab())
        store.openSplitChooser()
        let chooser = try #require(store.shownSplitChooser)

        store.awaitNewTab(inSplitChooser: chooser.id)
        store.stopAwaitingNewTabInSplitChooser()
        let later = open(store, makeTab())

        #expect(store.terminalSplits.isEmpty)
        #expect(store.selectedTerminalID == later.id)
        #expect(store.splitChooser(beside: a.id) == chooser)
    }

    // MARK: - Helpers

    /// Every chooser is beside an open tab in no split, with at most one beside a tab.
    private func expectChooserRules(_ store: ConversationStore, sourceLocation: SourceLocation = #_sourceLocation) {
        let openTabIDs = Set(store.terminalSessions.map(\.id))
        let chooserTabIDs = store.terminalSplitChoosers.map(\.tabID)
        #expect(chooserTabIDs.allSatisfy(openTabIDs.contains), "a chooser's tab is open", sourceLocation: sourceLocation)
        #expect(chooserTabIDs.allSatisfy { store.split(containing: $0) == nil }, "a chooser's tab is in no split", sourceLocation: sourceLocation)
        #expect(Set(chooserTabIDs).count == chooserTabIDs.count, "a tab has at most one chooser", sourceLocation: sourceLocation)
        if store.selectsShownSplitChooser {
            #expect(store.shownSplitChooser != nil, "only a shown chooser has the keyboard", sourceLocation: sourceLocation)
        }
    }

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
