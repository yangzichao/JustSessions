import Observation

@MainActor
@Observable
final class TerminalFindState {
    private(set) var isPresented = false
    var query = "" {
        didSet {
            guard query != oldValue, isPresented else { return }
            showCount(finder.findText(query))
        }
    }
    private(set) var matchCount: TerminalFindMatchCount?
    var isFieldFocused = false
    private(set) var focusRevision = 0
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
