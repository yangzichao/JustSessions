import Foundation

extension TerminalSession {
    var canKeepCLIRunningAfterClose: Bool {
        !isPlainTerminal && tmuxSessionName != nil && !isWaitingToBeShown && (host != .thisMac || !hasExited)
    }

    var closingStopsNothing: Bool {
        hasExited && !canKeepCLIRunningAfterClose && !mayRunPlainTerminalShellOnHost
    }

    var mayRunPlainTerminalShellOnHost: Bool {
        isPlainTerminal && host != .thisMac && tmuxSessionName != nil && (isWaitingToBeShown || hasDroppedConnectionToTmux)
    }
}
