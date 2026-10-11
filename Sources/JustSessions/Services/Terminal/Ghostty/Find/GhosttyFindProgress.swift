/// What Ghostty last reported of its search. Ghostty counts on a thread of its own and reports the total and the
/// selected match separately, so each report changes one of them.
struct GhosttyFindProgress: Equatable {
    /// The matches found so far, which rises while Ghostty reads the scrollback. Nil while no search runs.
    var total: Int?
    /// 0 for the newest match, the one the first move selects. Nil when none is selected: before the first move, and
    /// after Ghostty drops the selection, as on a resize.
    var selectedIndexFromNewest: Int?

    /// For the find bar, nil while no search runs. Ghostty counts every match, so there is no count limit.
    var matchCount: TerminalFindMatchCount? {
        guard let total else { return nil }
        let selectedNumber = selectedIndexFromNewest.flatMap { $0 < total ? $0 + 1 : nil }
        return TerminalFindMatchCount(total: total, selectedNumber: selectedNumber, exceedsCountLimit: false)
    }
}
