/// What one step of a search in a tmux session's history came to (`TmuxHistoryFinder`).
enum TmuxHistorySearchOutcome: Equatable {
    /// tmux searched. The count is nil when it found matches it doesn't count, as tmux 3.4, which only says whether
    /// the search found any.
    case searched(TerminalFindMatchCount?)
    /// tmux couldn't run the search, as on an SSH host without it, or with the session gone.
    case couldNotSearch

    /// Nil also when tmux couldn't search.
    var count: TerminalFindMatchCount? {
        if case .searched(let count) = self { count } else { nil }
    }
}
