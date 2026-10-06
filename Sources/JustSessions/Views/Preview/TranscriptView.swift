import SwiftUI

/// Read-only conversation for one session, loaded off the main actor.
struct TranscriptView: View {
    let conversation: Conversation
    let readingPositionStore: TranscriptReadingPositionStore
    var isActive = true
    /// Opens the reader at a match that a search through every session's messages found; see `TranscriptMatchReveal`.
    var matchReveal: TranscriptMatchReveal?
    /// Shown as a reading toolbar button; see `TranscriptReadingToolbar.onOpenInNewWindow`.
    var onOpenInNewWindow: (() -> Void)?

    private struct LoadKey: Equatable {
        let conversationID: String
        let updatedAt: Date
    }

    @State private var paging = TranscriptPagingModel()
    @State private var searchState = TranscriptSearchState()
    /// The reveal the reader last opened at, so each opens it once.
    @State private var shownMatchRevealID: UUID?
    /// A reveal whose pages are loading; Find selects its match once they arrive.
    @State private var loadingMatchReveal: TranscriptMatchReveal?

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: LoadKey(conversationID: conversation.id, updatedAt: conversation.updatedAt)) {
                if isActive { refresh() }
            }
            .onChange(of: isActive) {
                if isActive { refresh() } else { paging.cancel() }
            }
            .onChange(of: matchReveal?.id) {
                if isActive { refresh() }
            }
            .onChange(of: paging.revision) {
                guard let loadingMatchReveal else { return }
                searchState.reveal(loadingMatchReveal.query, at: loadingMatchReveal.entryID)
                self.loadingMatchReveal = nil
            }
            .onDisappear { paging.cancel() }
    }

    @ViewBuilder
    private var content: some View {
        if let transcript = paging.transcript, !transcript.entries.isEmpty {
            TranscriptScrollView(conversation: conversation, transcript: transcript, positionStore: readingPositionStore,
                                 isActive: isActive, searchState: searchState, paging: paging, onOpenInNewWindow: onOpenInNewWindow)
        } else if let message = paging.errorMessage {
            VStack {
                ContentUnavailableView("Could not read this session", systemImage: "exclamationmark.triangle", description: Text(message))
                Button("Try again") { refresh() }
                    .buttonStyle(ThemePlainButtonStyle(horizontalPadding: 6, verticalPadding: 4))
            }
        } else if paging.transcript != nil {
            ContentUnavailableView("No messages yet", systemImage: "text.bubble")
        } else {
            ProgressView().controlSize(.small)
        }
    }

    /// Loads the pages at a match reveal not yet shown, or else where the reader was left.
    private func refresh() {
        if let matchReveal, matchReveal.id != shownMatchRevealID {
            shownMatchRevealID = matchReveal.id
            loadingMatchReveal = matchReveal
            readingPositionStore.record(.entry(index: matchReveal.entryID, offset: -6), for: conversation.id)
        }
        paging.refresh(conversation, position: readingPositionStore.position(for: conversation.id))
    }
}
