import Foundation

extension TerminalSession {
    /// What closing the tab stops, as it is now.
    var closingNeed: TabClosingNeed {
        if mayRunPlainTerminalShellOnHost { return .plainTerminal }
        return TabClosingNeed(
            isWaitingToBeShown: isWaitingToBeShown,
            closingStopsNothing: closingStopsNothing,
            canKeepCLIRunningAfterClose: canKeepCLIRunningAfterClose,
            isPlainTerminal: isPlainTerminal
        )
    }
}
