import SwiftUI

/// Read-only conversation for one session, loaded off the main actor.
struct TranscriptView: View {
    let conversation: Conversation
    let readingPositionStore: TranscriptReadingPositionStore
    var isActive = true

    private struct LoadKey: Equatable {
        let conversationID: String
        let updatedAt: Date
    }

    @State private var paging = TranscriptPagingModel()

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: LoadKey(conversationID: conversation.id, updatedAt: conversation.updatedAt)) {
                if isActive, TranscriptLoader.supportsReading(conversation.provider) {
                    paging.refresh(conversation, position: readingPositionStore.position(for: conversation.id))
                }
            }
            .onChange(of: isActive) {
                if isActive, TranscriptLoader.supportsReading(conversation.provider) {
                    paging.refresh(conversation, position: readingPositionStore.position(for: conversation.id))
                } else { paging.cancel() }
            }
            .onDisappear { paging.cancel() }
    }

    @ViewBuilder
    private var content: some View {
        if !TranscriptLoader.supportsReading(conversation.provider) {
            ContentUnavailableView(
                "Preview not available",
                systemImage: "eye.slash",
                description: Text("JustSessions can't read \(conversation.provider.rawValue) conversations yet. Resume the session to see it.")
            )
        } else if let transcript = paging.transcript, !transcript.entries.isEmpty {
            TranscriptScrollView(conversation: conversation, transcript: transcript, positionStore: readingPositionStore,
                                 isActive: isActive, paging: paging)
        } else if let message = paging.errorMessage {
            VStack {
                ContentUnavailableView("Could not read this session", systemImage: "exclamationmark.triangle", description: Text(message))
                Button("Try again") { paging.refresh(conversation, position: readingPositionStore.position(for: conversation.id)) }
                    .buttonStyle(.borderless)
            }
        } else if paging.transcript != nil {
            ContentUnavailableView("No messages yet", systemImage: "text.bubble")
        } else {
            ProgressView().controlSize(.small)
        }
    }
}
