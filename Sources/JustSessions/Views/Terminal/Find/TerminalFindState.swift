import Observation

/// A tab's find bar, which searches what its terminal holds; see `TerminalTextFinding`. Each tab has its own, kept
/// while the tab moves between windows. Closing it keeps the text, so ⌘F brings back the last search.
@MainActor
@Observable
final class TerminalFindState {
    private(set) var isPresented = false
    /// Searched as it changes, while the bar shows.
    var query = "" {
        didSet {
            guard query != oldValue, isPresented else { return }
            showCount(finder.findText(query))
        }
    }
    /// Nil before a search and for an engine that doesn't count matches. A finder that counts later keeps the last count
    /// until the next one arrives.
    private(set) var matchCount: TerminalFindMatchCount?
    /// The field has the keyboard, so Return, Shift-Return, and Escape belong to the bar, not the terminal's program.
    var isFieldFocused = false
    /// Goes up each time the field should take the keyboard.
    private(set) var focusRevision = 0
    /// Goes up when the bar closes, so the terminal can take the keyboard back.
    private(set) var closeRevision = 0

    @ObservationIgnored private let finder: any TerminalTextFinding
    @ObservationIgnored private let countsLater: Bool

    init(finder: any TerminalTextFinding) {
        self.finder = finder
        let laterFinder = finder as? any TerminalTextFindingCountingLater
        countsLater = laterFinder != nil
        laterFinder?.onMatchCount = { [weak self] count in
            guard let self, self.isPresented else { return }
            self.matchCount = count
        }
    }

    /// Opens the bar, or puts the keyboard back in it, and searches again for the text it kept.
    func show() {
        if !isPresented {
            isPresented = true
            if !query.isEmpty { showCount(finder.findText(query)) }
        }
        focusRevision += 1
    }

    func move(_ direction: TerminalFindDirection) {
        guard isPresented, !query.isEmpty else { return }
        showCount(finder.findTextAgain(query, direction: direction))
    }

    func close() {
        guard isPresented else { return }
        isPresented = false
        isFieldFocused = false
        matchCount = nil
        finder.endTextFind()
        closeRevision += 1
    }

    private func showCount(_ count: TerminalFindMatchCount?) {
        guard !countsLater else { return }
        matchCount = count
    }
}
