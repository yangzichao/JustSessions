import Foundation

struct ThisMacTmuxNewSessionHistoryLimit {
    let lineCount: Int
    let sessionName: String

    var raisingServerLimitBeforeNewSession: [String] {
        ["set-option", "-gq", "history-limit", "\(lineCount)", ";"]
    }

    var keepingItOnTheSessionAndRestoringServerLimitAfterNewSession: [String] {
        [
            ";", "set-option", "-q", "-t", sessionPaneTarget, "history-limit", "\(lineCount)",
            ";", "set-option", "-gq", "history-limit", "\(PlainTerminalTmuxHistoryLimit.tmuxDefaultLineCount)",
        ]
    }

    // `set-option` takes a pane, and a bare `=name` is none.
    private var sessionPaneTarget: String { "=\(sessionName):" }
}
