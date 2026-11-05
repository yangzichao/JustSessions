import Foundation
import Testing
@testable import JustSessions

/// A split keeps its own layout through the tab strip's rules, which rebuild it as they swap or regroup its tabs
/// (SPL-18). Tabs are named by their project's letter and a number, such as `a1`.
struct TerminalTabStripOrientationTests {
    @Test func aSplitOpensInTheLayoutAskedFor() throws {
        var strip = makeStrip("a1", "a2")

        let added = strip.addSplit(joining: id("a2"), beside: id("a1"), orientation: .stacked)

        #expect(try #require(added).orientation == .stacked)
        #expect(strip.splits.map(\.orientation) == [.stacked])
    }

    @Test func aSplitIsSideBySideUnlessAskedOtherwise() throws {
        var strip = makeStrip("a1", "a2")

        let added = strip.addSplit(joining: id("a2"), beside: id("a1"))

        #expect(try #require(added).orientation == .sideBySide)
    }

    @Test func settingTheLayoutKeepsTheTabsWhereTheyAre() throws {
        var strip = makeStrip("a1", "a2", "a3")
        let added = strip.addSplit(joining: id("a3"), beside: id("a2"))
        let split = try #require(added)

        strip.setOrientation(.stacked, ofSplit: split.id)

        #expect(strip.split(containing: id("a2"))?.orientation == .stacked)
        #expect(names(strip) == ["a1", "a2", "a3"])
        strip.setOrientation(.sideBySide, ofSplit: split.id)
        #expect(strip.split(containing: id("a2"))?.orientation == .sideBySide)
    }

    @Test func aReversedSplitStaysStacked() throws {
        var strip = makeStrip("a1", "a2")
        let added = strip.addSplit(joining: id("a2"), beside: id("a1"), orientation: .stacked)
        let split = try #require(added)

        strip.reverseSplit(split.id)

        #expect(strip.split(containing: id("a1"))?.orientation == .stacked)
    }

    @Test func aTabSwappedIntoAStackedSplitOfItsProjectKeepsItStacked() throws {
        var strip = makeStrip("a1", "a2", "a3")
        let added = strip.addSplit(joining: id("a2"), beside: id("a1"), orientation: .stacked)
        let split = try #require(added)

        let swapped = strip.swap(id("a3"), intoSplit: split.id, replacing: id("a2"))
        #expect(swapped)

        #expect(strip.split(containing: id("a3"))?.orientation == .stacked)
    }

    @Test func aSwapThatRegroupsAStackedSplitKeepsItStacked() throws {
        var strip = makeStrip("a1", "a2", "a3", "b1")
        let added = strip.addSplit(joining: id("a3"), beside: id("a2"), orientation: .stacked)
        let split = try #require(added)

        let swapped = strip.swap(id("b1"), intoSplit: split.id, replacing: id("a3"))
        #expect(swapped)

        let regrouped = try #require(strip.split(containing: id("b1")))
        #expect(regrouped.spansProjects)
        #expect(regrouped.orientation == .stacked)
        expectSplitRules(strip)
    }

    // MARK: - Helpers

    private let tabIDsByName: [String: UUID] = Dictionary(
        uniqueKeysWithValues: ["a", "b"].flatMap { project in (1...3).map { ("\(project)\($0)", UUID()) } }
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
