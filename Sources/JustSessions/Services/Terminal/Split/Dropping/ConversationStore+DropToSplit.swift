import Foundation

/// A tab dragged onto the terminals and let go there shows where it was let go: in a split view on that side, or on its
/// own in place of the shown tab; see `TerminalSplitDropArea` for the places and `TabDragBetweenWindows` for the drag.
extension ConversationStore {
    /// Whether tabs dragged here, from this window's tab bar or another's, can show on the terminals: one tab in no
    /// split and beside no split chooser, while a tab other than itself is selected. A split's two tabs drag together,
    /// and a split view shows two panes.
    func canShowDroppedTabs(_ tabIDs: [UUID]) -> Bool {
        guard tabIDs.count == 1, let tabID = tabIDs.first, let selectedTerminalID, tabID != selectedTerminalID else { return false }
        return !isInSplitOrChooser(tabID)
    }

    /// Shows the tab, open here in no split, at `place` and selects it: in a split view on that side, or on its own,
    /// full width, the shown tab staying open behind it.
    func showDroppedTab(_ tabID: UUID, at place: TerminalDropPlace) {
        switch place {
        case .split(let side, let orientation):
            showDroppedTabInSplit(tabID, on: side, orientation: orientation)
        case .wholeArea:
            guard canShowDroppedTabs([tabID]) else { return }
            selectTerminal(tabID)
        }
    }

    /// Shows the tab, open here in no split, on `side` of a split view, and selects it: beside the selected tab in a new
    /// split laid out as `orientation`, or, while the selected tab is in a split or beside a split chooser, in place of
    /// the view on `side`, as Move tab into split view does, the split keeping its own layout.
    func showDroppedTabInSplit(_ tabID: UUID, on side: TerminalSplit.Side, orientation: TerminalSplit.Orientation = .sideBySide) {
        guard canShowDroppedTabs([tabID]) else { return }
        if isSplitViewShown {
            moveIntoShownSplitView(tabID, on: side)
        } else {
            splitSelectedTerminal(with: tabID, on: side, orientation: orientation)
        }
        selectTerminal(tabID)
    }
}
