import SwiftUI

struct TranscriptView: View {
    let conversation: Conversation
    let readingPositionStore: TranscriptReadingPositionStore
    var isActive = true
    var matchReveal: TranscriptMatchReveal?
    var readingRequests: SessionReadingRequests? = nil
    var onOpenInNewWindow: (() -> Void)?
    var store: ConversationStore? = nil

    private struct LoadKey: Equatable {
        let conversationID: String
        let updatedAt: Date
    }

    @State private var paging = TranscriptPagingModel()
    @State private var searchState = TranscriptSearchState()
    @State private var shownMatchRevealID: UUID?
    @State private var loadingMatchReveal: TranscriptMatchReveal?
    @State private var bookmarkState = TranscriptBookmarkState()
    @State private var loadingJumpCountAtMatchReveal = 0

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TranscriptBookmarkTargetReporter(target: waitingNavigationTarget, isActive: reportsWaitingNavigationTarget))
            .task(id: loadKey) { refreshIfActive() }
            .onChange(of: isActive) { activeChanged() }
            .onChange(of: matchReveal?.id) { refreshIfActive() }
            .onChange(of: findRevision, initial: true) { findRequested() }
            .onChange(of: navigationRevision) { readAgainForNavigation() }
            .onChange(of: paging.revision) { pagesArrived() }
            .onChange(of: paging.errorMessage) { readFailed() }
            .onDisappear { paging.cancel() }
    }

    // `body` calls these instead of holding their statements: Swift type-checks a closure's statements with the modifier
    // chain around it, and the release runner's compiler gave up on `body` with them inline.

    private var reportsWaitingNavigationTarget: Bool {
        isActive && readingRequests != nil && paging.transcript?.entries.isEmpty != false
    }

    private var loadKey: LoadKey { LoadKey(conversationID: conversation.id, updatedAt: conversation.updatedAt) }
    private var findRevision: Int { readingRequests?.findRevision ?? 0 }
    private var navigationRevision: Int { readingRequests?.navigationRevision ?? 0 }

    private func refreshIfActive() {
        if isActive { refresh() }
    }

    private func activeChanged() {
        if isActive { refresh() } else { paging.cancel() }
    }

    private func findRequested() {
        if findRevision > 0 { searchState.show() }
    }

    private func pagesArrived() {
        dropMatchRevealABookmarkJumpReplaced()
        if let loadingMatchReveal {
            if !loadingMatchReveal.query.isEmpty { searchState.reveal(loadingMatchReveal.query, at: loadingMatchReveal.entryID) }
            self.loadingMatchReveal = nil
        }
        if let bookmark = bookmarkState.loadingJump, pagesAreEmpty {
            bookmarkState.finishLoadingJump()
            bookmarkState.show(.missing(bookmark))
            bookmarkState.carrySeekTarget(bookmark.entryID)
            readingPositionStore.record(.bottom, for: conversation.id)
            paging.latest()
        }
        if bookmarkState.loadingEntryJump != nil, pagesAreEmpty {
            bookmarkState.finishLoadingEntryJump()
            readingPositionStore.record(.bottom, for: conversation.id)
            paging.latest()
        }
        if pagesAreEmpty, bookmarkState.loadingJump == nil, bookmarkState.loadingEntryJump == nil {
            takeNavigationMetByEmptyPage()
        }
    }

    private var pagesAreEmpty: Bool { paging.transcript?.entries.isEmpty == true }

    private func readFailed() {
        if paging.errorMessage != nil {
            bookmarkState.cancelLoadingJump()
            readingRequests?.discardNavigation()
        }
    }

    private var waitingNavigationTarget: TranscriptBookmarkCommandTarget? {
        guard let readingRequests, let store else { return nil }
        let conversationID = conversation.id
        return TranscriptBookmarkCommandTarget(
            toggleBookmark: {},
            goToAdjacentBookmark: { forward in
                let bookmarks = store.messageBookmarks.bookmarks(forConversationID: conversationID)
                if !bookmarks.isEmpty {
                    readingRequests.requestAdjacentBookmark(
                        forward: forward, in: bookmarks,
                        from: readingPositionStore.position(for: conversationID))
                }
            },
            contextMenuItems: { _ in [] })
    }

    @ViewBuilder
    private var content: some View {
        if let transcript = paging.transcript, !transcript.entries.isEmpty {
            TranscriptScrollView(
                conversation: conversation, transcript: transcript, positionStore: readingPositionStore,
                isActive: isActive, searchState: searchState, paging: paging, onOpenInNewWindow: onOpenInNewWindow,
                store: store, bookmarkState: bookmarkState, readingRequests: readingRequests)
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

    private func refresh() {
        if let matchReveal, matchReveal.id != shownMatchRevealID {
            shownMatchRevealID = matchReveal.id
            loadingMatchReveal = matchReveal
            loadingJumpCountAtMatchReveal = bookmarkState.loadingJumpCount
            bookmarkState.cancelLoadingJump()
            readingPositionStore.record(.startOfEntry(matchReveal.entryID), for: conversation.id)
        }
        dropMatchRevealABookmarkJumpReplaced()
        let position =
            loadingMatchReveal.map { TranscriptReadingPosition.startOfEntry($0.entryID) }
            ?? bookmarkState.loadingJump.map { TranscriptReadingPosition.startOfEntry($0.entryID) }
            ?? bookmarkState.loadingEntryJump.map { TranscriptReadingPosition.startOfEntry($0) }
            ?? readingPositionStore.position(for: conversation.id)
        paging.refresh(conversation, position: position)
    }

    private func readAgainForNavigation() {
        guard isActive, !paging.isLoading, paging.transcript?.entries.isEmpty != false,
            let navigation = readingRequests?.pendingNavigation
        else { return }
        if let entryID = navigation.entryID { readingPositionStore.record(.startOfEntry(entryID), for: conversation.id) }
        refresh()
    }

    private func takeNavigationMetByEmptyPage() {
        guard !paging.isLoading, let navigation = readingRequests?.pendingNavigation, let entryID = navigation.entryID else {
            readingRequests?.discardNavigation()
            return
        }
        guard readingPositionStore.position(for: conversation.id)?.entryIndex == entryID else {
            readAgainForNavigation()
            return
        }
        readingRequests?.discardNavigation()
        if case .bookmark(let bookmark) = navigation {
            bookmarkState.show(.missing(bookmark))
            bookmarkState.carrySeekTarget(entryID)
        }
        readingPositionStore.record(.bottom, for: conversation.id)
        paging.latest()
    }

    private func dropMatchRevealABookmarkJumpReplaced() {
        if loadingMatchReveal != nil, bookmarkState.loadingJumpCount != loadingJumpCountAtMatchReveal { loadingMatchReveal = nil }
    }
}
