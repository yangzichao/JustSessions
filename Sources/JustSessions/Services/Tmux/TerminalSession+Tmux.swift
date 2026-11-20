import Foundation

extension TerminalSession {
    var canKeepCLIRunningAfterClose: Bool {
        runsCLIInTmux && !isWaitingToBeShown && !tmuxSessionIsKnownToHaveEnded
    }

    private var runsCLIInTmux: Bool { !isPlainTerminal && tmuxSessionName != nil }

    private var tmuxSessionIsKnownToHaveEnded: Bool { host == .thisMac && hasExited }

    var closingStopsNothing: Bool {
        hasExited && !canKeepCLIRunningAfterClose && !mayRunPlainTerminalShellOnHost
    }

    var mayRunPlainTerminalShellOnHost: Bool {
        isPlainTerminal && host != .thisMac && tmuxSessionName != nil && (isWaitingToBeShown || hasDroppedConnectionToTmux)
    }
}
