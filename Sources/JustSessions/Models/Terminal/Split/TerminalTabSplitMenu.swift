import Foundation

/// The split view entries a tab's menus offer, in the tab bar and in its terminal, as Chrome's tab menu offers them.
enum TerminalTabSplitMenu {
    /// Another tab in no split, while the selected tab is in none: it can open in a new split with the selected tab,
    /// beside it or below it.
    case newSplitWithSelectedTab
    /// The selected tab, in no split: any of these tabs, every other tab in no split, or a new session of one of these
    /// CLIs or a terminal in its project, while its folder is there to start them in, can open in a new split with it,
    /// on its right or below it.
    case addTabToNewSplit(
        candidates: [TerminalTabSplitCandidate],
        newSessionProviders: [ConversationProvider],
        canStartNewTabs: Bool
    )
    /// A tab in no split, while the selected tab is in a split laid out this way: it can take the place of either of
    /// that split's tabs.
    case moveIntoShownSplit(TerminalSplit.Orientation)
    /// A tab in a split laid out this way, shown or not: its split can be separated, either of its views closed, its
    /// views reversed, or laid out the other way.
    case arrangeSplit(TerminalSplit.Orientation)
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

/// A tab that opens straight into a new split, in the selected tab's project: a new session of a CLI, or a terminal.
enum TerminalTabSplitNewTab: Equatable {
    case session(ConversationProvider)
    case terminal
}

/// What a tab's split view entries ask for; see `TerminalTabSplitMenu`.
enum TerminalTabSplitAction {
    /// Opens the tab in a new split with the selected tab: side by side on the side it came from, or stacked below it.
    case newSplitWithSelectedTab(TerminalSplit.Orientation)
    /// Opens the given tab in a new split with the selected tab, on its right or below it.
    case addToNewSplit(UUID, TerminalSplit.Orientation)
    /// Opens a new tab in the selected tab's project in a new split with it, on its right or below it.
    case openInNewSplit(TerminalTabSplitNewTab, TerminalSplit.Orientation)
    case moveIntoShownSplit(swappingWith: TerminalSplit.Side)
    case separateViews
    case closeView(TerminalSplit.Side)
    case reverseViews
    /// Lays the split's views out the other way, each keeping its side.
    case setOrientation(TerminalSplit.Orientation)
}

/// The names the terminal's split entries give a split's sides, as it is laid out; the tab bar's SwiftUI menu spells
/// them out.
extension TerminalSplit.Orientation {
    func closeViewTitle(_ side: TerminalSplit.Side) -> String.LocalizationValue {
        switch (self, side) {
        case (.sideBySide, .left): "Close left view"
        case (.sideBySide, .right): "Close right view"
        case (.stacked, .left): "Close top view"
        case (.stacked, .right): "Close bottom view"
        }
    }

    func swapWithViewSystemImage(_ side: TerminalSplit.Side) -> String {
        switch (self, side) {
        case (.sideBySide, .left): "rectangle.lefthalf.inset.filled"
        case (.sideBySide, .right): "rectangle.righthalf.inset.filled"
        case (.stacked, .left): "rectangle.tophalf.inset.filled"
        case (.stacked, .right): "rectangle.bottomhalf.inset.filled"
        }
    }

    /// The entry that lays the split out the other way.
    var toggleTitle: String.LocalizationValue {
        self == .sideBySide ? "Stack views" : "Place views side by side"
    }

    /// The entry that opens a tab in a new split laid out this way.
    var newSplitTitle: String.LocalizationValue {
        self == .sideBySide ? "Split right" : "Split down"
    }

    var systemImage: String {
        self == .sideBySide ? "rectangle.split.2x1" : "rectangle.split.1x2"
    }
}
