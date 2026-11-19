import Foundation
import Testing

@testable import JustSessions

struct TerminalTabStripBetweenWindowsTests {
    @Test func aTabLeavesItsTabBarAsWhenItCloses() throws {
        var strip = makeStrip("a1", "a2", "b1")

        let takenOut = strip.takeOutForAnotherWindow([id("a1")])

        let unit = try #require(takenOut)

        #expect(names(strip) == ["a2", "b1"])
        #expect(unit.tabs.map(\.id) == [id("a1")])
        #expect(unit.splits.isEmpty)
        #expect(unit.groupKey == "/a")
        expectSplitRules(strip)
    }

    @Test func aSplitLeavesWholeWithBothItsTabs() throws {
        var strip = makeStrip("a1", "a2", "b1", "b2")
        let added = strip.addSplit(joining: id("b1"), beside: id("a1"))
        let split = try #require(added)
        #expect(names(strip) == ["a2", "a1", "b1", "b2"])

        let takenOut = strip.takeOutForAnotherWindow([id("a1"), id("b1")])

        let unit = try #require(takenOut)

        #expect(names(strip) == ["a2", "b2"])
        #expect(strip.splits.isEmpty)
        #expect(unit.tabs.map(\.id) == [id("a1"), id("b1")])
        #expect(unit.splits == [split])
        #expect(unit.groupKey == split.groupKey)
        expectSplitRules(strip)
    }

    @Test func aSplitOfOneProjectLeavesWithItsProjectsGroup() throws {
        var strip = makeStrip("a1", "a2", "b1")
        let splitResult = strip.addSplit(joining: id("a2"), beside: id("a1"))
        let split = try #require(splitResult)

        let unitResult = strip.takeOutForAnotherWindow([id("a1"), id("a2")])

        let unit = try #require(unitResult)

        #expect(names(strip) == ["b1"])
        #expect(unit.splits == [split])
        #expect(unit.groupKey == "/a")
    }

    @Test func oneTabOfASplitCannotLeaveWithoutTheOther() throws {
        var strip = makeStrip("a1", "a2")
        let added = strip.addSplit(joining: id("a2"), beside: id("a1"))
        #expect(added != nil)
        let before = strip
        let takenOut = strip.takeOutForAnotherWindow([id("a1")])

        #expect(takenOut == nil)
        #expect(strip == before)
    }

    @Test func aSplitAcrossProjectsStaysPutWhenAnotherTabLeaves() throws {
        let split = splitAcrossProjects((id("b1"), id("c1")))
        var strip = TerminalTabStrip(tabs: [tab("a1"), tab("b1"), tab("c1"), tab("b2")], splits: [split])
        expectSplitRules(strip)

        let takenOut = strip.takeOutForAnotherWindow([id("a1")])

        _ = try #require(takenOut)

        #expect(names(strip) == ["b1", "c1", "b2"])
        #expect(strip.splits == [split])
        expectSplitRules(strip)
    }

    @Test func aWholeGroupLeavesWithItsSplits() throws {
        var strip = makeStrip("a1", "a2", "a3", "b1")
        let added = strip.addSplit(joining: id("a2"), beside: id("a1"))
        let split = try #require(added)

        let takenOut = strip.takeOutForAnotherWindow([id("a1"), id("a2"), id("a3")])

        let unit = try #require(takenOut)
        #expect(names(strip) == ["b1"])
        #expect(strip.splits.isEmpty)
        #expect(unit.tabs.map(\.id) == [id("a1"), id("a2"), id("a3")])
        #expect(unit.splits == [split])
        #expect(unit.groupKey == "/a")
    }

    @Test func tabsOfTwoGroupsCannotLeaveTogether() {
        var strip = makeStrip("a1", "b1")
        let before = strip

        let takenOut = strip.takeOutForAnotherWindow([id("a1"), id("b1")])

        #expect(takenOut == nil)
        #expect(strip == before)
    }

    @Test func aGroupCannotLeaveWithHalfASplit() throws {
        var strip = makeStrip("a1", "a2", "a3")
        let added = strip.addSplit(joining: id("a2"), beside: id("a1"))
        #expect(added != nil)
        let before = strip

        let takenOut = strip.takeOutForAnotherWindow([id("a1"), id("a3")])

        #expect(takenOut == nil)
        #expect(strip == before)
    }

    @Test func aTabJoinsItsGroupAtThePlaceItIsDroppedAt() throws {
        var source = makeStrip("a1", "b1")
        var target = makeStrip("a2", "a3", "c1")
        let takenOut = source.takeOutForAnotherWindow([id("a1")])
        let unit = try #require(takenOut)

        target.bringIn(unit, at: .amongGroupTabs(1))

        #expect(names(target) == ["a2", "a1", "a3", "c1"])
        expectSplitRules(target)
    }

    @Test func aTabWithNoGroupInTheOtherWindowStartsOneAtThePlaceItIsDroppedAt() throws {
        var source = makeStrip("a1", "b1")
        var target = makeStrip("b2", "c1")
        let takenOut = source.takeOutForAnotherWindow([id("a1")])
        let unit = try #require(takenOut)

        target.bringIn(unit, at: .asNewGroup(1))

        #expect(names(target) == ["b2", "a1", "c1"])
        expectSplitRules(target)
    }

