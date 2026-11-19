struct TerminalFindMatchCount: Equatable {
    let total: Int
    let selectedNumber: Int?
    let exceedsCountLimit: Bool

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
