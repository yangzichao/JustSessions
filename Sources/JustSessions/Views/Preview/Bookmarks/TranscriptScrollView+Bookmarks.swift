import AppKit
import SwiftUI

extension TranscriptScrollView {
    var bookmarksAreEnabled: Bool { store != nil && paging != nil }

    var bookmarks: [MessageBookmark] { store?.messageBookmarks.bookmarks(forConversationID: conversation.id) ?? [] }

    var bookmarkCommandTarget: TranscriptBookmarkCommandTarget? {
        guard bookmarksAreEnabled else { return nil }
        return TranscriptBookmarkCommandTarget(
            toggleBookmark: toggleBookmarkOnMessageBeingRead,
            goToAdjacentBookmark: goToAdjacentBookmark(forward:),
            contextMenuItems: bookmarkMenuItems(forEntryAt:),
            editBookmark: editBookmarkOnMessageBeingRead,
            toggleBookmarkOnEntry: { entryID in loadedMessage(entryID).map(toggleBookmark(on:)) },
            editBookmarkOnEntry: { entryID in loadedMessage(entryID).map(editBookmark(on:)) })
    }

    var bookmarkMenu: TranscriptBookmarkMenu? {
        guard bookmarksAreEnabled else { return nil }
        return TranscriptBookmarkMenu(
            bookmarks: bookmarks, assistantName: conversation.provider.rawValue,
            onGoTo: goToBookmark, onGoToAdjacent: goToAdjacentBookmark(forward:),
            onToggle: toggleBookmarkOnMessageBeingRead, onEdit: editBookmarkOnMessageBeingRead,
            onRemoveAll: removeAllBookmarks)
    }

    var messageBeingRead: TranscriptEntry? {
        if positionController.pointerMovedSinceSeek || positionController.seekTarget == nil,
            let entryID = positionController.entryIDAtPointer(),
            let entry = MessageBookmarkNavigation.message(at: entryID, in: transcript.entries)
        {
            return entry
        }
        return MessageBookmarkNavigation.messageBeingRead(
            in: transcript.entries,
            visibleEntryIDs: positionController.visibleEntryIDs(minimumVisibleHeight: MessageBookmarkNavigation.minimumVisibleHeight),
            seekTarget: positionController.seekTarget)
    }

    func updateBookmarkTarget() {
        guard bookmarksAreEnabled, isActive, bookmarkState.loadingJump == nil, bookmarkState.loadingEntryJump == nil,
            let entry = messageBeingRead, let frame = positionController.entryFrameInStack(at: entry.id)
        else {
            bookmarkState.target.show(nil)
            return
        }
        bookmarkState.target.show(
            TranscriptBookmarkTarget.Shown(
                entryID: entry.id, frame: frame, topPadding: TranscriptEntryView.topPadding(startsTurn: entry.startsTurn)))
    }

    private func loadedMessage(_ entryID: Int) -> TranscriptEntry? {
        guard bookmarksAreEnabled, bookmarkState.loadingJump == nil, bookmarkState.loadingEntryJump == nil,
            let entry = transcript.entries.first(where: { $0.id == entryID }), MessageBookmark.Kind(entry.content) != nil
        else { return nil }
        return entry
    }

    func toggleBookmarkOnMessageBeingRead() {
        guard bookmarksAreEnabled, bookmarkState.loadingJump == nil, bookmarkState.loadingEntryJump == nil else { return }
        guard let entry = messageBeingRead else {
            bookmarkState.show(.nothingToBookmark)
            return
        }
        toggleBookmark(on: entry)
    }

    func editBookmarkOnMessageBeingRead() {
        guard bookmarksAreEnabled, bookmarkState.loadingJump == nil, bookmarkState.loadingEntryJump == nil else { return }
        guard let entry = messageBeingRead else {
            bookmarkState.show(.nothingToBookmark)
            return
        }
        editBookmark(on: entry)
    }

    func editBookmark(on entry: TranscriptEntry) {
        switch store?.ensureMessageBookmark(on: entry, in: conversation) {
        case .existing(let bookmark), .added(let bookmark):
            bookmarkState.dismissNotice()
            bookmarkState.editor.open(bookmark, in: conversation)
        case .allLettersInUse: bookmarkState.show(.allLettersInUse)
        case nil: break
        }
    }

    func toggleBookmark(on entry: TranscriptEntry) {
        switch store?.toggleMessageBookmark(on: entry, in: conversation) {
        case .allLettersInUse: bookmarkState.show(.allLettersInUse)
        case .added, .removed: bookmarkState.dismissNotice()
        case nil: break
        }
    }

    func goToAdjacentBookmark(forward: Bool) {
        guard bookmarksAreEnabled else { return }
        let bookmarks = bookmarks
        guard !bookmarks.isEmpty else {
            bookmarkState.show(.noBookmarks)
            return
        }
        let origin =
            bookmarkState.loadingJump?.entryID ?? bookmarkState.loadingEntryJump ?? positionController.seekTarget
            ?? messageBeingRead?.id
            ?? positionController.visibleEntryIDs(minimumVisibleHeight: MessageBookmarkNavigation.minimumVisibleHeight).first
        let target =
            forward
            ? MessageBookmarkNavigation.bookmark(after: origin, in: bookmarks)
            : MessageBookmarkNavigation.bookmark(before: origin, in: bookmarks)
        if let target { goToBookmark(target) }
    }

