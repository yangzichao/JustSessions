import Foundation

/// The split view entries a tab's menus offer, in the tab bar and in its terminal, as Chrome's tab menu offers them.
enum TerminalTabSplitMenu {
    /// Another tab in no split, while the selected tab is in none: it can open in a new split with the selected tab.
    case newSplitWithSelectedTab
    /// The selected tab, in no split: any of these tabs, every other tab in no split, can open in a new split with it.
    case addTabToNewSplit(candidates: [TerminalTabSplitCandidate])
    /// A tab in no split, while the selected tab is in a split: it can take the place of either of that split's tabs.
    case moveIntoShownSplit
    /// A tab in a split, shown or not: its split can be separated, either of its views closed, or its views reversed.
    case arrangeSplit
}

/// A tab that can open in a new split with the selected tab, named in the menu by its title and its project's name, so
/// tabs of one title in different projects can be told apart.
struct TerminalTabSplitCandidate: Identifiable {
    let session: TerminalSession
    let projectDisplayName: String

    var id: UUID { session.id }

    /// Such as "Fix the build · JustSessions": the user's own names, joined as the tab's tooltip joins its details.
    @MainActor var menuTitle: String {
        [session.displayTitle, projectDisplayName].joined(separator: " · ")
    }
}

/// What a tab's split view entries ask for; see `TerminalTabSplitMenu`.
enum TerminalTabSplitAction {
    case newSplitWithSelectedTab
    /// Opens the given tab in a new split with the selected tab.
    case addToNewSplit(UUID)
    case moveIntoShownSplit(swappingWith: TerminalSplit.Side)
    case separateViews
    case closeView(TerminalSplit.Side)
    case reverseViews
}
