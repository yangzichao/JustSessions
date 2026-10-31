import Foundation

/// Two open tabs linked side by side, or one above the other, as Chrome links a pair of split tabs: while either is
/// selected, both terminals show. Which shows on the left, or on top, is not kept here: it is the one that comes first
/// in the tab bar, as in Chrome, so the panes can never disagree with the tabs. How the two are laid out is kept by the
/// store, by split id; see `ConversationStore.orientation(ofSplitView:)`. The split outlives the selection, so showing another tab and coming
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

    /// A split's first and second views: left and right side by side, or top and bottom when stacked.
    enum Side {
        case left, right
    }

    /// How a split's two views share the terminals: side by side, as in Chrome, or one above the other, as a terminal
    /// app stacks a pane below another. A split stays two views either way; see DNR-15.
    enum Orientation: Equatable {
        case sideBySide, stacked

        var toggled: Orientation {
            self == .sideBySide ? .stacked : .sideBySide
        }
    }

    private static let groupKeyPrefixOfSplitsAcrossProjects = "split-view:"

    let id: UUID
    /// The two tabs, in no particular order.
    private(set) var tabIDs: Set<UUID>
    /// The tab group both tabs show in: their project's, by its key, while both are of one project. A split across
    /// two projects shows in neither project's group but as a unit of its own among the groups, under a key of its
    /// own; see `groupKey(ofSplitAcrossProjects:)` and `TerminalTabStrip`.
    let groupKey: String

    init(id: UUID = UUID(), tabIDs: (UUID, UUID), groupKey: String) {
        precondition(tabIDs.0 != tabIDs.1, "A split links two different tabs")
        self.id = id
        self.tabIDs = [tabIDs.0, tabIDs.1]
        self.groupKey = groupKey
    }

    /// The group key of the split across two projects with this id, which no project key equals: project keys are
    /// folder paths or `ssh://` keys, see `ProjectLocation`.
    static func groupKey(ofSplitAcrossProjects id: UUID) -> String {
        groupKeyPrefixOfSplitsAcrossProjects + id.uuidString
    }

    /// Whether the group key is a split's own rather than a project's.
    static func isGroupKeyOfSplitAcrossProjects(_ groupKey: String) -> Bool {
        groupKey.hasPrefix(groupKeyPrefixOfSplitsAcrossProjects)
    }

    /// Whether the split's two tabs are of different projects, so it shows as a unit of its own among the groups.
    var spansProjects: Bool {
        groupKey == Self.groupKey(ofSplitAcrossProjects: id)
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

    /// The same split, showing in the group `groupKey`.
    func regrouped(into groupKey: String) -> TerminalSplit {
        let tabIDs = Array(tabIDs)
        return TerminalSplit(id: id, tabIDs: (tabIDs[0], tabIDs[1]), groupKey: groupKey)
    }
}
