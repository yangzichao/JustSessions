import Foundation
import Testing
@testable import JustSessions

/// A tab dragged to another window leaves its tab bar as a closed tab does, though a split goes whole, and joins the
/// other bar among its group's tabs, or as a new group. Tabs are named by their project's letter and a number, such
/// as `a1`.
struct TerminalTabStripBetweenWindowsTests {
    // MARK: - Taking out

    @Test func aTabLeavesItsTabBarAsWhenItCloses() throws {
        var strip = makeStrip("a1", "a2", "b1")

        let takenOut = strip.takeOutForAnotherWindow([id("a1")])

        let unit = try #require(takenOut)

        #expect(names(strip) == ["a2", "b1"])
        #expect(unit.tabs.map(\.id) == [id("a1")])
        #expect(unit.split == nil)
        #expect(unit.groupKey == "/a")
        expectSplitRules(strip)
    }

    @Test func aSplitLeavesWholeWithBothItsTabs() throws {
        var strip = makeStrip("a1", "a2", "b1", "b2")
        let added = strip.addSplit(joining: id("b1"), beside: id("a1"))
        let split = try #require(added)
        #expect(names(strip) == ["a1", "b1", "a2", "b2"])

        let takenOut = strip.takeOutForAnotherWindow([id("a1"), id("b1")])

        let unit = try #require(takenOut)

        #expect(names(strip) == ["a2", "b2"])
        #expect(strip.splits.isEmpty)
        #expect(unit.tabs.map(\.id) == [id("a1"), id("b1")])
        #expect(unit.split == split)
        #expect(unit.groupKey == "/a")
        expectSplitRules(strip)
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

    /// The split's group may be named for another tab's project, which stays behind; the split then shows in its left
    /// tab's project, as when that other tab closes.
    @Test func aSplitShowingInAnotherTabsGroupTakesItsLeftTabsProject() throws {
        let split = TerminalSplit(tabIDs: (id("b1"), id("c1")), groupKey: "/a")
        var strip = TerminalTabStrip(tabs: [tab("a1"), tab("b1"), tab("c1")], splits: [split])
        expectSplitRules(strip)

        let takenOut = strip.takeOutForAnotherWindow([id("b1"), id("c1")])

        let unit = try #require(takenOut)

        #expect(names(strip) == ["a1"])
        #expect(unit.groupKey == "/b")
    }

    /// Another split's group may be named for the leaving tab's project.
    @Test func aSplitLeftInAGroupOfNoneOfItsProjectsMovesToItsLeftTabsProject() throws {
        let split = TerminalSplit(tabIDs: (id("b1"), id("c1")), groupKey: "/a")
        var strip = TerminalTabStrip(tabs: [tab("a1"), tab("b1"), tab("c1"), tab("b2")], splits: [split])

        let takenOut = strip.takeOutForAnotherWindow([id("a1")])

        _ = try #require(takenOut)

        #expect(names(strip) == ["b2", "b1", "c1"])
        #expect(strip.splits.map(\.groupKey) == ["/b"])
        expectSplitRules(strip)
    }

    // MARK: - Bringing in

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
        var source = makeStrip("a1", "b1")
        let added = source.addSplit(joining: id("b1"), beside: id("a1"))
        let split = try #require(added)
        var target = makeStrip("a2", "c1")
        let takenOut = source.takeOutForAnotherWindow([id("a1"), id("b1")])
        let unit = try #require(takenOut)

        target.bringIn(unit, at: .amongGroupTabs(0))

        #expect(names(target) == ["a1", "b1", "a2", "c1"])
        #expect(target.splits == [split])
        #expect(target.sides(of: split) == TerminalSplit.Sides(left: id("a1"), right: id("b1")))
        expectSplitRules(target)
    }

    @Test func aSplitThatLeftAnotherTabsGroupArrivesInItsLeftTabsProject() throws {
        let split = TerminalSplit(tabIDs: (id("b1"), id("c1")), groupKey: "/a")
        var source = TerminalTabStrip(tabs: [tab("a1"), tab("b1"), tab("c1")], splits: [split])
        var target = makeStrip("a2", "b2")
        let takenOut = source.takeOutForAnotherWindow([id("b1"), id("c1")])
        let unit = try #require(takenOut)

        target.bringIn(unit, at: .amongGroupTabs(1))

        #expect(names(target) == ["a2", "b2", "b1", "c1"])
        #expect(target.splits.map(\.groupKey) == ["/b"])
        expectSplitRules(target)
    }

    // MARK: - Helpers

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
