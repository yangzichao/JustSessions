import GhosttyTerminal

extension GhosttyTabTerminalView: TerminalTextFinding {
    /// `search:` takes the rest of the action as its text, colons and backslashes included. It selects no match, so
    /// the first move selects the newest.
    func findText(_ query: String) -> TerminalFindMatchCount? {
        guard !query.isEmpty else {
            endTextFind()
            return nil
        }
        performBindingAction("search:" + query)
        performBindingAction("navigate_search:next")
        return nil
    }

    func findTextAgain(_ query: String, direction: TerminalFindDirection) -> TerminalFindMatchCount? {
        switch direction {
        case .towardOlder: performBindingAction("navigate_search:next")
        case .towardNewer: performBindingAction("navigate_search:previous")
        }
        return nil
    }

    func endTextFind() {
        performBindingAction("end_search")
    }
}
