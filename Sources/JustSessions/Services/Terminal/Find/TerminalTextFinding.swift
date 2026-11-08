/// Finding text in what a terminal holds, its scrollback and screen, whichever engine draws it. The selected match is
/// highlighted and scrolled into view. The find bar is the app's own, the same for both engines; see `TerminalFindState`.
/// A CLI drawing on the alternate screen, as each CLI in tmux does, leaves the terminal no scrollback, so there this finds
/// only what the screen shows.
@MainActor
protocol TerminalTextFinding: AnyObject {
    /// Starts a search for `query`, replacing any other, and selects its newest match. An empty query ends the search.
    /// Returns the matches counted, or nil when the engine doesn't count them, as Ghostty's wrapper doesn't pass its
    /// counts on.
    func findText(_ query: String) -> TerminalFindMatchCount?
    /// Selects the match after the selected one, wrapping around at either end.
    func findTextAgain(_ query: String, direction: TerminalFindDirection) -> TerminalFindMatchCount?
    /// Ends the search and takes its highlight away.
    func endTextFind()
}

/// A finder whose counts come after `findText` and `findTextAgain` return, as tmux's do; see `PlainTerminalFinder`. The
/// find bar ignores what those return and shows each count as it arrives.
@MainActor
protocol TerminalTextFindingCountingLater: TerminalTextFinding {
    var onMatchCount: ((TerminalFindMatchCount?) -> Void)? { get set }
}
