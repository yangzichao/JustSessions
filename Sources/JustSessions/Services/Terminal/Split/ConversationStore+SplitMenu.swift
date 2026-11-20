import Foundation

extension ConversationStore {
    func splitMenu(forTab tabID: UUID) -> TerminalTabSplitMenu? {
        if let split = split(containing: tabID) { return .arrangeSplit(orientation(ofSplitView: split.id)) }
        if let chooser = splitChooser(beside: tabID) { return .arrangeSplit(orientation(ofSplitView: chooser.id)) }
        guard let selectedTerminalID else { return nil }
        if let shownSplitOrientation { return .moveIntoShownSplit(shownSplitOrientation) }
        guard tabID == selectedTerminalID, let tab = terminalSessions.first(where: { $0.id == tabID }) else {
            return .newSplitWithSelectedTab
        }
        let candidates =
            terminalSessions
            .filter { $0.id != tabID && !isInSplitOrChooser($0.id) }
            .map { TerminalTabSplitCandidate(session: $0, projectDisplayName: projectDisplayName(forProjectPath: $0.projectDirectoryKey)) }
        let location = ProjectLocation(key: tab.projectDirectoryKey)
        return .addTabToNewSplit(
            candidates: candidates,
            newSessionProviders: newSessionProviders(on: location.host),
            host: location.host,
            canStartNewTabs: location.canStartSessions
        )
    }

    func performSplitAction(_ action: TerminalTabSplitAction, fromTab tabID: UUID, closeTab: (UUID) -> Void) {
        switch action {
        case .newSplitWithSelectedTab(let orientation):
            splitSelectedTerminal(with: tabID, on: orientation == .stacked ? .right : .sideItCameFrom, orientation: orientation)
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
            if let splitViewID = splitViewID(containing: tabID) {
                setOrientation(orientation, ofSplitView: splitViewID)
            }
        }
    }

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
