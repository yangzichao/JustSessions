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
            preferredEntryID = nil
            isSearching = !query.isEmpty
        }
    }
    var isFieldFocused = false
    private(set) var matches: [TranscriptSearchMatch] = []
    private(set) var selectedMatchIndex: Int?
    private(set) var isSearching = false
    private(set) var navigationRevision = 0
    private(set) var focusRevision = 0
    private(set) var focusesFieldOnOpen = true
    private(set) var preferredEntryID: Int?

    var selectedMatch: TranscriptSearchMatch? {
        selectedMatchIndex.flatMap { matches.indices.contains($0) ? matches[$0] : nil }
    }

    func show() {
        isPresented = true
        focusesFieldOnOpen = true
        focusRevision += 1
    }

    func reveal(_ query: String, at entryID: Int) {
        self.query = query
        preferredEntryID = entryID
        if !isPresented { focusesFieldOnOpen = false }
        isPresented = true
    }

    func close() {
        isPresented = false
        isFieldFocused = false
        isSearching = false
        matches = []
        selectedMatchIndex = nil
        preferredEntryID = nil
    }

    func beginSearch() {
        isSearching = !query.isEmpty
    }

    func update(matches: [TranscriptSearchMatch], preservingSelection: Bool) {
        let earlierMatch = preservingSelection ? selectedMatch : nil
        self.matches = matches
        if let preferredMatchIndex = preferredMatchIndex(in: matches) {
            selectedMatchIndex = preferredMatchIndex
        } else {
            selectedMatchIndex = earlierMatch.flatMap { matches.firstIndex(of: $0) } ?? (matches.isEmpty ? nil : 0)
        }
        isSearching = false
        if selectedMatch != earlierMatch { navigationRevision += 1 }
    }

    func move(forward: Bool) {
        guard !isSearching, !matches.isEmpty else { return }
        preferredEntryID = nil
        let currentIndex = selectedMatchIndex ?? 0
        selectedMatchIndex = (currentIndex + (forward ? 1 : matches.count - 1)) % matches.count
        navigationRevision += 1
    }

    private func preferredMatchIndex(in matches: [TranscriptSearchMatch]) -> Int? {
        guard let preferredEntryID else { return nil }
        let preferredRecord = TranscriptPageIdentity.record(for: preferredEntryID)
        return matches.firstIndex { TranscriptPageIdentity.record(for: $0.entryIndex) >= preferredRecord }
    }
}
