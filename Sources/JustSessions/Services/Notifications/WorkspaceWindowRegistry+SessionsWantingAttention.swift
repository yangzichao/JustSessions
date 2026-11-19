import Foundation

extension WorkspaceWindowRegistry {
    func showSession(wantingAttention source: SessionAttentionSource, reattachingIn reattachingStore: ConversationStore? = nil) {
        if let store = stores.first(where: { $0.showTab(notifiedAbout: source) }) {
            bringForward(store)
        } else if let store = reattachingStore ?? stores.first {
            store.reattach(notifiedAbout: source)
            bringForward(store)
        }
    }
}
