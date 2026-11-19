/// How many matches a terminal's find counted, and which one is selected, for the find bar's "2 of 14". Matches are
/// numbered from the newest, the one a search selects first, so moving toward older output counts up.
struct TerminalFindMatchCount: Equatable {
    /// The matches counted, at most `countLimit`.
    let total: Int
    /// The selected match's number, 1 for the newest. Nil when none is selected, as after new output cleared the
    /// selection, or when there are more matches than were counted.
    let selectedNumber: Int?
    /// More matches than the count goes to.
    let exceedsCountLimit: Bool

    /// Counting stops here, so a one-letter search through a long scrollback stays quick.
    static let countLimit = 5_000

    static let none = TerminalFindMatchCount(total: 0, selectedNumber: nil, exceedsCountLimit: false)

    /// From a count made from the oldest line down, as SwiftTerm counts: `selectedIndexFromOldest` is 1 for the
    /// oldest match and 0 when none is selected. With more matches than `countLimit`, the newest are past the count,
    /// so the selected one has no number.
    init(countedFromOldest total: Int, selectedIndexFromOldest: Int) {
        let exceedsCountLimit = total >= Self.countLimit
        self.total = total
        self.exceedsCountLimit = exceedsCountLimit
        selectedNumber =
            !exceedsCountLimit && selectedIndexFromOldest >= 1 && selectedIndexFromOldest <= total
            ? total - selectedIndexFromOldest + 1
            : nil
    }

    init(total: Int, selectedNumber: Int?, exceedsCountLimit: Bool) {
        self.total = total
        self.selectedNumber = selectedNumber
        self.exceedsCountLimit = exceedsCountLimit
    }
}
