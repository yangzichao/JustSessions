import Foundation
import Testing

@testable import JustSessions

struct TerminalSplitChooserTests {
    private let a = UUID(), b = UUID(), c = UUID(), d = UUID()

    @Test func tabsSelectedBeforeComeFirstTheLatestFirstThenTheRestInTabBarOrder() {
        let candidates = TerminalSplitChooser.candidates(amongTabs: [a, b, c, d], byLastSelected: [c, a]) { _ in true }

        #expect(candidates == [c, a, b, d])
    }

    @Test func tabsItCannotShowAndClosedTabsAreLeftOut() {
        let closed = UUID()

        let candidates = TerminalSplitChooser.candidates(amongTabs: [a, b, c, d], byLastSelected: [closed, d, a]) { $0 != a }

        #expect(candidates == [d, b, c])
    }

    @Test func theTabShowsOnTheChoosersOtherSide() {
        #expect(TerminalSplitChooser(tabID: a).tabSide == .left)
        #expect(TerminalSplitChooser(tabID: a, side: .left).tabSide == .right)
    }
}
