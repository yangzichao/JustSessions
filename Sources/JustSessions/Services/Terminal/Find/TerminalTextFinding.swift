/// A CLI drawing on the alternate screen, as each CLI in tmux does, leaves the terminal no scrollback, so there this finds
/// only what the screen shows.
@MainActor
protocol TerminalTextFinding: AnyObject {
    func findText(_ query: String) -> TerminalFindMatchCount?
    func findTextAgain(_ query: String, direction: TerminalFindDirection) -> TerminalFindMatchCount?
    func endTextFind()
}

@MainActor
protocol TerminalTextFindingCountingLater: AnyObject {
    var onMatchCount: ((TerminalFindMatchCount?) -> Void)? { get set }
    func findText(_ query: String)
    func findTextAgain(_ query: String, direction: TerminalFindDirection)
    func endTextFind()
}
