import Foundation
import Testing
@testable import JustSessions

/// A new pair shares a tab with the old one when one half was replaced or found a new partner, which keeps the
/// divider where it was; a pair of two other tabs shares none.
struct TerminalSplitPairTests {
    private let first = UUID()
    private let second = UUID()
    private let third = UUID()
    private let fourth = UUID()

    @Test func aPairWithOneHalfReplacedSharesTheOtherHalf() {
        let pair = TerminalSplitPair(leadingID: first, trailingID: second)
        #expect(pair.sharesTab(with: pair.replacing(second, with: third)))
        #expect(pair.sharesTab(with: pair.replacing(first, with: third)))
    }

    @Test func aSwappedPairSharesBothTabs() {
        let pair = TerminalSplitPair(leadingID: first, trailingID: second)
        #expect(pair.sharesTab(with: pair.swapped))
    }

    @Test func aTabOnTheOtherSideStillCountsAsShared() {
        let pair = TerminalSplitPair(leadingID: first, trailingID: second)
        #expect(pair.sharesTab(with: TerminalSplitPair(leadingID: third, trailingID: first)))
    }

    @Test func twoOtherTabsShareNothing() {
        let pair = TerminalSplitPair(leadingID: first, trailingID: second)
        #expect(!pair.sharesTab(with: TerminalSplitPair(leadingID: third, trailingID: fourth)))
    }
}
