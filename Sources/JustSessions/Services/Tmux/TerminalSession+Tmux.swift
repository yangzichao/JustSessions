import Foundation

extension TerminalSession {
    /// Whether closing the tab can leave its CLI running in tmux. On this Mac the tab's tmux client ends when its
    /// session does; over SSH it also ends when the connection drops, with the CLI still running on the host. A tab
    /// still waiting to be shown has started nothing. A plain terminal's shell ends with its tab, in tmux or not.
    var canKeepCLIRunningAfterClose: Bool {
        !isPlainTerminal && tmuxSessionName != nil && !isWaitingToBeShown && (host != .thisMac || !hasExited)
    }

    /// Whether closing the tab stops nothing, so it closes without asking: its CLI or shell already ended, and no tmux
    /// on an SSH host may still run it.
    var closingStopsNothing: Bool {
        hasExited && !canKeepCLIRunningAfterClose && !mayRunPlainTerminalShellOnHost
    }

    /// A plain terminal's shell may still run in tmux on its SSH host while the tab waits to be shown, as after a
    /// relaunch, or after its connection dropped; closing the tab ends it there. On this Mac a waiting plain terminal
    /// runs nothing: one whose shell still runs reattaches at once (`ConversationStore+TabReopening`).
    var mayRunPlainTerminalShellOnHost: Bool {
        isPlainTerminal && host != .thisMac && tmuxSessionName != nil && (isWaitingToBeShown || hasDroppedConnectionToTmux)
    }
}
