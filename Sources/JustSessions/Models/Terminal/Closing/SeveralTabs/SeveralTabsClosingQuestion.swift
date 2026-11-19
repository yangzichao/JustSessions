import Foundation

enum SeveralTabsClosingQuestion: Equatable, Sendable {
    case closeWithoutAsking
    case keepOrEndCLIs(alsoStopsOthers: Bool)
    case stopEverything

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
