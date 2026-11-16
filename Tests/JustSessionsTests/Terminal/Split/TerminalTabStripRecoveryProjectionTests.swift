import Foundation
import Testing
@testable import JustSessions

struct TerminalTabStripRecoveryProjectionTests {
    @Test func splitTabsJoinAnExistingProjectsEndEvenWhenItsGroupIsLater() {
        let firstA = tab("a"), firstB = tab("b"), ordinaryA = tab("a"), ordinaryC = tab("c")
        let splitID = UUID()
        let split = TerminalSplit(id: splitID, tabIDs: (firstA.id, firstB.id), groupKey: TerminalSplit.groupKey(ofSplitAcrossProjects: splitID))
        let strip = TerminalTabStrip(tabs: [firstA, firstB, ordinaryC, ordinaryA], splits: [split])
        #expect(strip.tabsWithSplitsSeparated.map(\.id) == [firstB.id, ordinaryC.id, ordinaryA.id, firstA.id])
    }

    @Test func projectsWithoutOrdinaryGroupsStartAtTheirFirstSplit() {
        let a = tab("a"), b = tab("b"), c = tab("c"), anotherA = tab("a")
        let firstID = UUID(), secondID = UUID()
        let strip = TerminalTabStrip(tabs: [a, b, c, anotherA], splits: [
            TerminalSplit(id: firstID, tabIDs: (a.id, b.id), groupKey: TerminalSplit.groupKey(ofSplitAcrossProjects: firstID)),
            TerminalSplit(id: secondID, tabIDs: (c.id, anotherA.id), groupKey: TerminalSplit.groupKey(ofSplitAcrossProjects: secondID)),
        ])
        #expect(strip.tabsWithSplitsSeparated.map(\.id) == [a.id, anotherA.id, b.id, c.id])
    }

    @Test func recoveryOrderMatchesSeparatingEverySplitThroughRepeatedEdits() {
        for seed in 1...8 {
            var random = RecoveryRandom(seed: UInt64(seed))
            var strip = TerminalTabStrip(tabs: (0..<32).map { tab("p\($0 / 4)") })
            for step in 0..<80 {
                let tabs = strip.tabs
                switch random.next(7) {
                case 0:
                    _ = strip.addSplit(
                        joining: tabs[random.next(tabs.count)].id,
                        beside: tabs[random.next(tabs.count)].id,
                        on: random.next(2) == 0 ? .left : .right,
                        orientation: random.next(2) == 0 ? .stacked : .sideBySide
                    )
                case 1:
                    if !strip.splits.isEmpty { strip.separateSplit(strip.splits[random.next(strip.splits.count)].id) }
                case 2:
                    if !strip.splits.isEmpty {
                        let split = strip.splits[random.next(strip.splits.count)]
                        if let outgoing = strip.sides(of: split)?.left {
                            _ = strip.swap(tabs[random.next(tabs.count)].id, intoSplit: split.id, replacing: outgoing)
                        }
                    }
                case 3:
                    let tab = tabs[random.next(tabs.count)]
                    let count = strip.movingUnits(inGroup: strip.groupKey(of: tab)).count
                    strip.moveTab(tab.id, toPlaceInGroup: random.next(count + 1))
                case 4:
                    let groups = strip.groupKeysInOrder
                    strip.moveGroup(groups[random.next(groups.count)], toPlace: random.next(groups.count + 1))
                case 5:
                    if !strip.splits.isEmpty { strip.reverseSplit(strip.splits[random.next(strip.splits.count)].id) }
                default:
                    if !strip.splits.isEmpty {
                        let split = strip.splits[random.next(strip.splits.count)]
                        strip.setOrientation(split.orientation.toggled, ofSplit: split.id)
                    }
                }
                var reference = strip
                reference.separateAllSplits()
                #expect(strip.tabsWithSplitsSeparated == reference.tabs, "seed \(seed), edit \(step)")
            }
        }
    }

    private func tab(_ project: String) -> TerminalTabStrip.Tab { .init(id: UUID(), projectKey: project) }
}

private struct RecoveryRandom {
    var seed: UInt64
    mutating func next(_ upperBound: Int) -> Int {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((seed >> 32) % UInt64(upperBound))
    }
}
