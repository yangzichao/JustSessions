import SwiftUI

extension TranscriptScrollView {
    func showFirstMessage() {
        if let paging { paging.first(); return }
        guard let index = displayedEntryIndices.first else { return }
        positionController.restore(.entry(index: index, offset: -6))
        visibleEntryIndex = index
    }

    func showLatestMessage() {
        if let paging { paging.latest(); return }
        positionController.restore(.bottom)
        visibleEntryIndex = displayedEntryIndices.last
    }

    func loadEarlierPage() {
        paging?.earlier(preserving: positionController.recordedPosition ?? .bottom)
    }

    func loadLaterPage() {
        paging?.later(preserving: positionController.recordedPosition ?? .bottom)
    }

    func prefetchIfNeeded() {
        guard isActive, let paging, !paging.isLoading, !searchState.isPresented, !positionController.isRestoring,
              let visibleEntryIndex, let offset = displayedEntryIndices.firstIndex(of: visibleEntryIndex) else { return }
        if offset < 5, paging.hasEarlier {
            loadEarlierPage()
        } else if offset >= displayedEntryIndices.count - 5, paging.hasLater {
            loadLaterPage()
        }
    }

    func restorePagedPosition(using scrollProxy: ScrollViewProxy) {
        guard let paging else { return }
        // Old indexes and snapshots must not keep pages alive after eviction, even while Find is closed.
        searchIndex = nil
        indexedTranscript = nil
        positionController.tracksTranscriptBottom = !paging.hasLater
        positionController.restore(paging.restorationPosition)
        visibleEntryIndex = paging.restorationPosition.entryIndex
        if let index = paging.restorationPosition.entryIndex { scrollProxy.scrollTo(index, anchor: .top) }
    }
}
