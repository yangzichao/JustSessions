import Foundation

/// The split entries a tab's menus offer, in the tab bar and in its terminal, and what each one does.
extension ConversationStore {
    /// The split entries Chrome's tab menu offers for the tab: a tab in a split arranges it; any other tab can open
    /// in a new split with the selected tab while that is in none, or take a place in its split while it is in one.
    func splitMenu(forTab tabID: UUID) -> TerminalTabSplitMenu? {
        if split(containing: tabID) != nil { return .arrangeSplit }
        guard let selectedTerminalID else { return nil }
        if split(containing: selectedTerminalID) != nil { return .moveIntoShownSplit }
        guard tabID == selectedTerminalID else { return .newSplitWithSelectedTab }
        let candidates = terminalSessions
            .filter { $0.id != tabID && split(containing: $0.id) == nil }
            .map { TerminalTabSplitCandidate(session: $0, projectDisplayName: projectDisplayName(forProjectPath: $0.projectDirectoryKey)) }
        return .addTabToNewSplit(candidates: candidates)
    }

    /// Acts on the tab's split entry. The views a split entry closes go through `closeTab`, the same close request as
    /// their ×.
    func performSplitAction(_ action: TerminalTabSplitAction, fromTab tabID: UUID, closeTab: (UUID) -> Void) {
        switch action {
        case .newSplitWithSelectedTab:
            splitSelectedTerminal(with: tabID)
        case .addToNewSplit(let otherTabID):
            splitSelectedTerminal(with: otherTabID)
        case .moveIntoShownSplit(let side):
            moveIntoShownSplit(tabID, swappingWith: side)
        case .separateViews:
            if let split = split(containing: tabID) { separateSplit(split.id) }
        case .closeView(let side):
            if let split = split(containing: tabID), let sides = sides(of: split) {
                closeTab(sides.tabID(on: side))
            }
        case .reverseViews:
            if let split = split(containing: tabID) { reverseSplit(split.id) }
        }
    }
}
