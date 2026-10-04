import Foundation

/// Two open tabs linked side by side, as Chrome links a pair of split tabs: while either is selected, both terminals
/// show. Which shows on the left is not kept here: it is the one that comes first in the tab bar, as in Chrome, so
/// the panes can never disagree with the tabs. The split outlives the selection, so showing another tab and coming
/// back to either tab shows the split again.
struct TerminalSplit: Identifiable, Equatable {
    /// The split's two tabs by their places in the tab bar: the left pane's tab and the right pane's.
    struct Sides: Equatable {
        var left: UUID
        var right: UUID

        func tabID(on side: Side) -> UUID {
            side == .left ? left : right
        }

        /// The tab's side, or nil for a tab outside the split.
        func side(of tabID: UUID) -> Side? {
            switch tabID {
            case left: .left
            case right: .right
            default: nil
            }
        }
    }

    enum Side {
        case left, right
    }

    let id: UUID
    /// The two tabs, in no particular order.
    private(set) var tabIDs: Set<UUID>
    /// The tab group both tabs show in, by project key: the group of the tab the split was made from, so a tab from
    /// another project joins that tab's group while they are split, as Chrome moves it into the group.
    let groupKey: String

    init(id: UUID = UUID(), tabIDs: (UUID, UUID), groupKey: String) {
        precondition(tabIDs.0 != tabIDs.1, "A split links two different tabs")
        self.id = id
        self.tabIDs = [tabIDs.0, tabIDs.1]
        self.groupKey = groupKey
    }

    func contains(_ tabID: UUID) -> Bool {
        tabIDs.contains(tabID)
    }

    /// The other tab of the split, or nil for a tab outside it.
    func partner(of tabID: UUID) -> UUID? {
        guard contains(tabID) else { return nil }
        return tabIDs.first { $0 != tabID }
    }

    /// The split with `oldID`'s place handed to `newID`, as when a tab is swapped for another; the same split for a
    /// tab outside it.
    func replacing(_ oldID: UUID, with newID: UUID) -> TerminalSplit {
        guard let partner = partner(of: oldID), partner != newID else { return self }
        return TerminalSplit(id: id, tabIDs: (partner, newID), groupKey: groupKey)
    }
}
