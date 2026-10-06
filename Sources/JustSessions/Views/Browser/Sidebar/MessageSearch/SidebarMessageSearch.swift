import Foundation
import Observation

/// One window's search through every session's messages: the latest results, which the sidebar lists until the
/// search is cleared. Results stay while the next query runs, so typing doesn't make rows blink.
@MainActor
@Observable
final class SidebarMessageSearch {
    private(set) var results = SessionMessageSearchResults.none
    /// The window's use of the indexer, held while its search has text.
    let indexerUserID = UUID()
    /// Typing pauses this long before a search runs, so one runs per pause rather than per keystroke.
    static let typingPause: Duration = .milliseconds(120)

    func match(for conversationID: String) -> SessionMessageMatch? {
        results.matchesByConversationID[conversationID]
    }

    /// Searches `conversations` for `typedQuery`, first bringing the indexer up to date with them.
    func run(typedQuery: String, conversations: [Conversation], indexer: SessionMessageIndexer) async {
        guard let query = SessionMessageQuery(typedQuery) else {
            results = .none
            indexer.endUse(by: indexerUserID)
            return
        }
        indexer.beginUse(by: indexerUserID)
        indexer.update(with: conversations)
        do {
            try await Task.sleep(for: Self.typingPause)
            let matches = try await indexer.index.matches(for: query)
            try Task.checkCancellation()
            results = SessionMessageSearchResults(query: query.text, matchesByConversationID: matches)
        } catch {
            // A newer query, newer sessions, or more read sessions run the search again.
        }
    }

    func stop(indexer: SessionMessageIndexer) {
        indexer.endUse(by: indexerUserID)
    }
}
