import Foundation
import Observation

@MainActor
@Observable
final class SidebarMessageSearch {
    private(set) var results = SessionMessageSearchResults.none
    let indexerUserID = UUID()
    static let typingPause: Duration = .milliseconds(120)

    func run(typedQuery: String, conversations: [Conversation], indexer: SessionMessageIndexer) async {
        guard let query = SessionMessageQuery(typedQuery) else {
            results = .none
            indexer.endUse(by: indexerUserID)
            return
        }
        indexer.beginUse(by: indexerUserID)
        await indexer.update(with: conversations, for: indexerUserID)
        do {
            try await Task.sleep(for: Self.typingPause)
            let matches = try await indexer.index.matches(for: query)
            try Task.checkCancellation()
            results = SessionMessageSearchResults(query: query.text, matchesByConversationID: matches)
        } catch {
        }
    }

    func stop(indexer: SessionMessageIndexer) {
        indexer.endUse(by: indexerUserID)
    }
}
