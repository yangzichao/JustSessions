import Foundation

/// What closing several tabs at once asks, such as a tab group's: one question for them all, or none when every tab
/// would close without asking on its own, by itself or by the choices saved with Don't ask again.
enum SeveralTabsClosingQuestion: Equatable, Sendable {
    /// Close them all without asking. Each CLI in tmux ends or keeps running as its host's saved choice says.
    case closeWithoutAsking
    /// Keep running or End sessions, for the CLIs tmux can keep running. With `alsoStopsOthers`, other tabs' CLIs or
    /// shells stop whichever is picked.
    case keepOrEndCLIs(alsoStopsOthers: Bool)
    /// Close the tabs, stopping their CLIs and shells, or Cancel.
    case stopEverything

    /// Each tab's need comes with the choice saved for its host, which only a CLI tmux can keep running reads.
    init(
        tabs: [(need: TabClosingNeed, tabCloseChoice: TabCloseChoice)],
        plainTerminalCloseChoice: PlainTerminalCloseChoice
    ) {
        let needs = tabs.map(\.need)
        let choicesForCLIsToKeep = tabs.filter { $0.need == .canKeepCLIRunning }.map(\.tabCloseChoice)
        let anyCLIToKeepAsks = choicesForCLIsToKeep.contains { $0.endsTmuxSessionWithoutAsking == nil }
        let stopsOthersAskingFirst =
            needs.contains(.cliStopsWithTab)
            || (needs.contains(.plainTerminal) && plainTerminalCloseChoice == .askEachTime)
        if !choicesForCLIsToKeep.isEmpty, anyCLIToKeepAsks || stopsOthersAskingFirst {
            let stopsOthers = needs.contains(.cliStopsWithTab) || needs.contains(.plainTerminal)
            self = .keepOrEndCLIs(alsoStopsOthers: stopsOthers)
        } else if stopsOthersAskingFirst {
            self = .stopEverything
        } else {
            self = .closeWithoutAsking
        }
    }
}
