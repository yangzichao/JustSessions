import SwiftUI

/// Read-only conversation for one session, loaded off the main actor.
struct TranscriptView: View {
    let conversation: Conversation
    let readingPositionStore: TranscriptReadingPositionStore

    private enum LoadState: Equatable {
        case loading
        case loaded(TranscriptContent)
        case unsupported
        case failed(String)
    }

    private struct LoadKey: Equatable {
        let conversationID: String
        let updatedAt: Date
    }

    @State private var loadState: LoadState = .loading

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: LoadKey(conversationID: conversation.id, updatedAt: conversation.updatedAt)) {
                do {
                    switch try await TranscriptLoader.load(conversation) {
                    case .loaded(let transcript): loadState = .loaded(transcript)
                    case .unsupported: loadState = .unsupported
                    }
                } catch is CancellationError {
                    // A newer load replaced this one.
                } catch {
                    loadState = .failed(error.localizedDescription)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            ProgressView().controlSize(.small)
        case .unsupported:
            ContentUnavailableView(
                "Preview not available",
                systemImage: "eye.slash",
                description: Text("JustSessions can't read \(conversation.provider.rawValue) conversations yet. Resume the session to see it.")
            )
        case .failed(let message):
            ContentUnavailableView("Could not read this session", systemImage: "exclamationmark.triangle", description: Text(message))
        case .loaded(let transcript) where transcript.entries.isEmpty:
            ContentUnavailableView("No messages yet", systemImage: "text.bubble")
        case .loaded(let transcript):
            TranscriptScrollView(conversation: conversation, transcript: transcript, positionStore: readingPositionStore)
        }
    }
}
