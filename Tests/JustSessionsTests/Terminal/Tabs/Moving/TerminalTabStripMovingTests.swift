import Foundation
import Testing
@testable import JustSessions

/// Dragging tabs in the tab bar keeps the order's rules: a tab moves only among its group's tabs, a split's two tabs
/// move together, and a group moves whole. Tabs are named by their project's letter and a number, such as `a1`.
struct TerminalTabStripMovingTests {
    // MARK: - Tabs

    @Test func aTabMovesAmongItsGroupsTabs() {
        var strip = makeStrip("a1", "a2", "a3", "b1")

        strip.moveTab(id("a1"), toPlaceInGroup: 2)
        #expect(names(strip) == ["a2", "a3", "a1", "b1"])

        strip.moveTab(id("a1"), toPlaceInGroup: 0)
        #expect(names(strip) == ["a1", "a2", "a3", "b1"])
        expectSplitRules(strip)
    }

    @Test func aTabNeverLeavesItsGroup() {
        var strip = makeStrip("a1", "a2", "b1", "b2", "c1")

        strip.moveTab(id("b1"), toPlaceInGroup: 9)
        #expect(names(strip) == ["a1", "a2", "b2", "b1", "c1"])

        strip.moveTab(id("b1"), toPlaceInGroup: -3)
        #expect(names(strip) == ["a1", "a2", "b1", "b2", "c1"])
        expectSplitRules(strip)
    }

    @Test func aSplitsGroupCountsItsTwoTabsAsOne() throws {
        var strip = makeStrip("a1", "a2", "a3", "b1")
        let added = strip.addSplit(joining: id("a3"), beside: id("a1"))
        #expect(added != nil)
        #expect(names(strip) == ["a1", "a3", "a2", "b1"])

        #expect(strip.movingUnits(inGroup: "/a") == [[id("a1"), id("a3")], [id("a2")]])
        #expect(strip.movingUnits(inGroup: "/b") == [[id("b1")]])
    }

    @Test func draggingEitherTabOfASplitMovesBothKeepingTheirSides() throws {
        var strip = makeStrip("a1", "a2", "a3")
        let added = strip.addSplit(joining: id("a2"), beside: id("a1"))
        let split = try #require(added)

        strip.moveTab(id("a2"), toPlaceInGroup: 1)

        #expect(names(strip) == ["a3", "a1", "a2"])
        #expect(strip.sides(of: split) == TerminalSplit.Sides(left: id("a1"), right: id("a2")))
        expectSplitRules(strip)
    }

    @Test func aTabMovesPastASplitWithoutPartingIt() throws {
        var strip = makeStrip("a1", "a2", "a3")
        let added = strip.addSplit(joining: id("a3"), beside: id("a2"))
        #expect(added != nil)

        strip.moveTab(id("a1"), toPlaceInGroup: 1)

        #expect(names(strip) == ["a2", "a3", "a1"])
        expectSplitRules(strip)
    }

    @Test func aSplitTabFromAnotherProjectMovesWithinTheSplitsGroup() throws {
        var strip = makeStrip("a1", "a2", "b1", "b2")
        let added = strip.addSplit(joining: id("b2"), beside: id("a1"))
        #expect(added != nil)
        #expect(names(strip) == ["a1", "b2", "a2", "b1"])

        strip.moveTab(id("b2"), toPlaceInGroup: 1)

        #expect(names(strip) == ["a2", "a1", "b2", "b1"])
        #expect(strip.groupKeys == ["/a", "/a", "/a", "/b"])
        expectSplitRules(strip)
    }

    // MARK: - Groups

    @Test func aGroupMovesWholeAmongTheGroups() {
        var strip = makeStrip("a1", "a2", "b1", "c1")

        strip.moveGroup("/c", toPlace: 0)
        #expect(names(strip) == ["c1", "a1", "a2", "b1"])
        #expect(strip.groupKeysInOrder == ["/c", "/a", "/b"])

        strip.moveGroup("/c", toPlace: 9)
        #expect(names(strip) == ["a1", "a2", "b1", "c1"])
        expectSplitRules(strip)
    }

    @Test func aGroupCarriesASplitTabFromAnotherProject() throws {
        var strip = makeStrip("a1", "a2", "b1", "b2")
        let added = strip.addSplit(joining: id("b2"), beside: id("a1"))
        let split = try #require(added)

        strip.moveGroup("/a", toPlace: 1)

        #expect(names(strip) == ["b1", "a1", "b2", "a2"])
        #expect(strip.sides(of: split) == TerminalSplit.Sides(left: id("a1"), right: id("b2")))
        expectSplitRules(strip)
    }

    @Test func movingATabOrGroupThatIsNotOpenChangesNothing() {
        var strip = makeStrip("a1", "b1")
        let before = strip

        strip.moveTab(UUID(), toPlaceInGroup: 0)
        strip.moveGroup("/z", toPlace: 0)

        #expect(strip == before)
    }

    // MARK: - Helpers

    private let tabIDsByName: [String: UUID] = Dictionary(
        uniqueKeysWithValues: ["a", "b", "c"].flatMap { project in (1...4).map { ("\(project)\($0)", UUID()) } }
    )

    private func id(_ name: String) -> UUID {
        tabIDsByName[name]!
    }

    private func makeStrip(_ names: String...) -> TerminalTabStrip {
        TerminalTabStrip(tabs: names.map { TerminalTabStrip.Tab(id: id($0), projectKey: "/" + String($0.prefix(1))) })
    }

    private func names(_ strip: TerminalTabStrip) -> [String] {
        strip.tabIDs.map { tabID in tabIDsByName.first { $0.value == tabID }!.key }
    }
}
