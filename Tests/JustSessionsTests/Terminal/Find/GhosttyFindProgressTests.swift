import Testing
@testable import JustSessions

/// Ghostty reports its total and its selected match separately, the selected one counted from 0 at the newest.
struct GhosttyFindProgressTests {
    @Test func numbersTheSelectedMatchFromOneAtTheNewest() {
        let progress = GhosttyFindProgress(total: 14, selectedIndexFromNewest: 0)
        #expect(progress.matchCount == TerminalFindMatchCount(total: 14, selectedNumber: 1, exceedsCountLimit: false))
        #expect(GhosttyFindProgress(total: 14, selectedIndexFromNewest: 13).matchCount?.selectedNumber == 14)
    }

    @Test func aTotalWithNothingSelectedHasNoNumber() {
        let matchCount = GhosttyFindProgress(total: 3, selectedIndexFromNewest: nil).matchCount
        #expect(matchCount == TerminalFindMatchCount(total: 3, selectedNumber: nil, exceedsCountLimit: false))
    }

    /// The two reports come one at a time, so a selection can briefly lie past a total that just went down.
    @Test func aSelectionPastTheTotalHasNoNumber() {
        #expect(GhosttyFindProgress(total: 2, selectedIndexFromNewest: 2).matchCount?.selectedNumber == nil)
    }

    @Test func noSearchCountsNothing() {
        #expect(GhosttyFindProgress().matchCount == nil)
        #expect(GhosttyFindProgress(total: nil, selectedIndexFromNewest: 0).matchCount == nil)
    }

    @Test func noMatches() {
        #expect(GhosttyFindProgress(total: 0, selectedIndexFromNewest: nil).matchCount == TerminalFindMatchCount.none)
    }
}
