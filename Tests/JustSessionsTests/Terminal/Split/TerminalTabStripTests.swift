import Foundation
import Testing

@testable import JustSessions

/// The tab order as Chrome's split view changes it: a tab joining a split moves beside the selected tab on the side it
/// came from; a split of one project's tabs stays in that project's group, and a split across two projects becomes a
/// unit of its own right after the selected tab's project's group; reversing trades the tabs' places; a tab leaving a
/// split goes back to its project's tabs. Tabs are named by their project's letter and a number, such as `a1`.
struct TerminalTabStripTests {
    // MARK: - New split

    @Test func aTabJoiningFromTheLeftLandsRightBeforeThePivotAsTheLeftPane() throws {
        var strip = makeStrip("a1", "a2", "a3")

        let added = strip.addSplit(joining: id("a1"), beside: id("a3"))

        let split = try #require(added)

        #expect(names(strip) == ["a2", "a1", "a3"])
        #expect(strip.sides(of: split) == TerminalSplit.Sides(left: id("a1"), right: id("a3")))
        #expect(split.groupKey == "/a")
        expectSplitRules(strip)
    }

    @Test func aTabJoiningFromTheRightLandsRightAfterThePivotAsTheRightPane() throws {
        var strip = makeStrip("a1", "a2", "a3")

        let added = strip.addSplit(joining: id("a3"), beside: id("a1"))

        let split = try #require(added)

        #expect(names(strip) == ["a1", "a3", "a2"])
        #expect(strip.sides(of: split) == TerminalSplit.Sides(left: id("a1"), right: id("a3")))
        expectSplitRules(strip)
    }

    @Test func aTabJoiningFromTheLeftOnTheRightLandsRightAfterThePivot() throws {
        var strip = makeStrip("a1", "a2", "a3")

        let added = strip.addSplit(joining: id("a1"), beside: id("a3"), on: .right)

        let split = try #require(added)

        #expect(names(strip) == ["a2", "a3", "a1"])
        #expect(strip.sides(of: split) == TerminalSplit.Sides(left: id("a3"), right: id("a1")))
        expectSplitRules(strip)
    }

    @Test func aTabJoiningFromTheRightOnTheLeftLandsRightBeforeThePivot() throws {
        var strip = makeStrip("a1", "a2", "a3")

        let added = strip.addSplit(joining: id("a3"), beside: id("a1"), on: .left)

        let split = try #require(added)

        #expect(names(strip) == ["a3", "a1", "a2"])
        #expect(strip.sides(of: split) == TerminalSplit.Sides(left: id("a3"), right: id("a1")))
        expectSplitRules(strip)
    }

    @Test func aTabFromAnotherProjectKeepsItsGivenSideInItsSplitOfItsOwn() throws {
        var strip = makeStrip("a1", "a2", "b1", "b2")

        let added = strip.addSplit(joining: id("b1"), beside: id("a1"), on: .left)

        let split = try #require(added)

        #expect(names(strip) == ["a2", "b1", "a1", "b2"])
        #expect(split.spansProjects)
        #expect(strip.groupKeys == ["/a", split.groupKey, split.groupKey, "/b"])
        #expect(strip.sides(of: split) == TerminalSplit.Sides(left: id("b1"), right: id("a1")))
        expectSplitRules(strip)
    }

    @Test func aTabFromAnotherProjectMakesASplitOfItsOwnRightAfterThePivotsGroup() throws {
        var strip = makeStrip("a1", "a2", "b1", "b2")

        let added = strip.addSplit(joining: id("b2"), beside: id("a1"))

        let split = try #require(added)

        #expect(names(strip) == ["a2", "a1", "b2", "b1"])
        #expect(split.spansProjects)
        #expect(strip.groupKeys == ["/a", split.groupKey, split.groupKey, "/b"])
        #expect(strip.sides(of: split) == TerminalSplit.Sides(left: id("a1"), right: id("b2")))
        expectSplitRules(strip)
    }

    @Test func aTabFromAnotherProjectBeforeThePivotTakesTheLeftPaneOfTheirSplit() throws {
        var strip = makeStrip("b1", "b2", "a1")

        let added = strip.addSplit(joining: id("b1"), beside: id("a1"))

        let split = try #require(added)

        #expect(names(strip) == ["b2", "b1", "a1"])
        #expect(strip.groupKeys == ["/b", split.groupKey, split.groupKey])
        #expect(strip.sides(of: split) == TerminalSplit.Sides(left: id("b1"), right: id("a1")))
        expectSplitRules(strip)
    }

