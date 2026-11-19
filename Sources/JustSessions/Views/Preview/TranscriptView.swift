import SwiftUI

/// Read-only conversation for one session, loaded off the main actor.
struct TranscriptView: View {
    let conversation: Conversation
    let readingPositionStore: TranscriptReadingPositionStore
    var isActive = true
    /// Opens the reader at a match that a search through every session's messages found; see `TranscriptMatchReveal`.
    var matchReveal: TranscriptMatchReveal?
    /// Find and navigation from a tab or the map; see `SessionReadingRequests`.
    var readingRequests: SessionReadingRequests? = nil
    /// Shown as a reading toolbar button; see `TranscriptReadingToolbar.onOpenInNewWindow`.
    var onOpenInNewWindow: (() -> Void)?
    /// Keeps the session's message bookmarks; nil leaves bookmarks out, as in tests.
    var store: ConversationStore? = nil

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
    @State private var bookmarkState = TranscriptBookmarkState()
    /// `bookmarkState.loadingJumpCount` when the loading reveal asked for its pages.
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

    /// Only while no scroll view shows (its own reporter is TranscriptScrollView.swift:91), so a window has one.
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

    /// Opens Find at a reveal whose pages arrived, and shows the latest messages when a jump's page came back empty.
    private func pagesArrived() {
        dropMatchRevealABookmarkJumpReplaced()
        if let loadingMatchReveal {
            if !loadingMatchReveal.query.isEmpty { searchState.reveal(loadingMatchReveal.query, at: loadingMatchReveal.entryID) }
            self.loadingMatchReveal = nil
        }
        // A bookmark's page can hold only records the reader hides, as at the end of a file; "No messages yet"
        // would offer no way back. Show the latest messages and say the message is gone.
        if let bookmark = bookmarkState.loadingJump, pagesAreEmpty {
            bookmarkState.finishLoadingJump()
            bookmarkState.show(.missing(bookmark))
            bookmarkState.carrySeekTarget(bookmark.entryID)
            readingPositionStore.record(.bottom, for: conversation.id)
            paging.latest()
        }
        // A map click's page holding no message shows the latest instead, as a bookmark's does.
        if bookmarkState.loadingEntryJump != nil, pagesAreEmpty {
            bookmarkState.finishLoadingEntryJump()
            readingPositionStore.record(.bottom, for: conversation.id)
            paging.latest()
        }
        if pagesAreEmpty, bookmarkState.loadingJump == nil, bookmarkState.loadingEntryJump == nil {
            takeNavigationMetByEmptyPage()
        }
    }

    /// Read again at each use: `paging.latest()` above may change the pages.
    private var pagesAreEmpty: Bool { paging.transcript?.entries.isEmpty == true }

    /// The error shows under the pages; nothing waits for the jump's page.
    private func readFailed() {
        if paging.errorMessage != nil {
            bookmarkState.cancelLoadingJump()
            readingRequests?.discardNavigation()
        }
    }

    /// ⌘' and ⇧⌘' while the window's first page loads, or it shows no messages: they add to the request waiting, or go on
    /// from where the window was left, since nothing is on screen to read from (RDR-50).
    private var waitingNavigationTarget: TranscriptBookmarkCommandTarget? {
        guard let readingRequests, let store else { return nil }
        let conversationID = conversation.id
        return TranscriptBookmarkCommandTarget(
            toggleBookmark: {},  // no message shows to bookmark
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

    /// Loads the pages at a match reveal not yet shown, or at a bookmark jump's message, or else where the reader was left.
    private func refresh() {
        if let matchReveal, matchReveal.id != shownMatchRevealID {
            shownMatchRevealID = matchReveal.id
            loadingMatchReveal = matchReveal
            loadingJumpCountAtMatchReveal = bookmarkState.loadingJumpCount
            bookmarkState.cancelLoadingJump()  // the newer request wins
            readingPositionStore.record(.entry(index: matchReveal.entryID, offset: -6), for: conversation.id)
        }
        dropMatchRevealABookmarkJumpReplaced()
        // Until the reveal's or the jump's pages arrive, the pages shown before still record where they are, such as the
        // bottom. A refresh in the meantime, as when the session's file changes, must not load those instead.
        let position =
            loadingMatchReveal.map { TranscriptReadingPosition.entry(index: $0.entryID, offset: -6) }
            ?? bookmarkState.loadingJump.map { TranscriptReadingPosition.entry(index: $0.entryID, offset: -6) }
            ?? bookmarkState.loadingEntryJump.map { TranscriptReadingPosition.entry(index: $0, offset: -6) }
            ?? readingPositionStore.position(for: conversation.id)
        paging.refresh(conversation, position: position)
    }

    /// With no pages shown (empty or unreadable before), a request reads the file again at what it asks for; the scroll
    /// view takes it once pages show. While a page loads it just waits.
    private func readAgainForNavigation() {
        guard isActive, !paging.isLoading, paging.transcript?.entries.isEmpty != false,
            let navigation = readingRequests?.pendingNavigation
        else { return }
        if let entryID = navigation.entryID { readingPositionStore.record(.entry(index: entryID, offset: -6), for: conversation.id) }
        refresh()
    }

    /// An empty page can take no request, and a later one must not replay it (RDR-50). A bookmark or message read where it
    /// asked, as one past the end of a rewritten file that ends in hidden records, shows the latest messages instead, as a
    /// jump's page does (above): the position it recorded would bring every later request back to the empty page. One
    /// that came while another place loaded reads its own place first. One met by a jump's empty page, which is already
    /// loading the latest (above), is dropped.
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

    /// A bookmark jump asked for its page after the reveal did, so the newer request wins: the page that arrives is the
    /// jump's, and Find must not open over it.
    private func dropMatchRevealABookmarkJumpReplaced() {
        if loadingMatchReveal != nil, bookmarkState.loadingJumpCount != loadingJumpCountAtMatchReveal { loadingMatchReveal = nil }
    }
}
