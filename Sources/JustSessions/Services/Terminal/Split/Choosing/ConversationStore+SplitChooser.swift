import Foundation

extension ConversationStore {
    func splitChooser(beside tabID: UUID) -> TerminalSplitChooser? {
        terminalSplitChoosers.first { $0.tabID == tabID }
    }

    var shownSplitChooser: TerminalSplitChooser? {
        selectedTerminalID.flatMap(splitChooser(beside:))
    }

    func isInSplitOrChooser(_ tabID: UUID) -> Bool {
        split(containing: tabID) != nil || splitChooser(beside: tabID) != nil
    }

    var isSplitViewShown: Bool {
        shownSplit != nil || shownSplitChooser != nil
    }

    var canOpenSplitChooser: Bool {
        selectedTerminalID.map { !isInSplitOrChooser($0) } ?? false
    }

    func openSplitChooser() {
        guard canOpenSplitChooser, let selectedTerminalID else { return }
        terminalSplitChoosers.append(TerminalSplitChooser(tabID: selectedTerminalID))
        selectsShownSplitChooser = true
    }

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

    func selectSplitChooser(beside tabID: UUID) {
        guard splitChooser(beside: tabID) != nil else { return }
        selectTerminal(tabID)
        selectsShownSplitChooser = true
    }

    func chooseTab(_ tabID: UUID, inSplitChooser chooserID: UUID) {
        guard let chooser = terminalSplitChoosers.first(where: { $0.id == chooserID }),
            let chosenTab = terminalSessions.first(where: { $0.id == tabID }),
            tabID != chooser.tabID,
            !isInSplitOrChooser(tabID)
        else { return }
        var strip = tabStrip
        guard
            strip.addSplit(
                joining: tabID,
                beside: chooser.tabID,
                on: .fixed(chooser.side),
                splitID: chooser.id,
                orientation: chooser.orientation
            ) != nil
        else { return }
        defer { persistOpenTabs() }
        apply(strip)
        selectTerminal(tabID)
        chosenTab.startNowThatItIsShown()
    }

    func closeSplitChooser(_ chooserID: UUID) {
        terminalSplitChoosers.removeAll { $0.id == chooserID }
    }

    func reverseSplitChooser(_ chooserID: UUID) {
        guard let index = terminalSplitChoosers.firstIndex(where: { $0.id == chooserID }) else { return }
        terminalSplitChoosers[index].side = terminalSplitChoosers[index].tabSide
    }

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

    private func moveBesideShownSplitChooser(_ tabID: UUID) {
        guard let chooser = shownSplitChooser,
            let chooserIndex = terminalSplitChoosers.firstIndex(where: { $0.id == chooser.id }),
            terminalSessions.contains(where: { $0.id == tabID }),
            !isInSplitOrChooser(tabID)
        else { return }
        let chooserWasSelected = selectsShownSplitChooser
        terminalSplitChoosers[chooserIndex].tabID = tabID
        selectTerminal(tabID)
        selectsShownSplitChooser = chooserWasSelected
    }

    func awaitNewTab(inSplitChooser chooserID: UUID) {
        splitChooserAwaitingNewTab = chooserID
    }

    func stopAwaitingNewTabInSplitChooser() {
        splitChooserAwaitingNewTab = nil
    }
}