    @Test func aSplitAcrossProjectsStaysWhereThePivotWasWhenItsProjectHasNoOtherTab() throws {
        var strip = makeStrip("b1", "a1", "b2", "b3")

        let added = strip.addSplit(joining: id("b2"), beside: id("a1"))

        let split = try #require(added)

        // Past the rest of project b's group, which the split would otherwise part.
        #expect(names(strip) == ["b1", "b3", "a1", "b2"])
        #expect(strip.groupKeys == ["/b", "/b", split.groupKey, split.groupKey])
        expectSplitRules(strip)
    }

    @Test func aSplitAcrossProjectsWithAProjectOfNoOtherTabsIsTheWholeBar() throws {
        var strip = makeStrip("a1", "b1")

        let added = strip.addSplit(joining: id("b1"), beside: id("a1"))

        let split = try #require(added)

        #expect(names(strip) == ["a1", "b1"])
        #expect(strip.groupKeys == [split.groupKey, split.groupKey])
        expectSplitRules(strip)
    }

    @Test func aNewSplitNeedsTwoOpenTabsInNoSplit() throws {
        var strip = makeStrip("a1", "a2", "a3")
        let withItself = strip.addSplit(joining: id("a1"), beside: id("a1"))
        #expect(withItself == nil)
        let withAClosedTab = strip.addSplit(joining: UUID(), beside: id("a1"))
        #expect(withAClosedTab == nil)
        let first = strip.addSplit(joining: id("a2"), beside: id("a1"))
        #expect(first != nil)
        let before = strip

        let besideASplitTab = strip.addSplit(joining: id("a3"), beside: id("a1"))
        #expect(besideASplitTab == nil)
        let joiningFromASplit = strip.addSplit(joining: id("a2"), beside: id("a3"))
        #expect(joiningFromASplit == nil)
        #expect(strip == before)
    }

    // MARK: - Reverse and separate

    @Test func reversingTradesTheTabsPlaces() throws {
        var strip = makeStrip("a1", "a2", "a3")
        let added = strip.addSplit(joining: id("a2"), beside: id("a1"))
        let split = try #require(added)

        strip.reverseSplit(split.id)

        #expect(names(strip) == ["a2", "a1", "a3"])
        #expect(strip.sides(of: split) == TerminalSplit.Sides(left: id("a2"), right: id("a1")))
        expectSplitRules(strip)
    }

    @Test func reversingASplitAcrossProjectsTradesItsTabsPlacesInItsOwnGroup() throws {
        var strip = makeStrip("a1", "a2", "b1")
        let added = strip.addSplit(joining: id("b1"), beside: id("a1"))
        let split = try #require(added)
        #expect(names(strip) == ["a2", "a1", "b1"])

        strip.reverseSplit(split.id)

        #expect(names(strip) == ["a2", "b1", "a1"])
        #expect(strip.sides(of: split) == TerminalSplit.Sides(left: id("b1"), right: id("a1")))
        #expect(strip.groupKeys == ["/a", split.groupKey, split.groupKey])
        expectSplitRules(strip)
    }

    @Test func separatingSendsEachTabOfASplitAcrossProjectsAfterItsProjectsLastTab() throws {
        var strip = makeStrip("a1", "a2", "b1", "b2")
        let added = strip.addSplit(joining: id("b2"), beside: id("a1"))
        let split = try #require(added)
        #expect(names(strip) == ["a2", "a1", "b2", "b1"])

        strip.separateSplit(split.id)

        #expect(names(strip) == ["a2", "a1", "b1", "b2"])
        #expect(strip.groupKeys == ["/a", "/a", "/b", "/b"])
        #expect(strip.splits.isEmpty)
        expectSplitRules(strip)
    }

    @Test func separatingLeavesATabWhoseProjectHasNoOtherTabBetweenTheGroups() throws {
        var strip = makeStrip("a1", "a2", "b1", "c1")
        let added = strip.addSplit(joining: id("b1"), beside: id("a1"))
        let split = try #require(added)
        #expect(names(strip) == ["a2", "a1", "b1", "c1"])

        strip.separateSplit(split.id)

        #expect(names(strip) == ["a2", "a1", "b1", "c1"])
        #expect(strip.groupKeys == ["/a", "/a", "/b", "/c"])
        expectSplitRules(strip)
    }

