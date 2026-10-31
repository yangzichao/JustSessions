import Foundation

/// The split entries a tab's menus offer, in the tab bar and in its terminal, and what each one does.
extension ConversationStore {
    /// The split entries Chrome's tab menu offers for the tab: a tab in a split, or beside a split chooser, arranges it;
    /// any other tab can open in a new split with the selected tab while that is in none, or take a place in its split
    /// or beside its chooser while it is in one. The selected tab can also open a new session or terminal of its project
    /// in a new split.
    func splitMenu(forTab tabID: UUID) -> TerminalTabSplitMenu? {
        if let split = split(containing: tabID) { return .arrangeSplit(orientation(ofSplitView: split.id)) }
        if let chooser = splitChooser(beside: tabID) { return .arrangeSplit(orientation(ofSplitView: chooser.id)) }
        guard let selectedTerminalID else { return nil }
        if let shownSplitOrientation { return .moveIntoShownSplit(shownSplitOrientation) }
        guard tabID == selectedTerminalID, let tab = terminalSessions.first(where: { $0.id == tabID }) else {
            return .newSplitWithSelectedTab
        }
        let candidates = terminalSessions
            .filter { $0.id != tabID && !isInSplitOrChooser($0.id) }
            .map { TerminalTabSplitCandidate(session: $0, projectDisplayName: projectDisplayName(forProjectPath: $0.projectDirectoryKey)) }
        let location = ProjectLocation(key: tab.projectDirectoryKey)
        return .addTabToNewSplit(
            candidates: candidates,
            newSessionProviders: newSessionProviders(on: location.host),
            canStartNewTabs: location.canStartSessions
        )
    }

    /// Acts on the tab's split entry. The views a split entry closes go through `closeTab`, the same close request as
    /// their ×; a split chooser closes at once, as it runs nothing. Separating a tab from its chooser closes the chooser.
    func performSplitAction(_ action: TerminalTabSplitAction, fromTab tabID: UUID, closeTab: (UUID) -> Void) {
        switch action {
        case .newSplitWithSelectedTab(let orientation):
            // Side by side, it joins on the side it came from, as in Chrome; stacked, below.
            splitSelectedTerminal(with: tabID, on: orientation == .stacked ? .right : nil, orientation: orientation)
        case .addToNewSplit(let otherTabID, let orientation):
            splitSelectedTerminal(with: otherTabID, on: .right, orientation: orientation)
        case .openInNewSplit(let newTab, let orientation):
            openNewTabInNewSplit(newTab, besideTab: tabID, orientation: orientation)
        case .moveIntoShownSplit(let side):
            moveIntoShownSplitView(tabID, on: side)
        case .separateViews:
            if let split = split(containing: tabID) {
                separateSplit(split.id)
            } else if let chooser = splitChooser(beside: tabID) {
                closeSplitChooser(chooser.id)
            }
        case .closeView(let side):
            if let split = split(containing: tabID), let sides = sides(of: split) {
                closeTab(sides.tabID(on: side))
            } else if let chooser = splitChooser(beside: tabID) {
                if side == chooser.side { closeSplitChooser(chooser.id) } else { closeTab(chooser.tabID) }
            }
        case .reverseViews:
            if let split = split(containing: tabID) {
                reverseSplit(split.id)
            } else if let chooser = splitChooser(beside: tabID) {
                reverseSplitChooser(chooser.id)
            }
        case .setOrientation(let orientation):
            if let splitViewID = split(containing: tabID)?.id ?? splitChooser(beside: tabID)?.id {
                setOrientation(orientation, ofSplitView: splitViewID)
            }
        }
    }

    /// A new session of the CLI, or a terminal, in the tab's project, on the right of the tab or below it.
    private func openNewTabInNewSplit(_ newTab: TerminalTabSplitNewTab, besideTab tabID: UUID, orientation: TerminalSplit.Orientation) {
        guard selectedTerminalID == tabID, let tab = terminalSessions.first(where: { $0.id == tabID }) else { return }
        let location = ProjectLocation(key: tab.projectDirectoryKey)
        openTabInNewSplit(on: .right, orientation: orientation) {
            switch newTab {
            case .session(let provider):
                launchNewSessionFromProject(provider: provider, projectPath: tab.projectDirectoryKey)
            case .terminal:
                openPlainTerminal(in: location)
            }
        }
    }
}
