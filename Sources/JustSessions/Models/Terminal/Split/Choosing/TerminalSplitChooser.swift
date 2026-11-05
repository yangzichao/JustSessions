import Foundation

/// A split whose other view is still to be chosen, as Chrome's split view new tab page: Add Tab to New Split View (⌘⌥N)
/// shows the selected tab beside a list of the window's other tabs, and the tab chosen there takes the list's place in
/// the split. Unlike Chrome's page, the list is no tab of its own: the tab beside it holds it, so the tab bar draws the
/// two as one split tab, and the list closes with that tab.
struct TerminalSplitChooser: Identifiable, Equatable {
    /// The id the split takes once a tab is chosen, so its panes keep their widths, as Chrome keeps a split's sizes.
    let id: UUID
    /// The tab shown beside the list.
    var tabID: UUID
    /// The list's side; the tab shows on the other.
    var side: TerminalSplit.Side
    /// How the tab and the list share the area; the split the chooser becomes takes it.
    var orientation: TerminalSplit.Orientation

    init(id: UUID = UUID(), tabID: UUID, side: TerminalSplit.Side = .right, orientation: TerminalSplit.Orientation = .sideBySide) {
        self.id = id
        self.tabID = tabID
        self.side = side
        self.orientation = orientation
    }

    /// The side the tab beside the list shows on.
    var tabSide: TerminalSplit.Side {
        side == .left ? .right : .left
    }

    /// The tabs the list offers, as Chrome's split view page lists them: the window's open tabs that are off screen, in
    /// no split, and beside no list of their own, the one selected last first, as Chrome sorts by when a tab was last
    /// active, then those never selected, in tab bar order.
    /// - Parameters:
    ///   - tabIDs: the open tabs, in tab bar order.
    ///   - tabIDsByLastSelected: tabs by when they were last selected, the latest first.
    ///   - isAvailable: whether a tab is off screen, in no split, and beside no list.
    static func candidates(
        amongTabs tabIDs: [UUID],
        byLastSelected tabIDsByLastSelected: [UUID],
        isAvailable: (UUID) -> Bool
    ) -> [UUID] {
        let openTabIDs = Set(tabIDs)
        let selectedBefore = tabIDsByLastSelected.filter { openTabIDs.contains($0) }
        let neverSelected = tabIDs.filter { !selectedBefore.contains($0) }
        return (selectedBefore + neverSelected).filter(isAvailable)
    }
}
