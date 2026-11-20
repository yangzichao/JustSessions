import Foundation

/// A plain terminal's scrollback is its tmux pane's history, since the tab's terminal shows tmux on the alternate
/// screen, which keeps none. tmux 3.7 and later apply a session's limit to the pane it has; earlier versions only to
/// panes made after it.
enum PlainTerminalTmuxHistoryLimit {
    static let lineCount = SelectableTerminalView.scrollbackLineCount
    static let tmuxDefaultLineCount = 2_000

    static let remoteSessionOptionCommand = "set-option -q history-limit \(lineCount)"
}
