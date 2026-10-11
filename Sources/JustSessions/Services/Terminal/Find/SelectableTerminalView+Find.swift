import SwiftTerm

/// SwiftTerm selects a match as text is selected and scrolls it into view. Its own find bar opens only from the Edit
/// menu's Find items, which the app doesn't have, and a Ghostty tab couldn't match it, so the app's bar drives these.
/// Output clears SwiftTerm's selection, so after new output the next move starts again from the newest match.
extension SelectableTerminalView: TerminalTextFinding {
    /// SwiftTerm's "previous" searches up from the end, so with nothing selected it finds the newest match.
    func findText(_ query: String) {
        clearSearch()
        guard !query.isEmpty else {
            onFindMatchCountChange?(nil)
            return
        }
        findPrevious(query)
        onFindMatchCountChange?(matchCount(for: query))
    }

    func findTextAgain(_ query: String, direction: TerminalFindDirection) {
        guard !query.isEmpty else { return }
        switch direction {
        case .towardOlder: findPrevious(query)
        case .towardNewer: findNext(query)
        }
        onFindMatchCountChange?(matchCount(for: query))
    }

    func endTextFind() {
        clearSearch()
        onFindMatchCountChange?(nil)
    }

    private func matchCount(for query: String) -> TerminalFindMatchCount {
        let summary = searchMatchSummary(query, limit: TerminalFindMatchCount.countLimit)
        return TerminalFindMatchCount(countedFromOldest: summary.total, selectedIndexFromOldest: summary.index)
    }
}
