import SwiftUI

/// A read-only session preview docked in a workspace pane: a compact header above the full transcript reader,
/// whose search, paging, and images work as in the preview and reading windows.
struct WorkspacePreviewPane: View {
    @ObservedObject var store: ConversationStore
    let conversationID: String
    let readingPositionStore: TranscriptReadingPositionStore

    var body: some View {
        if let conversation = store.conversation(withID: conversationID) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "book")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Read only")
                    Text(store.title(for: conversation))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(verbatim: conversation.provider.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Button {
                        store.closePane(.preview(conversationID))
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .help("Close pane")
                    .accessibilityLabel("Close pane")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ThemePalette.contentSurface)
                ThemeDivider()
                TranscriptView(conversation: conversation, readingPositionStore: readingPositionStore)
                    .id(conversation.id)
            }
            .background(ThemePalette.contentSurface)
        }
    }
}
