import SwiftUI

/// Right side of the window when no terminal tab is showing: the selected session's conversation.
struct SessionPreviewPane: View {
    @ObservedObject var store: ConversationStore
    let sessionSelection: SessionMultiSelection
    let onRename: (Conversation) -> Void
    let onDelete: (Conversation) -> Void

    @State private var readingPositionStore = TranscriptReadingPositionStore()

    private var previewedConversation: Conversation? {
        guard let conversationID = sessionSelection.onlySelectedConversationID else { return nil }
        return store.conversation(withID: conversationID)
    }

    var body: some View {
        Group {
            if sessionSelection.hasMultipleSelected {
                ContentUnavailableView(
                    "\(sessionSelection.selectedConversationIDs.count) sessions selected",
                    systemImage: "checklist",
                    description: Text("Right-click a selected row in the sidebar to resume, branch, or delete them.")
                )
            } else if let conversation = previewedConversation {
                VStack(spacing: 0) {
                    SessionPreviewHeader(
                        store: store,
                        conversation: conversation,
                        onRename: { onRename(conversation) },
                        onDelete: { onDelete(conversation) },
                        onRead: {
                            SessionReadingWindowManager.shared.open(
                                conversation, store: store, initialPosition: readingPositionStore.position(for: conversation.id)
                            )
                        }
                    )
                    ThemeDivider()
                    TranscriptView(conversation: conversation, readingPositionStore: readingPositionStore)
                        .id(conversation.id)
                }
            } else if store.isScanningThisMac && store.conversations.isEmpty {
                ContentUnavailableView("Scanning conversations", systemImage: "magnifyingglass")
            } else {
                ContentUnavailableView(
                    "No session selected",
                    systemImage: "text.bubble",
                    description: Text("Choose a session in the sidebar to read its conversation.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemePalette.contentSurface)
    }
}
