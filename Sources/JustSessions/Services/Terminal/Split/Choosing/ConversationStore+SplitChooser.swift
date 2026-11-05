import Foundation

/// Add Tab to New Split View (⌘⌥N) and the list it shows beside the selected tab, as Chrome's split view new tab page;
/// see `TerminalSplitChooser`. A chooser counts as a split's other view: its tab joins no split and drops into none,
/// the split entries arrange it, and a tab put on its side takes its place.
extension ConversationStore {
    func splitChooser(beside tabID: UUID) -> TerminalSplitChooser? {
        terminalSplitChoosers.first { $0.tabID == tabID }
    }

    /// The selected tab's chooser, which shows beside it.
    var shownSplitChooser: TerminalSplitChooser? {
        selectedTerminalID.flatMap(splitChooser(beside:))
    }

    /// The tab is in a split or beside a chooser, as Chrome counts the tab beside its split view page as split.
    func isInSplitOrChooser(_ tabID: UUID) -> Bool {
        split(containing: tabID) != nil || splitChooser(beside: tabID) != nil
    }

    /// A split or a chooser shows, so the split view entries act on it.
    var isSplitViewShown: Bool {
        shownSplit != nil || shownSplitChooser != nil
    }

    /// Add Tab to New Split View acts only on a selected tab in no split and beside no chooser, as Chrome's
    /// IDC_NEW_SPLIT_TAB acts only while the active tab is in no split.
    var canOpenSplitChooser: Bool {
        selectedTerminalID.map { !isInSplitOrChooser($0) } ?? false
    }

    /// Shows the selected tab on the left and a chooser on the right, which takes the keyboard, as Chrome's NewSplitTab
    /// adds its split view page right after the active tab and activates it.
    func openSplitChooser() {
        guard canOpenSplitChooser, let selectedTerminalID else { return }
        terminalSplitChoosers.append(TerminalSplitChooser(tabID: selectedTerminalID))
        selectsShownSplitChooser = true
    }

    /// The tabs the shown chooser lists; see `TerminalSplitChooser.candidates`.
    var splitChooserCandidates: [TerminalSession] {
        guard shownSplitChooser != nil else { return [] }
        let tabsOnScreen = terminalIDsOnScreen
        let candidateIDs = TerminalSplitChooser.candidates(
            amongTabs: terminalSessions.map(\.id),
            byLastSelected: tabIDsByLastSelected
        ) { tabID in
            !tabsOnScreen.contains(tabID) && !isInSplitOrChooser(tabID)
        }
        let tabsByID = Dictionary(uniqueKeysWithValues: terminalSessions.map { ($0.id, $0) })
        return candidateIDs.compactMap { tabsByID[$0] }
    }

    /// Gives the chooser beside the tab the keyboard, showing it, as a click on the chooser or on its half of the split
    /// tab does.
    func selectSplitChooser(beside tabID: UUID) {
        guard splitChooser(beside: tabID) != nil else { return }
        selectTerminal(tabID)
        selectsShownSplitChooser = true
    }

    /// Puts the tab, open here and in no split, in the chooser's place, as Chrome's ReplaceActiveSplitTab: the two tabs
    /// make a split, under the chooser's id so the panes keep their widths, the chosen tab on the chooser's side, and
    /// it is selected. A reopened tab still waiting to be shown starts as it joins.
    func chooseTab(_ tabID: UUID, inSplitChooser chooserID: UUID) {
        guard let chooser = terminalSplitChoosers.first(where: { $0.id == chooserID }),
              let chosenTab = terminalSessions.first(where: { $0.id == tabID }),
              tabID != chooser.tabID,
              !isInSplitOrChooser(tabID) else { return }
        var strip = tabStrip
        guard strip.addSplit(
            joining: tabID,
            beside: chooser.tabID,
            on: chooser.side,
            splitID: chooser.id,
            orientation: chooser.orientation
        ) != nil else { return }
        defer { persistOpenTabs() }
        // Applying the split closes the chooser, its tab now in a split.
        apply(strip)
        selectTerminal(tabID)
        chosenTab.startNowThatItIsShown()
    }

    /// Closes the chooser, leaving its tab full width, with the keyboard if the chooser had it, as closing Chrome's split
    /// view page does.
    func closeSplitChooser(_ chooserID: UUID) {
        terminalSplitChoosers.removeAll { $0.id == chooserID }
    }

    /// The chooser and its tab trade sides, as a split's views reverse.
    func reverseSplitChooser(_ chooserID: UUID) {
        guard let index = terminalSplitChoosers.firstIndex(where: { $0.id == chooserID }) else { return }
        terminalSplitChoosers[index].side = terminalSplitChoosers[index].tabSide
    }

    /// Puts the tab, open here and in no split, on `side` of the shown split or chooser, as Move tab into split view
    /// does: in a split, in place of the tab on that side; beside a chooser, in the chooser's place on its side, or else
    /// in place of the tab beside it.
    func moveIntoShownSplitView(_ tabID: UUID, on side: TerminalSplit.Side) {
        if shownSplit != nil {
            moveIntoShownSplit(tabID, swappingWith: side)
        } else if let chooser = shownSplitChooser {
            if side == chooser.side {
                chooseTab(tabID, inSplitChooser: chooser.id)
            } else {
                moveBesideShownSplitChooser(tabID)
            }
        }
    }

    /// The chooser moves from the selected tab to `tabID`, open here and in no split, which is selected; the tab it
    /// leaves goes off screen, and the chooser keeps the keyboard if it had it. Each tab keeps its place in the tab bar,
    /// within its project's group, where Chrome trades the two tabs' places.
    private func moveBesideShownSplitChooser(_ tabID: UUID) {
        guard let chooser = shownSplitChooser,
              let chooserIndex = terminalSplitChoosers.firstIndex(where: { $0.id == chooser.id }),
              terminalSessions.contains(where: { $0.id == tabID }),
              !isInSplitOrChooser(tabID) else { return }
        let chooserWasSelected = selectsShownSplitChooser
        terminalSplitChoosers[chooserIndex].tabID = tabID
        selectTerminal(tabID)
        selectsShownSplitChooser = chooserWasSelected
    }

    /// The chooser's New Session…: the next tab to open takes the chooser's place, as Chrome's split view page becomes
    /// the page you go to from it, until `stopAwaitingNewTabInSplitChooser()`.
    func awaitNewTab(inSplitChooser chooserID: UUID) {
        splitChooserAwaitingNewTab = chooserID
    }

    /// The New Session sheet closed: a tab opening later opens on its own.
    func stopAwaitingNewTabInSplitChooser() {
        splitChooserAwaitingNewTab = nil
    }
}