    func goToBookmark(_ bookmark: MessageBookmark) {
        guard bookmarksAreEnabled, let paging else { return }
        bookmarkState.dismissNotice()
        guard !paging.isLoading else {
            loadBookmarkJump(to: bookmark)
            return
        }
        switch MessageBookmarkNavigation.locate(bookmark, in: transcript.entries, hasEarlier: paging.hasEarlier, hasLater: paging.hasLater)
        {
        case .found(let entry):
            positionController.seek(toEntryAt: entry.id)
            refreshBookmark(bookmark, foundAt: entry)
            bookmarkState.announce(AppLocalization.string("Bookmark \(bookmark.letter)"))
        case .missing(let landingEntryID):
            if let last = transcript.entries.last,
                TranscriptPageIdentity.record(for: bookmark.entryID) > TranscriptPageIdentity.record(for: last.id)
            {
                loadBookmarkJump(to: bookmark)
                return
            }
            positionController.seek(toEntryAt: landingEntryID)
            positionController.setSeekTarget(bookmark.entryID)
            bookmarkState.show(.missing(bookmark))
        case .notLoaded:
            loadBookmarkJump(to: bookmark)
        }
    }

    private func loadBookmarkJump(to bookmark: MessageBookmark) {
        guard let paging else { return }
        if searchState.isPresented { searchState.close() }
        bookmarkState.startLoadingJump(bookmark)
        positionController.setSeekTarget(bookmark.entryID)
        paging.refresh(conversation, position: .startOfEntry(bookmark.entryID))
    }

    func settleBookmarkJump() {
        guard let paging, !paging.isLoading, let transcript = paging.transcript, !transcript.entries.isEmpty,
            let bookmark = bookmarkState.finishLoadingJump()
        else { return }
        switch MessageBookmarkNavigation.locate(bookmark, in: transcript.entries, hasEarlier: paging.hasEarlier, hasLater: paging.hasLater)
        {
        case .found(let entry):
            if entry.id == bookmark.entryID {
                positionController.setSeekTarget(entry.id, recordingPosition: true)
            } else {
                positionController.seek(toEntryAt: entry.id)
            }
            refreshBookmark(bookmark, foundAt: entry)
            bookmarkState.announce(AppLocalization.string("Bookmark \(bookmark.letter)"))
        case .missing, .notLoaded:
            positionController.setSeekTarget(bookmark.entryID, recordingPosition: true)
            bookmarkState.show(.missing(bookmark))
        }
    }

    func forgetBookmarkJump() {
        bookmarkState.cancelLoadingJump()
        positionController.clearSeekTarget()
    }

    func removeBookmark(_ bookmark: MessageBookmark) {
        store?.removeMessageBookmark(bookmark, in: conversation)
        bookmarkState.dismissNotice()
    }

    func removeAllBookmarks() {
        store?.removeAllMessageBookmarks(in: conversation)
        bookmarkState.dismissNotice()
    }

    func bookmarkMenuItems(forEntryAt entryID: Int) -> [NSMenuItem] {
        guard bookmarksAreEnabled, let entry = transcript.entries.first(where: { $0.id == entryID }),
            MessageBookmark.Kind(entry.content) != nil
        else { return [] }
        let bookmarks = bookmarks
        if let bookmark = bookmarks.first(where: { $0.entryID == entryID }) {
            return [
                ActionMenuItem(title: AppLocalization.string("Remove bookmark \(bookmark.letter)"), systemImage: "bookmark.slash") {
                    toggleBookmark(on: entry)
                },
                ActionMenuItem(title: AppLocalization.string("Edit bookmark \(bookmark.letter)…"), systemImage: "pencil") {
                    editBookmark(on: entry)
                },
            ]
        }
        guard bookmarks.count < MessageBookmarks.letters.count else {
            // The stock menu enables every item that has an action, whatever isEnabled says; these have none.
            let add = NSMenuItem(title: AppLocalization.string("Add bookmark"), action: nil, keyEquivalent: "")
            add.image = NSImage(systemSymbolName: "bookmark", accessibilityDescription: nil)
            return [
                add,
                NSMenuItem(
                    title: AppLocalization.string("All 26 letters are in use. Remove a bookmark to add another."), action: nil,
                    keyEquivalent: ""),
            ]
        }
        return [ActionMenuItem(title: AppLocalization.string("Add bookmark"), systemImage: "bookmark") { toggleBookmark(on: entry) }]
    }

    private func refreshBookmark(_ bookmark: MessageBookmark, foundAt entry: TranscriptEntry) {
        let snippet = MessageBookmarkNavigation.snippet(of: entry) ?? bookmark.snippet
        guard entry.id != bookmark.entryID || snippet.count > bookmark.snippet.count else { return }
        store?.updateMessageBookmark(bookmark, entryID: entry.id, snippet: snippet, in: conversation)
    }
}