    @Test func separatingLeavesATabOfTheSplitsOwnProjectInPlace() throws {
        var strip = makeStrip("a1", "a2", "a3")
        let added = strip.addSplit(joining: id("a3"), beside: id("a2"))
        let split = try #require(added)

        strip.separateSplit(split.id)

        #expect(names(strip) == ["a1", "a2", "a3"])
        expectSplitRules(strip)
    }

    @Test func separatingEverySplitSendsEachTabBackToItsProject() throws {
        var strip = makeStrip("a1", "a2", "b1", "b2", "c1")
        let firstResult = strip.addSplit(joining: id("c1"), beside: id("a1"))
        let first = try #require(firstResult)
        let secondResult = strip.addSplit(joining: id("a2"), beside: id("b1"))
        let second = try #require(secondResult)
        #expect(names(strip) == ["a1", "c1", "b2", "a2", "b1"])
        #expect(strip.groupKeys == [first.groupKey, first.groupKey, "/b", second.groupKey, second.groupKey])
        expectSplitRules(strip)

        strip.separateAllSplits()

        #expect(names(strip) == ["a1", "a2", "c1", "b2", "b1"])
        #expect(strip.groupKeys == ["/a", "/a", "/c", "/b", "/b"])
        #expect(strip.splits.isEmpty)
        expectSplitRules(strip)
    }

    // MARK: - Swap into a split

    @Test func aSwappedInTabTakesTheRightTabsPlaceAndThatTabTakesItsOldOne() throws {
        var strip = makeStrip("a1", "a2", "a3", "a4")
        let added = strip.addSplit(joining: id("a3"), beside: id("a2"))
        let split = try #require(added)

        let made = strip.swap(id("a1"), intoSplit: split.id, replacing: id("a3"))
        #expect(made)

        #expect(names(strip) == ["a3", "a2", "a1", "a4"])
        let swapped = try #require(strip.split(containing: id("a1")))
        #expect(swapped.id == split.id)
        #expect(strip.sides(of: swapped) == TerminalSplit.Sides(left: id("a2"), right: id("a1")))
        #expect(strip.split(containing: id("a3")) == nil)
        expectSplitRules(strip)
    }

    @Test func aSwappedInTabTakesTheLeftTabsPlace() throws {
        var strip = makeStrip("a1", "a2", "a3", "a4")
        let added = strip.addSplit(joining: id("a3"), beside: id("a2"))
        let split = try #require(added)

        let made = strip.swap(id("a4"), intoSplit: split.id, replacing: id("a2"))
        #expect(made)

        #expect(names(strip) == ["a1", "a4", "a3", "a2"])
        #expect(strip.sides(of: try #require(strip.split(containing: id("a4")))) == TerminalSplit.Sides(left: id("a4"), right: id("a3")))
        expectSplitRules(strip)
    }

    @Test func aTabSwappedOutAmongAnotherProjectsTabsGoesBackToItsProject() throws {
        let split = splitAcrossProjects((id("a1"), id("b1")))
        var strip = makeStrip("c1", "a1", "b1", "b2", splits: [split])

        let made = strip.swap(id("c1"), intoSplit: split.id, replacing: id("b1"))
        #expect(made)

        #expect(names(strip) == ["a1", "c1", "b2", "b1"])
        #expect(strip.groupKeys == [split.groupKey, split.groupKey, "/b", "/b"])
        expectSplitRules(strip)
    }

    @Test func aTabSwappedOutAmongItsOwnProjectsTabsStaysInThatPlace() throws {
        let split = splitAcrossProjects((id("a1"), id("b1")))
        var strip = makeStrip("a1", "b1", "b2", "b3", splits: [split])

        let made = strip.swap(id("b2"), intoSplit: split.id, replacing: id("b1"))
        #expect(made)

        #expect(names(strip) == ["a1", "b2", "b1", "b3"])
        #expect(strip.groupKeys == [split.groupKey, split.groupKey, "/b", "/b"])
        expectSplitRules(strip)
    }

    @Test func aTabSwappedOutWhoseProjectHasNoOtherTabSitsBetweenTheGroups() throws {
        let split = splitAcrossProjects((id("a1"), id("c1")))
        var strip = makeStrip("b1", "b2", "b3", "a1", "c1", splits: [split])

        let made = strip.swap(id("b2"), intoSplit: split.id, replacing: id("c1"))
        #expect(made)

        // Past the rest of project b's group, which it would otherwise part.
        #expect(names(strip) == ["b1", "b3", "c1", "a1", "b2"])
        #expect(strip.groupKeys == ["/b", "/b", "/c", split.groupKey, split.groupKey])
        expectSplitRules(strip)
    }

