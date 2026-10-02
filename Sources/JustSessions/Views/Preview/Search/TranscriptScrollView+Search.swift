import SwiftUI

extension TranscriptScrollView {
    struct SearchRequest: Equatable {
        let query: String
        let isPresented: Bool
        let transcript: TranscriptContent
    }

    /// Parsing and matching happen off the main actor; cancelled queries never replace newer results.
    func updateSearch() async {
        guard isActive, searchState.isPresented, !searchState.query.isEmpty else {
            searchState.update(matches: [], preservingSelection: false)
            return
        }
        let query = searchState.query
        let transcript = transcript
        let existingIndex = indexedTranscript == transcript ? searchIndex : nil
        let preservingSelection = indexedQuery == query
        searchState.beginSearch()
        do {
            try await Task.sleep(for: .milliseconds(120))
            let searchTask = Task.detached(priority: .userInitiated) {
                let index = try existingIndex ?? TranscriptSearchIndex(transcript: transcript)
                return (index, try index.matches(for: query))
            }
            let (index, matches) = try await withTaskCancellationHandler {
                try await searchTask.value
            } onCancel: {
                searchTask.cancel()
            }
            try Task.checkCancellation()
            searchIndex = index
            indexedTranscript = transcript
            indexedQuery = query
            searchState.update(matches: matches, preservingSelection: preservingSelection)
        } catch is CancellationError {
            // A newer query or conversation superseded this search.
        } catch {
            searchState.update(matches: [], preservingSelection: false)
        }
    }
}
