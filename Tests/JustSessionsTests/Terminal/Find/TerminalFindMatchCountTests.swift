import Testing

@testable import JustSessions

struct TerminalFindMatchCountTests {
    /// SwiftTerm counts from the oldest line down; the bar numbers from the newest, the match a search selects first.
    @Test func numbersMatchesFromTheNewest() {
        #expect(TerminalFindMatchCount(countedFromOldest: 14, selectedIndexFromOldest: 14).selectedNumber == 1)
        #expect(TerminalFindMatchCount(countedFromOldest: 14, selectedIndexFromOldest: 13).selectedNumber == 2)
        #expect(TerminalFindMatchCount(countedFromOldest: 14, selectedIndexFromOldest: 1).selectedNumber == 14)
    }

    @Test func noSelectedMatchHasNoNumber() {
        let count = TerminalFindMatchCount(countedFromOldest: 3, selectedIndexFromOldest: 0)
        #expect(count.total == 3)
        #expect(count.selectedNumber == nil)
        #expect(!count.exceedsCountLimit)
    }

    @Test func noMatches() {
        #expect(TerminalFindMatchCount(countedFromOldest: 0, selectedIndexFromOldest: 0) == .none)
    }

    /// The newest matches lie past a count stopped at the limit, so the selected one can't be numbered from them.
    @Test func aCountStoppedAtTheLimitNumbersNoMatch() {
        let limit = TerminalFindMatchCount.countLimit
        let count = TerminalFindMatchCount(countedFromOldest: limit, selectedIndexFromOldest: 12)
        #expect(count.exceedsCountLimit)
        #expect(count.selectedNumber == nil)
        #expect(count.total == limit)
    }
}
