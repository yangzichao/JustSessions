import SwiftUI

extension TranscriptScrollView {
    func showFirstMessage() {
        if let paging { paging.first(); return }
        guard let index = displayedEntryIndices.first else { return }
        positionController.restore(.entry(index: index, offset: -6))
    }

    func showLatestMessage() {
        if let paging { paging.latest(); return }
        positionController.restore(.bottom)
    }

    func loadEarlierPage() {
        paging?.earlier(preserving: positionController.recordedPosition ?? .bottom,
                        currentPosition: { positionController.recordedPosition },
                        keepingPages: retainedPageCount(afterLoading: .earlier))
    }

    func loadLaterPage() {
        paging?.later(preserving: positionController.recordedPosition ?? .bottom,
                      currentPosition: { positionController.recordedPosition },
                      keepingPages: retainedPageCount(afterLoading: .later))
    }

    /// Keeps the pages the reader is near, so the one that loads does not push out a page it would load straight back.
    private func retainedPageCount(afterLoading direction: TranscriptPagingViewport.Direction) -> Int {
        guard let paging, let viewport = positionController.pagingViewport else { return TranscriptPagingModel.maximumPageCount }
        let pageStarts = paging.pages.map { page in
            page.entries.first.flatMap { positionController.documentMinY(ofEntryAt: $0.id) }
        }
        return viewport.retainedPageCount(afterLoading: direction, pageStarts: pageStarts)
    }

    func prefetchIfNeeded(in viewport: TranscriptPagingViewport? = nil) {
        guard isActive, let paging, !paging.isLoading, paging.errorMessage == nil, !searchState.isPresented,
              !positionController.isRestoring, restoredPagingRevision == paging.revision,
              let viewport = viewport ?? positionController.pagingViewport else { return }
        switch viewport.prefetchDirection(hasEarlier: paging.hasEarlier, hasLater: paging.hasLater, retainedPageCount: paging.pages.count) {
        case .earlier: loadEarlierPage()
        case .later: loadLaterPage()
        case nil: break
        }
    }

    func restorePagedPosition(using scrollProxy: ScrollViewProxy) {
        guard let paging else { return }
        restoredPagingRevision = paging.revision
        // Old indexes and snapshots must not keep pages alive after eviction, even while Find is closed.
        searchIndex = nil
        indexedTranscript = nil
        positionController.tracksTranscriptBottom = !paging.hasLater
        let position = paging.restorationPosition
        if let index = position.entryIndex, positionController.documentMinY(ofEntryAt: index) == nil {
            // The entry is new, as after going to the first message: SwiftUI brings its row into view first.
            positionController.restore(position)
            scrollProxy.scrollTo(index, anchor: .top)
        } else {
            positionController.restore(position, duringNextLayout: true)
        }
    }
}
