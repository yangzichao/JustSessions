import Foundation

extension ConversationStore {
    func orientation(ofSplitView id: UUID) -> TerminalSplit.Orientation {
        terminalSplits.first { $0.id == id }?.orientation
            ?? terminalSplitChoosers.first { $0.id == id }?.orientation
            ?? .sideBySide
    }

    var stackedSplitViewIDs: Set<UUID> {
        Set(
            terminalSplits.filter { $0.orientation == .stacked }.map(\.id)
                + terminalSplitChoosers.filter { $0.orientation == .stacked }.map(\.id))
    }

    func splitViewID(containing tabID: UUID) -> UUID? {
        split(containing: tabID)?.id ?? splitChooser(beside: tabID)?.id
    }

    var shownSplitViewID: UUID? {
        shownSplit?.id ?? shownSplitChooser?.id
    }

    var shownSplitOrientation: TerminalSplit.Orientation? {
        shownSplitViewID.map(orientation(ofSplitView:))
    }

    func setOrientation(_ orientation: TerminalSplit.Orientation, ofSplitView id: UUID) {
        if terminalSplits.contains(where: { $0.id == id }) {
            var strip = tabStrip
            strip.setOrientation(orientation, ofSplit: id)
            apply(strip)
        } else if let index = terminalSplitChoosers.firstIndex(where: { $0.id == id }) {
            if terminalSplitChoosers[index].orientation != orientation { terminalSplitChoosers[index].orientation = orientation }
        }
    }

    func rearrangeShownSplit(placing tabID: UUID, at place: TerminalDropPlace) {
        guard let shownSplit, shownSplit.contains(tabID) else { return }
        switch place {
        case .split(let side, let orientation):
            setOrientation(orientation, ofSplitView: shownSplit.id)
            if sides(of: shownSplit)?.side(of: tabID) != side { reverseSplit(shownSplit.id) }
            selectTerminal(tabID)
        case .wholeArea:
            selectTerminal(tabID)
            separateSplit(shownSplit.id)
        }
    }

    func openTabInNewSplit(on side: TerminalSplit.Side, orientation: TerminalSplit.Orientation, _ openTab: () -> Void) {
        let shownTabID = selectedTerminalID
        openTab()
        guard let shownTabID, let newTabID = selectedTerminalID, newTabID != shownTabID,
            !isInSplitOrChooser(shownTabID), !isInSplitOrChooser(newTabID)
        else { return }
        splitTerminal(shownTabID, with: newTabID, on: .fixed(side), orientation: orientation)
    }

    func splitTerminal(
        _ tabID: UUID,
        with id: UUID,
        on side: TerminalSplit.JoiningSide,
        orientation: TerminalSplit.Orientation
    ) {
        guard let joiningTab = terminalSessions.first(where: { $0.id == id }),
            splitChooser(beside: id) == nil, splitChooser(beside: tabID) == nil
        else { return }
        var strip = tabStrip
        guard strip.addSplit(joining: id, beside: tabID, on: side, orientation: orientation) != nil else { return }
        defer { persistOpenTabs() }
        apply(strip)
        joiningTab.startNowThatItIsShown()
    }
}
