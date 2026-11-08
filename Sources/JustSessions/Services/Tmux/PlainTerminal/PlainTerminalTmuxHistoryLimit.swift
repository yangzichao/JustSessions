import Foundation

/// A plain terminal's scrollback is its tmux pane's history, since the tab's terminal shows tmux on the alternate
/// screen, which keeps none. Its session keeps as many lines as the tab's terminal does outside tmux, rather than
/// tmux's default, which CLI tabs keep. tmux 3.7 and later apply a session's limit to the pane it has; earlier
/// versions only to panes made after it. So this Mac's server, whose default is tmux's own as it reads no
/// configuration, makes the pane under a raised server-wide limit and sets that back right after; on an SSH host,
/// whose limit is yours, a tmux before 3.7 keeps it.
enum PlainTerminalTmuxHistoryLimit {
    /// As `SelectableTerminalView.scrollbackLineCount`.
    static let lineCount = 10_000
    static let tmuxDefaultLineCount = 2_000

    /// For the commands a remote tab's session runs on every attach; see `RemoteTmuxSessionOptions`.
    static let remoteSessionOptionCommand = "set-option -q history-limit \(lineCount)"
}
