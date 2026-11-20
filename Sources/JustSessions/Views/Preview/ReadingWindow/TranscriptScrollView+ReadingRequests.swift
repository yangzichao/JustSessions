import SwiftUI

extension TranscriptScrollView {
    func takeReadingNavigation() {
        guard isActive, let navigation = readingRequests?.takeNavigation() else { return }
        switch navigation {
        case .adjacentBookmark(let forward): goToAdjacentBookmark(forward: forward)
        case .bookmark(let requested):
            let record = TranscriptPageIdentity.record(for: requested.entryID)
            goToBookmark(
                bookmarks.first { $0.letter == requested.letter && TranscriptPageIdentity.record(for: $0.entryID) == record } ?? requested)
        case .entry(let entryID): goToEntry(entryID)
        }
    }

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
            positionController.seek(toEntryAt: target.id)
            return
        }
        if searchState.isPresented { searchState.close() }
        bookmarkState.startLoadingEntryJump(entryID)
        positionController.setSeekTarget(entryID)
        paging.refresh(conversation, position: .startOfEntry(entryID))
    }

    func settleEntryJump() {
        guard let paging, !paging.isLoading, let ids = paging.transcript?.positionIDs, let last = ids.last,
            let entryID = bookmarkState.finishLoadingEntryJump()
        else { return }
        positionController.setSeekTarget(ids.first { $0 >= entryID } ?? last, recordingPosition: true)
    }
}