    @Test func onlyATabInNoSplitSwapsIntoASplit() throws {
        var strip = makeStrip("a1", "a2", "a3", "a4")
        let added = strip.addSplit(joining: id("a2"), beside: id("a1"))
        let split = try #require(added)
        let other = strip.addSplit(joining: id("a4"), beside: id("a3"))
        #expect(other != nil)
        let before = strip

        let fromAnotherSplit = strip.swap(id("a3"), intoSplit: split.id, replacing: id("a1"))
        let fromTheSameSplit = strip.swap(id("a1"), intoSplit: split.id, replacing: id("a2"))
        let ofAClosedTab = strip.swap(UUID(), intoSplit: split.id, replacing: id("a2"))
        #expect(!fromAnotherSplit && !fromTheSameSplit && !ofAClosedTab)
        #expect(strip == before)
    }

    // MARK: - A split's group

    @Test func aSplitAcrossProjectsKeepsItsOwnGroupWhateverOtherTabsClose() throws {
        var strip = makeStrip("a1", "b1", "b2", "c1", "c2")
        let splitResult = strip.addSplit(joining: id("b1"), beside: id("a1"))
        let split = try #require(splitResult)
        let made = strip.swap(id("c1"), intoSplit: split.id, replacing: id("a1"))
        #expect(made)
        #expect(names(strip) == ["c1", "b1", "b2", "a1", "c2"])
        expectSplitRules(strip)

        strip.removeTab(id("a1"))
        strip.removeTab(id("c2"))

        let kept = try #require(strip.split(containing: id("c1")))
        #expect(kept.id == split.id)
        #expect(kept.spansProjects)
        #expect(names(strip) == ["c1", "b1", "b2"])
        #expect(strip.sides(of: kept) == TerminalSplit.Sides(left: id("c1"), right: id("b1")))
        expectSplitRules(strip)
    }

    @Test func aSwapThatMakesASplitOfOneProjectMovesItIntoThatProjectsGroup() throws {
        let split = splitAcrossProjects((id("a2"), id("b1")))
        var strip = makeStrip("a1", "a3", "a2", "b1", "b2", splits: [split])
        expectSplitRules(strip)

        let made = strip.swap(id("a3"), intoSplit: split.id, replacing: id("b1"))
        #expect(made)

        let regrouped = try #require(strip.split(containing: id("a2")))
        #expect(regrouped.id == split.id)
        #expect(regrouped.groupKey == "/a")
        #expect(names(strip) == ["a1", "a2", "a3", "b2", "b1"])
        #expect(strip.groupKeys == ["/a", "/a", "/a", "/b", "/b"])
        expectSplitRules(strip)
    }

    @Test func aSwapThatMakesASplitSpanProjectsMovesItRightAfterTheStayingTabsGroup() throws {
        var strip = makeStrip("a1", "a2", "a3", "b1")
        let splitResult = strip.addSplit(joining: id("a3"), beside: id("a2"))
        let split = try #require(splitResult)

        let made = strip.swap(id("b1"), intoSplit: split.id, replacing: id("a3"))
        #expect(made)

        let regrouped = try #require(strip.split(containing: id("a2")))
        #expect(regrouped.id == split.id)
        #expect(regrouped.spansProjects)
        #expect(names(strip) == ["a1", "a3", "a2", "b1"])
        #expect(strip.groupKeys == ["/a", "/a", regrouped.groupKey, regrouped.groupKey])
        #expect(strip.sides(of: regrouped) == TerminalSplit.Sides(left: id("a2"), right: id("b1")))
        expectSplitRules(strip)
    }

    @Test func aSplitTakesNoTabOfItsProjectsOutOfTheirGroups() throws {
        var strip = makeStrip("a1", "a2", "b1", "b2")
        let splitResult = strip.addSplit(joining: id("b1"), beside: id("a1"))
        let split = try #require(splitResult)

        #expect(strip.movingUnits(inGroup: "/a") == [[id("a2")]])
        #expect(strip.movingUnits(inGroup: "/b") == [[id("b2")]])
        #expect(strip.movingUnits(inGroup: split.groupKey) == [[id("a1"), id("b1")]])
        #expect(strip.groupKeysInOrder == ["/a", split.groupKey, "/b"])
    }

