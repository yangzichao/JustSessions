import SwiftUI

/// Runs a window's search through every session's messages again whenever its text, the listed sessions, or the
/// sessions the indexer has read change. Draws nothing.
struct SidebarMessageSearchDriver: View {
    @ObservedObject var indexer: SessionMessageIndexer
    let search: SidebarMessageSearch
    let typedQuery: String
    let conversations: [Conversation]
    let conversationsRevision: Int

    private struct SearchInputs: Equatable {
        let typedQuery: String
        let conversationsRevision: Int
        let indexRevision: Int
    }

    var body: some View {
        Color.clear
            .task(id: SearchInputs(typedQuery: typedQuery, conversationsRevision: conversationsRevision, indexRevision: indexer.revision)) {
                await search.run(typedQuery: typedQuery, conversations: conversations, indexer: indexer)
            }
            .onDisappear { search.stop(indexer: indexer) }
    }
}
