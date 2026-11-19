enum TmuxHistorySearchOutcome: Equatable {
    case searched(TerminalFindMatchCount?)
    case couldNotSearch

    var count: TerminalFindMatchCount? {
        if case .searched(let count) = self { count } else { nil }
    }
}
