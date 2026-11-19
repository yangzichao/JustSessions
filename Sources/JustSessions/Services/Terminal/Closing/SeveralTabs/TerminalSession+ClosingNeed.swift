import Foundation

extension TerminalSession {
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
