import Observation

@MainActor
@Observable
final class TerminalFindState {
    private(set) var isPresented = false
    var query = "" {
        didSet {
            guard query != oldValue, isPresented else { return }
            find(query)
        }
    }
    private(set) var matchCount: TerminalFindMatchCount?
    var isFieldFocused = false
    private(set) var focusRevision = 0
    private(set) var closeRevision = 0

    private enum Finder {
        case countingAtOnce(any TerminalTextFinding)
        case countingLater(any TerminalTextFindingCountingLater)
    }

    @ObservationIgnored private let finder: Finder

    init(finder: any TerminalTextFinding) {
        self.finder = .countingAtOnce(finder)
    }

    init(finder: any TerminalTextFindingCountingLater) {
        self.finder = .countingLater(finder)
        finder.onMatchCount = { [weak self] count in
            guard let self, self.isPresented else { return }
            self.matchCount = count
        }
    }

    func show() {
        if !isPresented {
            isPresented = true
            if !query.isEmpty { find(query) }
        }
        focusRevision += 1
    }

    func move(_ direction: TerminalFindDirection) {
        guard isPresented, !query.isEmpty else { return }
        switch finder {
        case .countingAtOnce(let finder): matchCount = finder.findTextAgain(query, direction: direction)
        case .countingLater(let finder): finder.findTextAgain(query, direction: direction)
        }
    }

    func close() {
        guard isPresented else { return }
        isPresented = false
        isFieldFocused = false
        matchCount = nil
        switch finder {
        case .countingAtOnce(let finder): finder.endTextFind()
        case .countingLater(let finder): finder.endTextFind()
        }
        closeRevision += 1
    }

    private func find(_ query: String) {
        switch finder {
        case .countingAtOnce(let finder): matchCount = finder.findText(query)
        case .countingLater(let finder): finder.findText(query)
        }
    }
}
