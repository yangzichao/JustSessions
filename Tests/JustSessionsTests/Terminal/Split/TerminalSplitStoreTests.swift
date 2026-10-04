import Foundation
import Testing
@testable import JustSessions

/// Splitting links two tabs side by side as Chrome's split view does: any number of splits, each outliving the
/// selection, showing while either of its tabs is selected, with the tab first in the tab bar on the left. A tab
/// joining from another project shows in the selected tab's group until it leaves the split.
@MainActor
struct TerminalSplitStoreTests {
    // MARK: - New split

    @Test func splittingLinksTheTabBesideTheSelectedTab() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        let third = open(store, makeTab())
        store.selectTerminal(first.id)

        store.splitSelectedTerminal(with: third.id)

        let split = try #require(store.shownSplit)
        #expect(split.tabIDs == [first.id, third.id])
        #expect(store.terminalSplits == [split])
        // The tab came from the right, so it lands right after the selected tab, as the right pane.
        #expect(ids(store) == [first.id, third.id, second.id])
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: first.id, right: third.id))
        #expect(store.selectedTerminalID == first.id)
        expectSplitRules(store)
    }

    @Test func aTabFromBeforeTheSelectedTabBecomesTheLeftPane() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        let third = open(store, makeTab())

        store.splitSelectedTerminal(with: first.id)

        let split = try #require(store.shownSplit)
        #expect(ids(store) == [second.id, first.id, third.id])
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: first.id, right: third.id))
        #expect(store.selectedTerminalID == third.id)
        expectSplitRules(store)
    }

    @Test func splittingNeedsAnotherOpenTab() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let onlyTab = open(store, makeTab())

        store.splitSelectedTerminal(with: onlyTab.id)
        #expect(store.terminalSplits.isEmpty)

        store.splitSelectedTerminal(with: UUID())
        #expect(store.terminalSplits.isEmpty)
        expectSplitRules(store)
    }

    @Test func splittingNeedsBothTabsOutOfEverySplit() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        let third = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        let split = try #require(store.shownSplit)
        let orderBefore = ids(store)

        // The selected tab is in a split.
        store.splitSelectedTerminal(with: third.id)
        #expect(store.terminalSplits == [split])

        // The other tab is in a split.
        store.selectTerminal(third.id)
        store.splitSelectedTerminal(with: first.id)
        #expect(store.terminalSplits == [split])
        #expect(ids(store) == orderBefore)
        expectSplitRules(store)
    }

    @Test func selectingATabOutsideTheSplitHidesItButKeepsItLinked() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        let third = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        let split = try #require(store.shownSplit)

        store.selectTerminal(third.id)
        #expect(store.shownSplit == nil)
        #expect(store.terminalSplits == [split])

        store.selectTerminal(second.id)
        #expect(store.shownSplit == split)
        expectSplitRules(store)
    }

    @Test func aTabFromAnotherProjectJoinsTheSelectedTabsGroupAndGoesBackOnSeparating() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app"))
        let secondApp = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))
        let secondTools = open(store, makeTab(projectPath: "/tmp/tools"))
        store.selectTerminal(app.id)

        store.splitSelectedTerminal(with: secondTools.id)

        let split = try #require(store.shownSplit)
        #expect(split.groupKey == app.projectDirectoryKey)
        #expect(ids(store) == [app.id, secondTools.id, secondApp.id, tools.id])
        #expect(store.tabGroupKey(of: secondTools) == app.projectDirectoryKey)
        #expect(store.tabGroupKeys == [app, app, app, tools].map(\.projectDirectoryKey))
        expectSplitRules(store)

        store.separateSplit(split.id)

        #expect(store.terminalSplits.isEmpty)
        #expect(ids(store) == [app.id, secondApp.id, tools.id, secondTools.id])
        #expect(store.tabGroupKey(of: secondTools) == tools.projectDirectoryKey)
        #expect(store.selectedTerminalID == app.id)
        expectSplitRules(store)
    }

    @Test func twoSplitsCanBeLinkedAtOnce() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app"))
        let secondApp = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))
        let secondTools = open(store, makeTab(projectPath: "/tmp/tools"))
        store.selectTerminal(app.id)
        store.splitSelectedTerminal(with: secondApp.id)
        let appSplit = try #require(store.shownSplit)
        store.selectTerminal(tools.id)
        store.splitSelectedTerminal(with: secondTools.id)
        let toolsSplit = try #require(store.shownSplit)

        #expect(store.terminalSplits == [appSplit, toolsSplit])
        #expect(store.split(containing: app.id) == appSplit)
        #expect(store.split(containing: secondTools.id) == toolsSplit)
        expectSplitRules(store)

        store.selectTerminal(secondApp.id)
        #expect(store.shownSplit == appSplit)
    }

    @Test func aNewTabOfTheSplitsGroupOpensAfterTheSplit() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))
        store.selectTerminal(app.id)
        store.splitSelectedTerminal(with: tools.id)
        #expect(ids(store) == [app.id, tools.id])

        let newApp = open(store, makeTab(projectPath: "/tmp/app"))
        let newTools = open(store, makeTab(projectPath: "/tmp/tools"))

        // The split's right tab is in the app's group, so the new app tab comes after it, and the tools tab starts
        // a tools group of its own.
        #expect(ids(store) == [app.id, tools.id, newApp.id, newTools.id])
        expectSplitRules(store)
    }

    @Test func aReopenedTabWaitingToBeShownStartsAsItJoinsTheSplit() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let conversation = sandbox.conversation()
        store.replaceConversations(on: .thisMac, with: [conversation])
        let selectedTab = makeTab()
        store.openTerminal(selectedTab)
        let waitingTab = try #require(try store.makeTerminal(for: conversation, action: .resume, startsOnceShown: true))
        store.insertReopenedTerminal(waitingTab, at: 0, selecting: false)
        #expect(waitingTab.isWaitingToBeShown)

        store.splitSelectedTerminal(with: waitingTab.id)

        #expect(store.selectedTerminalID == selectedTab.id)
        #expect(!waitingTab.isWaitingToBeShown)
        #expect(waitingTab.isRunning)
        #expect(waitingTab.processID > 0)
        expectSplitRules(store)
    }

    // MARK: - Reverse and separate

    @Test func reversingTradesTheTabsPlacesAndSoThePanesSides() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        let split = try #require(store.shownSplit)

        store.reverseSplit(split.id)

        #expect(ids(store) == [second.id, first.id])
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: second.id, right: first.id))
        #expect(store.terminalSplits == [split])
        #expect(store.selectedTerminalID == first.id)
        expectSplitRules(store)
    }

    @Test func separatingUnlinksTheSplitAndKeepsTheTabsOpen() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)

        store.separateSplit(try #require(store.shownSplit).id)

        #expect(store.terminalSplits.isEmpty)
        #expect(ids(store) == [first.id, second.id])
        #expect(store.selectedTerminalID == first.id)
        expectSplitRules(store)
    }

    // MARK: - Move into the split

    @Test func aTabMovedIntoTheRightPaneTradesPlacesWithItsTab() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        let third = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        let split = try #require(store.shownSplit)

        store.moveIntoShownSplit(third.id, swappingWith: .right)

        #expect(ids(store) == [first.id, third.id, second.id])
        let swapped = try #require(store.shownSplit)
        #expect(swapped.id == split.id)
        #expect(store.sides(of: swapped) == TerminalSplit.Sides(left: first.id, right: third.id))
        #expect(store.split(containing: second.id) == nil)
        #expect(store.selectedTerminalID == first.id)
        expectSplitRules(store)
    }

    @Test func aTabMovedInPlaceOfTheSelectedTabIsSelected() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        let third = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)

        store.moveIntoShownSplit(third.id, swappingWith: .left)

        #expect(ids(store) == [third.id, second.id, first.id])
        #expect(store.selectedTerminalID == third.id)
        #expect(store.sides(of: try #require(store.shownSplit)) == TerminalSplit.Sides(left: third.id, right: second.id))
        #expect(store.split(containing: first.id) == nil)
        expectSplitRules(store)
    }

    @Test func aTabMovedInPlaceOfTheOtherPaneLeavesTheSelectionAlone() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        let third = open(store, makeTab())
        store.selectTerminal(second.id)
        store.splitSelectedTerminal(with: first.id)
        #expect(ids(store) == [first.id, second.id, third.id])

        store.moveIntoShownSplit(third.id, swappingWith: .left)

        #expect(ids(store) == [third.id, second.id, first.id])
        #expect(store.selectedTerminalID == second.id)
        expectSplitRules(store)
    }

    @Test func aTabSwappedOutAmongAnotherProjectsTabsGoesBackToItsProject() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))
        let docs = open(store, makeTab(projectPath: "/tmp/docs"))
        let secondTools = open(store, makeTab(projectPath: "/tmp/tools"))
        store.selectTerminal(app.id)
        store.splitSelectedTerminal(with: tools.id)
        #expect(ids(store) == [app.id, tools.id, secondTools.id, docs.id])

        store.moveIntoShownSplit(docs.id, swappingWith: .right)

        // The tools tab took the docs tab's place at the end, then went back after the other tools tab.
        #expect(ids(store) == [app.id, docs.id, secondTools.id, tools.id])
        #expect(store.tabGroupKey(of: docs) == app.projectDirectoryKey)
        expectSplitRules(store)
    }

    @Test func movingIntoASplitNeedsTheSelectedTabInOneAndTheTabInNone() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        let third = open(store, makeTab())
        let fourth = open(store, makeTab())
        store.selectTerminal(first.id)
        store.moveIntoShownSplit(second.id, swappingWith: .left)
        #expect(store.terminalSplits.isEmpty)

        store.splitSelectedTerminal(with: second.id)
        store.selectTerminal(third.id)
        store.splitSelectedTerminal(with: fourth.id)
        let splitsBefore = store.terminalSplits
        let orderBefore = ids(store)

        store.moveIntoShownSplit(first.id, swappingWith: .left)

        #expect(store.terminalSplits == splitsBefore)
        #expect(ids(store) == orderBefore)
        expectSplitRules(store)
    }

    @Test func aWaitingTabStartsAsItMovesIntoTheSplit() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let conversation = sandbox.conversation()
        store.replaceConversations(on: .thisMac, with: [conversation])
        let first = makeTab()
        let second = makeTab()
        store.openTerminal(first)
        store.openTerminal(second)
        store.splitSelectedTerminal(with: first.id)
        let waitingTab = try #require(try store.makeTerminal(for: conversation, action: .resume, startsOnceShown: true))
        store.insertReopenedTerminal(waitingTab, at: 2, selecting: false)
        #expect(waitingTab.isWaitingToBeShown)

        store.moveIntoShownSplit(waitingTab.id, swappingWith: .left)

        #expect(store.shownSplit?.contains(waitingTab.id) == true)
        #expect(!waitingTab.isWaitingToBeShown)
        #expect(waitingTab.isRunning)
        expectSplitRules(store)
    }

    // MARK: - Closing

    @Test func closingTheSelectedTabOfASplitLeavesTheOtherInFront() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        // A tab next to the closed one in the bar would otherwise be the one selected after closing.
        let other = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        #expect(ids(store) == [first.id, second.id, other.id])

        store.closeTerminal(first.id)

        #expect(store.terminalSplits.isEmpty)
        #expect(store.selectedTerminalID == second.id)
        expectSplitRules(store)
    }

    @Test func closingTheOtherTabOfASplitKeepsTheSelectionAndUnlinks() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)

        store.closeTerminal(second.id)

        #expect(store.terminalSplits.isEmpty)
        #expect(store.selectedTerminalID == first.id)
        expectSplitRules(store)
    }

    @Test func aTabFromAnotherProjectGoesBackToItsProjectWhenItsPartnerCloses() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app"))
        let secondApp = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))
        let secondTools = open(store, makeTab(projectPath: "/tmp/tools"))
        store.selectTerminal(app.id)
        store.splitSelectedTerminal(with: tools.id)
        #expect(ids(store) == [app.id, tools.id, secondApp.id, secondTools.id])

        store.closeTerminal(app.id)

        #expect(ids(store) == [secondApp.id, secondTools.id, tools.id])
        #expect(store.selectedTerminalID == tools.id)
        #expect(store.tabGroupKey(of: tools) == tools.projectDirectoryKey)
        expectSplitRules(store)
    }

    @Test func closingATabOutsideTheSplitKeepsIt() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        let third = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        let split = try #require(store.shownSplit)

        store.closeTerminal(third.id)

        #expect(store.terminalSplits == [split])
        expectSplitRules(store)
    }

    @Test func closingTheSelectedTabBesideASplitShowsANeighborInItsGroup() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))
        let lastApp = open(store, makeTab(projectPath: "/tmp/app"))
        let docs = open(store, makeTab(projectPath: "/tmp/docs"))
        store.selectTerminal(app.id)
        store.splitSelectedTerminal(with: tools.id)
        #expect(ids(store) == [app.id, tools.id, lastApp.id, docs.id])
        store.selectTerminal(lastApp.id)

        store.closeTerminal(lastApp.id)

        // The tools tab is in the app's group while it is split, so it is the neighbor in the same group.
        #expect(store.selectedTerminalID == tools.id)
        expectSplitRules(store)
    }

    @Test func closingAllTabsUnlinksEverySplit() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)

        store.closeAllTerminals()

        #expect(store.terminalSplits.isEmpty)
    }

    @Test func closingTheLastTabOfASplitsGroupProjectRegroupsTheSplitUnderItsLeftTab() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))
        let docs = open(store, makeTab(projectPath: "/tmp/docs"))
        store.selectTerminal(app.id)
        store.splitSelectedTerminal(with: tools.id)
        store.moveIntoShownSplit(docs.id, swappingWith: .left)
        #expect(store.tabGroupKeys == [app, app, app].map(\.projectDirectoryKey))

        store.closeTerminal(app.id)

        // No group is left named for the app with none of its tabs.
        #expect(ids(store) == [docs.id, tools.id])
        #expect(store.tabGroupKeys == [docs, docs].map(\.projectDirectoryKey))
        #expect(store.split(containing: docs.id)?.groupKey == docs.projectDirectoryKey)
        expectSplitRules(store)
    }

    @Test func aSelectedTabLeavingAnotherProjectsGroupChangesItsGroupKey() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))
        let secondTools = open(store, makeTab(projectPath: "/tmp/tools"))
        store.selectTerminal(app.id)
        store.splitSelectedTerminal(with: secondTools.id)
        store.selectTerminal(secondTools.id)
        let groupKeyInTheSplit = try store.tabGroupKey(of: #require(store.selectedTerminal))
        #expect(groupKeyInTheSplit == app.projectDirectoryKey)

        store.separateSplit(try #require(store.shownSplit).id)

        // The selection stays while the selected tab's group changes: the tab bar expands that group if collapsed.
        #expect(store.selectedTerminalID == secondTools.id)
        #expect(try store.tabGroupKey(of: #require(store.selectedTerminal)) == tools.projectDirectoryKey)
        expectSplitRules(store)
    }

    // MARK: - Reconnecting

    @Test func aTabReplacedInPlaceKeepsItsPlaceInTheSplit() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        let split = try #require(store.shownSplit)

        let replacement = makeTab()
        let index = try #require(store.terminalSessions.firstIndex { $0.id == second.id })
        store.replaceTerminal(at: index, with: replacement)

        let replaced = try #require(store.split(containing: replacement.id))
        #expect(replaced.id == split.id)
        #expect(ids(store) == [first.id, replacement.id])
        #expect(store.sides(of: replaced) == TerminalSplit.Sides(left: first.id, right: replacement.id))
        expectSplitRules(store)
    }

    @Test func replacingTheSelectedTabOfASplitKeepsTheSplitItsSideAndTheSelection() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab())
        let second = open(store, makeTab())
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)

        let replacement = makeTab()
        let index = try #require(store.terminalSessions.firstIndex { $0.id == first.id })
        store.replaceTerminal(at: index, with: replacement)

        let split = try #require(store.shownSplit)
        #expect(store.sides(of: split) == TerminalSplit.Sides(left: replacement.id, right: second.id))
        #expect(store.selectedTerminalID == replacement.id)
        expectSplitRules(store)
    }

    // MARK: - Host refreshes

    @Test func movingBetweenThePanesOfAShownSplitRefreshesNoHost() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let newSessionTab = open(store, makeTab(action: .new))
        let other = open(store, makeTab())
        store.selectTerminal(newSessionTab.id)
        store.splitSelectedTerminal(with: other.id)

        store.selectTerminal(other.id)
        store.selectTerminal(newSessionTab.id)

        #expect(store.hostRefreshStatuses[.thisMac] == nil)
    }

    @Test func aNewSessionTabLeavingTheScreenWithItsSplitRefreshesItsHost() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let newSessionTab = open(store, makeTab(action: .new))
        let other = open(store, makeTab())
        let outside = open(store, makeTab())
        store.selectTerminal(other.id)
        store.splitSelectedTerminal(with: newSessionTab.id)
        #expect(store.hostRefreshStatuses[.thisMac] == nil)

        // The other tab is the selected one; the new session's tab still goes off screen with it.
        store.selectTerminal(outside.id)

        #expect(store.hostRefreshStatuses[.thisMac] == .refreshing)
    }

    @Test func separatingAShownSplitRefreshesTheHostOfANewSessionTabGoingOffScreen() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let newSessionTab = open(store, makeTab(action: .new))
        let other = open(store, makeTab())
        store.selectTerminal(other.id)
        store.splitSelectedTerminal(with: newSessionTab.id)
        #expect(store.hostRefreshStatuses[.thisMac] == nil)

        store.separateSplit(try #require(store.shownSplit).id)

        #expect(store.hostRefreshStatuses[.thisMac] == .refreshing)
    }

    @Test func separatingAShownSplitRefreshesNoHostWhileTheNewSessionTabStaysSelected() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let newSessionTab = open(store, makeTab(action: .new))
        let other = open(store, makeTab())
        store.selectTerminal(newSessionTab.id)
        store.splitSelectedTerminal(with: other.id)

        store.separateSplit(try #require(store.shownSplit).id)

        #expect(store.hostRefreshStatuses[.thisMac] == nil)
    }

    @Test func aNewSessionTabSwappedOutOfTheShownSplitRefreshesItsHost() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let newSessionTab = open(store, makeTab(action: .new))
        let other = open(store, makeTab())
        let incoming = open(store, makeTab())
        store.selectTerminal(other.id)
        store.splitSelectedTerminal(with: newSessionTab.id)
        let shownSplit = try #require(store.shownSplit)
        let side = try #require(store.sides(of: shownSplit)?.side(of: newSessionTab.id))

        store.moveIntoShownSplit(incoming.id, swappingWith: side)

        #expect(store.selectedTerminalID == other.id)
        #expect(store.hostRefreshStatuses[.thisMac] == .refreshing)
    }

    // MARK: - Reopening after quit

    @Test func tabsAreSavedInTheOrderTheyWouldTakeWithEverySplitSeparated() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app", isPlainTerminal: true))
        let secondApp = open(store, makeTab(projectPath: "/tmp/app", isPlainTerminal: true))
        let tools = open(store, makeTab(projectPath: "/tmp/tools", isPlainTerminal: true))
        let secondTools = open(store, makeTab(projectPath: "/tmp/tools", isPlainTerminal: true))
        store.selectTerminal(app.id)
        store.splitSelectedTerminal(with: tools.id)
        #expect(ids(store) == [app.id, tools.id, secondApp.id, secondTools.id])

        let saved = store.reopenableTabs

        // The tools tab is saved after the other tools tab, where separating the split sends it, not inside the app's.
        #expect(saved.map(\.projectDirectoryKey) == [app, secondApp, secondTools, tools].map(\.projectDirectoryKey))
        #expect(saved.map(\.wasSelected) == [true, false, false, false])
        #expect(ids(store) == [app.id, tools.id, secondApp.id, secondTools.id])
        #expect(store.shownSplit != nil)
    }

    @Test func aReopenedTabNeverLandsBetweenASplitsTabs() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app"))
        let secondApp = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))
        store.selectTerminal(app.id)
        store.splitSelectedTerminal(with: secondApp.id)

        let reopenedApp = makeTab(projectPath: "/tmp/app")
        store.insertReopenedTerminal(reopenedApp, at: 1, selecting: false)
        #expect(ids(store) == [app.id, secondApp.id, reopenedApp.id, tools.id])
        expectSplitRules(store)

        let reopenedDocs = makeTab(projectPath: "/tmp/docs")
        store.insertReopenedTerminal(reopenedDocs, at: 1, selecting: false)
        #expect(ids(store) == [app.id, secondApp.id, reopenedApp.id, tools.id, reopenedDocs.id])
        #expect(store.selectedTerminalID == app.id)
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
        expectSplitRules(store)
        return tab
    }

    private func ids(_ store: ConversationStore) -> [UUID] {
        store.terminalSessions.map(\.id)
    }

    private func makeTab(
        projectPath: String = "/tmp/app",
        action: ConversationAction = .resume,
        isPlainTerminal: Bool = false
    ) -> TerminalSession {
        TerminalSession(
            conversation: nil,
            provider: isPlainTerminal ? nil : .claude,
            projectPath: projectPath,
            action: isPlainTerminal ? nil : action,
            displayTitle: "Tab in \(projectPath)",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: projectPath, environment: [])
        )
    }
}
