import Foundation

/// Two open tabs linked side by side, as Chrome links a pair of split tabs: while either is selected, both
/// terminals show, with `leadingID` on the left. The pair outlives the selection, so showing another tab and
/// coming back to either half shows the split again.
struct TerminalSplitPair: Equatable {
    var leadingID: UUID
    var trailingID: UUID

    func contains(_ id: UUID) -> Bool {
        id == leadingID || id == trailingID
    }

    /// Either tab of this pair is also in `other`, as when one half was replaced and the other stayed.
    func sharesTab(with other: TerminalSplitPair) -> Bool {
        other.contains(leadingID) || other.contains(trailingID)
    }

    /// The other half of the pair, or nil for a tab outside it.
    func counterpart(of id: UUID) -> UUID? {
        switch id {
        case leadingID: trailingID
        case trailingID: leadingID
        default: nil
        }
    }

    /// The pair with its panes trading sides.
    var swapped: TerminalSplitPair {
        TerminalSplitPair(leadingID: trailingID, trailingID: leadingID)
    }

    /// The pair with `oldID`'s half handed to `newID`, as when a tab is swapped for another in its place.
    func replacing(_ oldID: UUID, with newID: UUID) -> TerminalSplitPair {
        TerminalSplitPair(
            leadingID: leadingID == oldID ? newID : leadingID,
            trailingID: trailingID == oldID ? newID : trailingID
        )
    }
}
