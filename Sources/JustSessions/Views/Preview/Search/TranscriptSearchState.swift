import Observation

@MainActor
@Observable
final class TranscriptSearchState {
    var isPresented = false
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            matches = []
            selectedMatchIndex = nil
            isSearching = !query.isEmpty
        }
    }
    var isFieldFocused = false
    private(set) var matches: [TranscriptSearchMatch] = []
    private(set) var selectedMatchIndex: Int?
    private(set) var isSearching = false
    private(set) var navigationRevision = 0
    private(set) var focusRevision = 0

    var selectedMatch: TranscriptSearchMatch? {
        selectedMatchIndex.flatMap { matches.indices.contains($0) ? matches[$0] : nil }
    }

    var resultLabel: String {
        if isSearching { return "Searching…" }
        if query.isEmpty { return "" }
        guard let selectedMatchIndex else { return "No matches" }
        return "\(selectedMatchIndex + 1) of \(matches.count)"
    }

    func show() {
        isPresented = true
        focusRevision += 1
    }

    func close() {
        isPresented = false
        isFieldFocused = false
        isSearching = false
        matches = []
        selectedMatchIndex = nil
    }

    func beginSearch() {
        isSearching = !query.isEmpty
    }

    func update(matches: [TranscriptSearchMatch], preservingSelection: Bool) {
        let earlierMatch = preservingSelection ? selectedMatch : nil
        self.matches = matches
        selectedMatchIndex = earlierMatch.flatMap { matches.firstIndex(of: $0) } ?? (matches.isEmpty ? nil : 0)
        isSearching = false
        if selectedMatch != earlierMatch { navigationRevision += 1 }
    }

    func move(forward: Bool) {
        guard !isSearching, !matches.isEmpty else { return }
        let currentIndex = selectedMatchIndex ?? 0
        selectedMatchIndex = (currentIndex + (forward ? 1 : matches.count - 1)) % matches.count
        navigationRevision += 1
    }
}
