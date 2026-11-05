import Foundation

/// How each split, or split chooser, lays out its two views: side by side, as in Chrome, unless stacked, one above the
/// other. Kept by the split's id rather than in the split, as its panes' widths are, so the tab strip's rules, which
/// know only the tabs' order, never change it. Splits are not saved across quits, and neither is this.
extension ConversationStore {
    func orientation(ofSplitView id: UUID) -> TerminalSplit.Orientation {
        stackedSplitViewIDs.contains(id) ? .stacked : .sideBySide
    }

    /// The id of the split the tab is in, or of the split chooser beside it; nil for a tab in neither.
    func splitViewID(containing tabID: UUID) -> UUID? {
        split(containing: tabID)?.id ?? splitChooser(beside: tabID)?.id
    }

    /// The shown split's, or split chooser's, id.
    var shownSplitViewID: UUID? {
        shownSplit?.id ?? shownSplitChooser?.id
    }

    /// The shown split's, or split chooser's, layout; nil while neither shows.
    var shownSplitOrientation: TerminalSplit.Orientation? {
        shownSplitViewID.map(orientation(ofSplitView:))
    }

    /// Lays the split's, or split chooser's, views out as `orientation`. Each keeps its tab and its side: the left view
    /// is the top one when stacked.
    func setOrientation(_ orientation: TerminalSplit.Orientation, ofSplitView id: UUID) {
        guard terminalSplits.contains(where: { $0.id == id }) || terminalSplitChoosers.contains(where: { $0.id == id }) else { return }
        switch orientation {
        case .stacked: stackedSplitViewIDs.insert(id)
        case .sideBySide: stackedSplitViewIDs.remove(id)
        }
    }

    /// Puts the shown split's tab at `place`, as its pane dragged by its toolbar is let go there: on that side of the
    /// split, laid out that way, its partner taking the other side; or, in the middle, on its own, the split separated.
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

    /// Opens a tab with `openTab`, such as a new session in the selected tab's project, and shows it on `side` of a new
    /// split with the tab selected before, laid out as `orientation`. While that tab is in a split already, or no tab
    /// was selected, the new tab opens on its own, as it would otherwise. The new tab stays selected throughout, so it
    /// never leaves the screen, which would refresh its host before its CLI saved anything (SPL-10).
    func openTabInNewSplit(on side: TerminalSplit.Side, orientation: TerminalSplit.Orientation, _ openTab: () -> Void) {
        let shownTabID = selectedTerminalID
        openTab()
        guard let shownTabID, let newTabID = selectedTerminalID, newTabID != shownTabID,
              !isInSplitOrChooser(shownTabID), !isInSplitOrChooser(newTabID) else { return }
        splitTerminal(shownTabID, with: newTabID, on: side, orientation: orientation)
    }

    /// As `splitSelectedTerminal`, beside `tabID` rather than the selected tab; the selection stays as it is.
    func splitTerminal(
        _ tabID: UUID,
        with id: UUID,
        on side: TerminalSplit.Side?,
        orientation: TerminalSplit.Orientation
    ) {
        guard let joiningTab = terminalSessions.first(where: { $0.id == id }),
              splitChooser(beside: id) == nil, splitChooser(beside: tabID) == nil else { return }
        var strip = tabStrip
        guard let split = strip.addSplit(joining: id, beside: tabID, on: side) else { return }
        defer { persistOpenTabs() }
        apply(strip)
        // Once the split is open: a layout kept for an id no split or chooser has is forgotten.
        if orientation == .stacked { stackedSplitViewIDs.insert(split.id) }
        joiningTab.startNowThatItIsShown()
    }

    /// Splits and choosers that are gone take their layout with them.
    func forgetOrientationsOfClosedSplitViews() {
        guard !stackedSplitViewIDs.isEmpty else { return }
        let openIDs = Set(terminalSplits.map(\.id) + terminalSplitChoosers.map(\.id))
        let kept = stackedSplitViewIDs.intersection(openIDs)
        if kept != stackedSplitViewIDs { stackedSplitViewIDs = kept }
    }
}
