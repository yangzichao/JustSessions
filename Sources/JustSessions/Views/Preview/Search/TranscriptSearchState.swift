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
    /// Whether the field takes the keyboard as Find opens: not when a search through every session's messages opened
    /// it, so typing goes on in the sidebar's search.
    private(set) var focusesFieldOnOpen = true
    /// The entry whose match, or the first one after it, is selected each time the transcript is searched, until
    /// another match is chosen, the query changes, or Find closes; see `reveal(_:at:)`.
    private(set) var preferredEntryID: Int?

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
        focusesFieldOnOpen = true
        focusRevision += 1
    }

    /// Opens Find on `query` and selects its match in the entry `entryID`, where a search through every session's
    /// messages found it, or else the next match after it. The pages around the entry can arrive after the pages shown
    /// before are searched, so the preference outlasts one search.
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

    /// A paged transcript's entry IDs go by source record, the same in every page read around it.
    private func preferredMatchIndex(in matches: [TranscriptSearchMatch]) -> Int? {
        guard let preferredEntryID else { return nil }
        let preferredRecord = TranscriptPageIdentity.record(for: preferredEntryID)
        return matches.firstIndex { TranscriptPageIdentity.record(for: $0.entryIndex) >= preferredRecord }
    }
}
