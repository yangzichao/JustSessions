import Foundation

enum TerminalTabSplitMenu {
    case newSplitWithSelectedTab
    case addTabToNewSplit(
        candidates: [TerminalTabSplitCandidate],
        newSessionProviders: [ConversationProvider],
        host: SessionHost,
        canStartNewTabs: Bool
    )
    case moveIntoShownSplit(TerminalSplit.Orientation)
    case arrangeSplit(TerminalSplit.Orientation)
}

struct TerminalTabSplitCandidate: Identifiable {
    let session: TerminalSession
    let projectDisplayName: String

    var id: UUID { session.id }

    @MainActor var menuTitle: String {
        [session.displayTitle, projectDisplayName].joined(separator: " · ")
    }
}

enum TerminalTabSplitNewTab: Equatable {
    case session(ConversationProvider)
    case terminal
}

enum TerminalTabSplitAction {
    case newSplitWithSelectedTab(TerminalSplit.Orientation)
    case addToNewSplit(UUID, TerminalSplit.Orientation)
    case openInNewSplit(TerminalTabSplitNewTab, TerminalSplit.Orientation)
    case moveIntoShownSplit(swappingWith: TerminalSplit.Side)
    case separateViews
    case closeView(TerminalSplit.Side)
    case reverseViews
    case setOrientation(TerminalSplit.Orientation)
}

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

    var toggleTitle: String.LocalizationValue {
        self == .sideBySide ? "Stack views" : "Place views side by side"
    }

    var newSplitTitle: String.LocalizationValue {
        self == .sideBySide ? "Split right" : "Split down"
    }

    var systemImage: String {
        self == .sideBySide ? "rectangle.split.2x1" : "rectangle.split.1x2"
    }
}
