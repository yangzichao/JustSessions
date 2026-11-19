import Foundation

@MainActor
final class PlainTerminalFinder: TerminalTextFindingCountingLater {
    var onMatchCount: ((TerminalFindMatchCount?) -> Void)?

    private let terminalFinder: any TerminalTextFinding
    private let tmuxFinder: TmuxHistoryFinder
    private let terminalIsOnAlternateScreen: () -> Bool
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
        tmuxFinder.onStepFinished = { [weak self] outcome in self?.tmuxStepFinished(outcome) }
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

    private func tmuxStepFinished(_ outcome: TmuxHistorySearchOutcome) {
        guard searchesInTmux == true else { return }
        switch outcome {
        case .searched(let count):
            report(count)
        case .couldNotSearch:
            tmuxFinder.endTextFind()
            searchesInTmux = false
            report(terminalFinder.findText(query))
        }
    }

    private func report(_ count: TerminalFindMatchCount?) {
        onMatchCount?(count)
    }
}
