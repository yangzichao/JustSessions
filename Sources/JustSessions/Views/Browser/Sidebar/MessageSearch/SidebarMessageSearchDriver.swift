import SwiftUI

/// Runs a window's search through every session's messages again whenever its text, the listed sessions, the CLIs
/// hidden in Settings, or the sessions the indexer has read change. Draws nothing.
struct SidebarMessageSearchDriver: View {
    @ObservedObject var indexer: SessionMessageIndexer
    let search: SidebarMessageSearch
    let typedQuery: String
    let conversations: [Conversation]
    let conversationsRevision: Int
    let hiddenProviders: HiddenConversationProviders

    private struct SearchInputs: Equatable {
        let typedQuery: String
        let conversationsRevision: Int
        let hiddenProviders: HiddenConversationProviders
        let indexRevision: Int
    }

    var body: some View {
        Color.clear
            .task(id: SearchInputs(
                typedQuery: typedQuery,
                conversationsRevision: conversationsRevision,
                hiddenProviders: hiddenProviders,
                indexRevision: indexer.revision
            )) {
                await search.run(typedQuery: typedQuery, conversations: conversations, indexer: indexer)
            }
            .onDisappear { search.stop(indexer: indexer) }
    }
}
