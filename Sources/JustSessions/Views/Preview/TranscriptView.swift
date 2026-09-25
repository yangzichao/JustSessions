import SwiftUI

/// Read-only conversation for one session, loaded off the main actor.
struct TranscriptView: View {
    let conversation: Conversation

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
            transcriptScrollView(transcript)
        }
    }

    private func transcriptScrollView(_ transcript: TranscriptContent) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if transcript.omittedEntryCount > 0 {
                    Text("\(transcript.omittedEntryCount) earlier entries are not shown. Resume the session to see all of it.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
                ForEach(transcript.entries) { entry in
                    TranscriptEntryView(
                        entry: entry,
                        assistantName: conversation.provider.rawValue,
                        assistantTint: conversation.provider.tintColor
                    )
                }
            }
            .frame(maxWidth: 820, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 6)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.bottom)
    }
}
