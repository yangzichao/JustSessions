import GhosttyTerminal

/// Ghostty searches through its binding actions, the ones its own find bar uses, highlighting every match and scrolling
/// the selected one to the top of the view. Its "next" match is the older one, as the app's find goes. It reports the
/// count and the selected match later, from its search thread, through `TerminalSurfaceSearchDelegate`.
extension GhosttyTabTerminalView: TerminalTextFinding {
    /// `search:` takes the rest of the action as its text, colons and backslashes included. It selects no match, so
    /// the first move selects the newest.
    func findText(_ query: String) {
        guard !query.isEmpty else {
            endTextFind()
            return
        }
        performBindingAction("search:" + query)
        performBindingAction("navigate_search:next")
    }

    func findTextAgain(_ query: String, direction: TerminalFindDirection) {
        switch direction {
        case .towardOlder: performBindingAction("navigate_search:next")
        case .towardNewer: performBindingAction("navigate_search:previous")
        }
    }

    func endTextFind() {
        performBindingAction("end_search")
    }
}

/// Only the counts are used: ⌘F opens the app's own bar before the key reaches Ghostty; see `TerminalFindShortcuts`.
extension GhosttyTabTerminalView: TerminalSurfaceSearchDelegate {
    func terminalDidUpdateSearchTotal(_ total: Int?) {
        findProgress.total = total
        onFindMatchCountChange?(findProgress.matchCount)
    }

    func terminalDidUpdateSearchSelected(_ selected: Int?) {
        findProgress.selectedIndexFromNewest = selected
        onFindMatchCountChange?(findProgress.matchCount)
    }
}
