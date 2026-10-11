/// Finding text in what a terminal holds, its scrollback and screen, whichever engine draws it. The selected match is
/// highlighted and scrolled into view. The find bar is the app's own, the same for both engines; see `TerminalFindState`.
/// A CLI drawing on the alternate screen, as each CLI in tmux does, leaves the terminal no scrollback, so there this finds
/// only what the screen shows.
@MainActor
protocol TerminalTextFinding: AnyObject {
    /// Called with the matches counted each time the count or the selected match changes, and with nil when no search
    /// runs. SwiftTerm counts as it moves, so it calls this from inside `findText` and `findTextAgain`. Ghostty counts
    /// on a thread of its own and calls this later, as its count grows and its selection moves.
    var onFindMatchCountChange: ((TerminalFindMatchCount?) -> Void)? { get set }
    /// Starts a search for `query`, replacing any other, and selects its newest match. An empty query ends the search.
    func findText(_ query: String)
    /// Selects the match after the selected one, wrapping around at either end.
    func findTextAgain(_ query: String, direction: TerminalFindDirection)
    /// Ends the search and takes its highlight away.
    func endTextFind()
}