    // MARK: - Closing and opening

    @Test func removingATabOfASplitSendsTheOtherBackToItsProject() throws {
        var strip = makeStrip("a1", "a2", "b1", "b2")
        let added = strip.addSplit(joining: id("b1"), beside: id("a1"))
        #expect(added != nil)
        #expect(names(strip) == ["a2", "a1", "b1", "b2"])

        strip.removeTab(id("a1"))

        #expect(names(strip) == ["a2", "b2", "b1"])
        #expect(strip.groupKeys == ["/a", "/b", "/b"])
        #expect(strip.splits.isEmpty)
        expectSplitRules(strip)
    }

    @Test func removingATabOfASplitLeavesTheOtherInPlaceWhenItsProjectHasNoOtherTab() throws {
        var strip = makeStrip("a1", "b1", "c1")
        let added = strip.addSplit(joining: id("b1"), beside: id("a1"))
        #expect(added != nil)

        strip.removeTab(id("b1"))

        #expect(names(strip) == ["a1", "c1"])
        #expect(strip.splits.isEmpty)
        expectSplitRules(strip)
    }

    @Test func aNewTabOpensAfterASplitAtTheEndOfItsGroup() throws {
        var strip = makeStrip("a1", "a2", "a3", "b1")
        let added = strip.addSplit(joining: id("a3"), beside: id("a2"))
        #expect(added != nil)
        #expect(names(strip) == ["a1", "a2", "a3", "b1"])

        #expect(strip.insertionIndex(forNewTabOfProject: "/a") == 3)
        #expect(strip.insertionIndex(forNewTabOfProject: "/b") == 4)
    }

    @Test func aNewTabOpensAfterItsProjectsGroupNotBesideASplitAcrossProjects() throws {
        var strip = makeStrip("a1", "a2", "b1", "c1")
        let added = strip.addSplit(joining: id("b1"), beside: id("a2"))
        #expect(added != nil)
        #expect(names(strip) == ["a1", "a2", "b1", "c1"])

        #expect(strip.insertionIndex(forNewTabOfProject: "/a") == 1)
        #expect(strip.insertionIndex(forNewTabOfProject: "/b") == 4)
        #expect(strip.insertionIndex(forNewTabOfProject: "/c") == 4)
    }

    @Test func aReopenedTabGoesToItsSavedPlaceUnlessThatIsAmongAnotherGroupsTabs() {
        let strip = makeStrip("a1", "a2", "b1")

        #expect(strip.insertionIndex(forReopenedTabOfProject: "/a", at: 0) == 0)
        #expect(strip.insertionIndex(forReopenedTabOfProject: "/a", at: 1) == 1)
        #expect(strip.insertionIndex(forReopenedTabOfProject: "/c", at: 2) == 2)
        #expect(strip.insertionIndex(forReopenedTabOfProject: "/c", at: 9) == 3)
        #expect(strip.insertionIndex(forReopenedTabOfProject: "/b", at: 1) == 3)
    }

    @Test func aReopenedTabNeverPartsASplitOrSitsInAnotherGroup() throws {
        var strip = makeStrip("a1", "a2", "b1", "b2")
        let added = strip.addSplit(joining: id("a2"), beside: id("a1"))
        #expect(added != nil)

        // Between the split's tabs, its own project's group or not.
        #expect(strip.insertionIndex(forReopenedTabOfProject: "/a", at: 1) == 2)
        #expect(strip.insertionIndex(forReopenedTabOfProject: "/c", at: 1) == 4)
        // Among another project's tabs.
        #expect(strip.insertionIndex(forReopenedTabOfProject: "/c", at: 3) == 4)
    }

    // MARK: - Helpers

    private let tabIDsByName: [String: UUID] = Dictionary(
        uniqueKeysWithValues: ["a", "b", "c"].flatMap { project in (1...4).map { ("\(project)\($0)", UUID()) } }
    )

    private func id(_ name: String) -> UUID {
        tabIDsByName[name]!
    }

    private func makeStrip(_ names: String..., splits: [TerminalSplit] = []) -> TerminalTabStrip {
        TerminalTabStrip(
            tabs: names.map { TerminalTabStrip.Tab(id: id($0), projectKey: "/" + String($0.prefix(1))) },
            splits: splits
        )
    }

    private func names(_ strip: TerminalTabStrip) -> [String] {
        strip.tabIDs.map { tabID in tabIDsByName.first { $0.value == tabID }!.key }
    }
}