    @Test func aWindowWithNoTabsTakesATabAsItsOnlyGroup() throws {
        var source = makeStrip("a1", "b1")
        var target = makeStrip()
        let takenOut = source.takeOutForAnotherWindow([id("b1")])
        let unit = try #require(takenOut)

        target.bringIn(unit, at: .asNewGroup(0))

        #expect(names(target) == ["b1"])
    }

    @Test func aSplitArrivesWholeInItsGroupKeepingItsSides() throws {
        var source = makeStrip("a1", "a3", "b1")
        let added = source.addSplit(joining: id("a3"), beside: id("a1"))
        let split = try #require(added)
        var target = makeStrip("a2", "c1")
        let takenOut = source.takeOutForAnotherWindow([id("a1"), id("a3")])
        let unit = try #require(takenOut)

        target.bringIn(unit, at: .amongGroupTabs(0))

        #expect(names(target) == ["a1", "a3", "a2", "c1"])
        #expect(target.splits == [split])
        #expect(target.sides(of: split) == TerminalSplit.Sides(left: id("a1"), right: id("a3")))
        expectSplitRules(target)
    }

    @Test func aSplitAcrossProjectsArrivesAsAGroupOfItsOwnAtThePlaceItIsDroppedAt() throws {
        var source = makeStrip("a1", "b1")
        let splitResult = source.addSplit(joining: id("b1"), beside: id("a1"))
        let split = try #require(splitResult)
        var target = makeStrip("a2", "c1")
        let unitResult = source.takeOutForAnotherWindow([id("a1"), id("b1")])
        let unit = try #require(unitResult)

        target.bringIn(unit, at: .asNewGroup(1))

        #expect(names(target) == ["a2", "a1", "b1", "c1"])
        #expect(target.splits == [split])
        #expect(target.groupKeysInOrder == ["/a", split.groupKey, "/c"])
        #expect(target.sides(of: split) == TerminalSplit.Sides(left: id("a1"), right: id("b1")))
        expectSplitRules(target)
    }

    @Test func aWholeGroupWithNoGroupInTheOtherWindowArrivesAsAGroupAtThePlaceItIsDroppedAt() throws {
        var source = makeStrip("a1", "a2", "b1")
        var target = makeStrip("b2", "c1")
        let takenOut = source.takeOutForAnotherWindow([id("a1"), id("a2")])
        let unit = try #require(takenOut)

        target.bringIn(unit, at: .asNewGroup(1))

        #expect(names(source) == ["b1"])
        #expect(names(target) == ["b2", "a1", "a2", "c1"])
        expectSplitRules(target)
    }

    @Test func aWholeGroupJoinsItsProjectsTabsTogetherKeepingItsSplit() throws {
        var source = makeStrip("a1", "a2", "a3", "b1")
        let added = source.addSplit(joining: id("a2"), beside: id("a1"))
        let split = try #require(added)
        var target = makeStrip("a4", "c1")
        let takenOut = source.takeOutForAnotherWindow([id("a1"), id("a2"), id("a3")])
        let unit = try #require(takenOut)

        target.bringIn(unit, at: .amongGroupTabs(0))

        #expect(names(target) == ["a1", "a2", "a3", "a4", "c1"])
        #expect(target.splits == [split])
        #expect(target.sides(of: split) == TerminalSplit.Sides(left: id("a1"), right: id("a2")))
        #expect(
            target.movingUnits(inGroup: "/a", keepingTogether: unit.tabs.map(\.id)) == [
                [id("a1"), id("a2"), id("a3")], [id("a4")],
            ])
        expectSplitRules(target)
    }

    @Test func aGroupJoinedWithItsProjectsTabsMovesAndLeavesTogether() throws {
        var source = makeStrip("a1", "a2", "b1")
        var target = makeStrip("a3", "a4", "c1")
        let takenOut = source.takeOutForAnotherWindow([id("a1"), id("a2")])
        let unit = try #require(takenOut)
        target.bringIn(unit, at: .amongGroupTabs(1))
        #expect(names(target) == ["a3", "a1", "a2", "a4", "c1"])

        target.moveTabs([id("a1"), id("a2")], toPlaceInGroup: 2)
        #expect(names(target) == ["a3", "a4", "a1", "a2", "c1"])

        let takenOutAgain = target.takeOutForAnotherWindow([id("a1"), id("a2")])
        #expect(takenOutAgain?.tabs.map(\.id) == [id("a1"), id("a2")])
        #expect(names(target) == ["a3", "a4", "c1"])
    }

    private let tabIDsByName: [String: UUID] = Dictionary(
        uniqueKeysWithValues: ["a", "b", "c"].flatMap { project in (1...4).map { ("\(project)\($0)", UUID()) } }
    )

    private func id(_ name: String) -> UUID {
        tabIDsByName[name]!
    }

    private func tab(_ name: String) -> TerminalTabStrip.Tab {
        TerminalTabStrip.Tab(id: id(name), projectKey: "/" + String(name.prefix(1)))
    }

    private func makeStrip(_ names: String...) -> TerminalTabStrip {
        TerminalTabStrip(tabs: names.map(tab))
    }

    private func names(_ strip: TerminalTabStrip) -> [String] {
        strip.tabIDs.map { tabID in tabIDsByName.first { $0.value == tabID }!.key }
    }
}
