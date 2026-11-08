import Foundation

/// ⌘F in a plain terminal whose shell may run in tmux. While it does, the tab's terminal shows tmux on its alternate
/// screen, and the shell's history is tmux's, so tmux finds in it (`TmuxHistoryFinder`). Otherwise, as on an SSH host
/// without tmux, the terminal finds in its own scrollback. A search keeps the finder it started with until it ends,
/// and one tmux couldn't run goes on in the terminal.
@MainActor
final class PlainTerminalFinder: TerminalTextFindingCountingLater {
    var onMatchCount: ((TerminalFindMatchCount?) -> Void)?

    private let terminalFinder: any TerminalTextFinding
    private let tmuxFinder: TmuxHistoryFinder
    private let terminalIsOnAlternateScreen: () -> Bool
    /// Which finder the current search uses; nil between searches.
    private var searchesInTmux: Bool?
    private var query = ""

    init(
        terminalFinder: any TerminalTextFinding,
        tmuxHistory: TmuxHistory,
        terminalIsOnAlternateScreen: @escaping () -> Bool
    ) {
        self.terminalFinder = terminalFinder
        tmuxFinder = TmuxHistoryFinder(history: tmuxHistory)
        self.terminalIsOnAlternateScreen = terminalIsOnAlternateScreen
        tmuxFinder.onStepFinished = { [weak self] count in self?.tmuxStepFinished(count) }
    }

    func findText(_ query: String) -> TerminalFindMatchCount? {
        self.query = query
        guard !query.isEmpty else {
            endTextFind()
            onMatchCount?(nil)
            return nil
        }
        let searchesInTmux = searchesInTmux ?? terminalIsOnAlternateScreen()
        self.searchesInTmux = searchesInTmux
        if searchesInTmux {
            _ = tmuxFinder.findText(query)
        } else {
            report(terminalFinder.findText(query))
        }
        return nil
    }

    func findTextAgain(_ query: String, direction: TerminalFindDirection) -> TerminalFindMatchCount? {
        guard let searchesInTmux else { return findText(query) }
        self.query = query
        if searchesInTmux {
            _ = tmuxFinder.findTextAgain(query, direction: direction)
        } else {
            report(terminalFinder.findTextAgain(query, direction: direction))
        }
        return nil
    }

    func endTextFind() {
        switch searchesInTmux {
        case true?: tmuxFinder.endTextFind()
        case false?: terminalFinder.endTextFind()
        case nil: break
        }
        searchesInTmux = nil
    }

    private func tmuxStepFinished(_ count: TerminalFindMatchCount?) {
        guard searchesInTmux == true else { return }
        guard count == nil else {
            report(count)
            return
        }
        tmuxFinder.endTextFind()
        searchesInTmux = false
        report(terminalFinder.findText(query))
    }

    /// The terminal searches even with no one to tell, as `onMatchCount?(…)` would skip its argument.
    private func report(_ count: TerminalFindMatchCount?) {
        onMatchCount?(count)
    }
}
