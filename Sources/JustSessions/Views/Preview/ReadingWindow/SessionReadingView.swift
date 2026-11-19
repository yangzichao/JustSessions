import SwiftUI

struct SessionReadingView: View {
    let store: ConversationStore
    let conversation: Conversation
    let readingPositionStore: TranscriptReadingPositionStore
    let requests: SessionReadingRequests

    private var currentConversation: Conversation {
        store.conversation(withID: conversation.id) ?? conversation
    }

    var body: some View {
        let conversation = currentConversation
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(store.title(for: conversation))
                    .font(ThemeFont.title)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Label("Read only", systemImage: "book")
                    Text("·")
                    Text(conversation.provider.rawValue)
                    Text("·")
                    Text(store.projectDisplayName(forProjectPath: conversation.projectDirectoryKey))
                }
                .font(ThemeFont.caption)
                .foregroundStyle(ThemePalette.secondaryText)
                .lineLimit(1)
                .help(conversation.projectLocation.copyablePath)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            ThemeDivider()
            TranscriptView(
                conversation: conversation,
                readingPositionStore: readingPositionStore,
                readingRequests: requests,
                store: store.conversation(withID: conversation.id) == nil ? nil : store
            )
            .id(conversation.id)
        }
        .frame(minWidth: 400, minHeight: 300)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemePalette.contentSurface)
        .accessibilityIdentifier("preview.reading-window")
    }
}
