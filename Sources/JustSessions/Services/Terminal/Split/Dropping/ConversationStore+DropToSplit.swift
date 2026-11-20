import Foundation

extension ConversationStore {
    func canShowDroppedTabs(_ tabIDs: [UUID]) -> Bool {
        guard tabIDs.count == 1, let tabID = tabIDs.first, let selectedTerminalID, tabID != selectedTerminalID else { return false }
        return !isInSplitOrChooser(tabID)
    }

    func showDroppedTab(_ tabID: UUID, at place: TerminalDropPlace) {
        switch place {
        case .split(let side, let orientation):
            showDroppedTabInSplit(tabID, on: side, orientation: orientation)
        case .wholeArea:
            guard canShowDroppedTabs([tabID]) else { return }
            selectTerminal(tabID)
        }
    }

    func showDroppedTabInSplit(_ tabID: UUID, on side: TerminalSplit.Side, orientation: TerminalSplit.Orientation = .sideBySide) {
        guard canShowDroppedTabs([tabID]) else { return }
        if isSplitViewShown {
            moveIntoShownSplitView(tabID, on: side)
        } else {
            splitSelectedTerminal(with: tabID, on: .fixed(side), orientation: orientation)
        }
        selectTerminal(tabID)
    }
}
