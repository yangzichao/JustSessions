import SwiftUI

/// What a reading window does when a tab or the conversation map asks it to go somewhere (RDR-50); see
/// `SessionReadingRequests`.
extension TranscriptScrollView {
    func takeReadingNavigation() {
        guard isActive, let navigation = readingRequests?.takeNavigation() else { return }
        switch navigation {
        case .adjacentBookmark(let forward): goToAdjacentBookmark(forward: forward)
        case .bookmark(let requested):
            // As saved now: another window may have moved its entry ID within the record or grown its snippet.
            let record = TranscriptPageIdentity.record(for: requested.entryID)
            goToBookmark(
                bookmarks.first { $0.letter == requested.letter && TranscriptPageIdentity.record(for: $0.entryID) == record } ?? requested)
        case .entry(let entryID): goToEntry(entryID)
        }
    }

    /// A map click: the entry at the top, loading its page when it isn't loaded, lies past the pages loaded (an open
    /// window's pages are older than the file, TranscriptView.swift:39), or another page is loading. It becomes the seek
    /// target, so ⌘D, ⌘', and ⇧⌘' act from it (RDR-48 rule 1).
    func goToEntry(_ entryID: Int) {
        guard let paging else { return }
        bookmarkState.dismissNotice()
        let record = TranscriptPageIdentity.record(for: entryID)
        let entries = transcript.entries
        if !paging.isLoading, let first = entries.first, let last = entries.last,
            record >= TranscriptPageIdentity.record(for: first.id) || !paging.hasEarlier,
            record <= TranscriptPageIdentity.record(for: last.id),
            let target = entries.first(where: { $0.id >= entryID })
        {
            bookmarkState.cancelLoadingJump()
            positionController.seek(toEntryAt: target.id)  // records, restores, seeks (TranscriptScrollPositionController.swift:249-254)
            return
        }
        if searchState.isPresented { searchState.close() }  // a new page would select Find's first match
        bookmarkState.startLoadingEntryJump(entryID)
        positionController.setSeekTarget(entryID)
        // Cancels a page in flight (TranscriptPagingModel.swift:76).
        paging.refresh(conversation, position: .entry(index: entryID, offset: -6))
    }

    /// After the entry jump's page restored the first entry at or after it to the top.
    func settleEntryJump() {
        guard let paging, !paging.isLoading, let ids = paging.transcript?.positionIDs, let last = ids.last,
            let entryID = bookmarkState.finishLoadingEntryJump()
        else { return }
        positionController.setSeekTarget(ids.first { $0 >= entryID } ?? last, recordingPosition: true)
    }
}
