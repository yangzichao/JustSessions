import Foundation
import Testing
@testable import JustSessions

struct TranscriptPagingViewportTests {
    @Test func prefetchesWithinOneScreenOfEitherEdge() {
        let document = CGRect(x: 0, y: 0, width: 780, height: 10_000)
        let nearTop = TranscriptPagingViewport(document: document, visible: CGRect(x: 0, y: 350, width: 780, height: 480))
        let middle = TranscriptPagingViewport(document: document, visible: CGRect(x: 0, y: 4_000, width: 780, height: 480))
        let nearBottom = TranscriptPagingViewport(document: document, visible: CGRect(x: 0, y: 9_200, width: 780, height: 480))
        #expect(nearTop.prefetchDirection(hasEarlier: true, hasLater: true, retainedPageCount: 3) == .earlier)
        #expect(middle.prefetchDirection(hasEarlier: true, hasLater: true, retainedPageCount: 3) == nil)
        #expect(nearBottom.prefetchDirection(hasEarlier: true, hasLater: true, retainedPageCount: 3) == .later)
        #expect(nearTop.prefetchDirection(hasEarlier: false, hasLater: true, retainedPageCount: 3) == nil)
        #expect(nearBottom.prefetchDirection(hasEarlier: true, hasLater: false, retainedPageCount: 3) == nil)
    }

    /// The geometry the reader bounced in: three pages of a few screenshots each in a 1,308-point viewport. Dropping
    /// the far page brought the viewport within prefetch distance of the new edge, so that page loaded straight back
    /// and pushed out the one just loaded, over and over.
    @Test func pagesTheReaderIsNearStayWhenAPageLoadsAtTheOtherEnd() {
        let viewport = TranscriptPagingViewport(document: CGRect(x: 0, y: 0, width: 2_220, height: 3_558),
                                               visible: CGRect(x: 0, y: 384, width: 2_220, height: 1_308))
        #expect(viewport.retainedPageCount(afterLoading: .earlier, pageStarts: [40, 1_300, 2_500]) == 4)
        #expect(viewport.retainedPageCount(afterLoading: .later, pageStarts: [40, 1_300, 2_500]) == 4)
    }

    @Test func pagesClearOfTheViewportLeaveAsUsual() {
        let viewport = TranscriptPagingViewport(document: CGRect(x: 0, y: 0, width: 780, height: 30_000),
                                               visible: CGRect(x: 0, y: 15_000, width: 780, height: 1_308))
        #expect(viewport.retainedPageCount(afterLoading: .earlier, pageStarts: [0, 9_000, 20_000]) == 3)
        #expect(viewport.retainedPageCount(afterLoading: .later, pageStarts: [0, 9_000, 20_000]) == 3)
        // Only as many leave as the usual three-page budget needs.
        #expect(viewport.retainedPageCount(afterLoading: .later, pageStarts: [0, 9_000]) == 3)
        // A page with no laid-out rows starts where the next one does, so it leaves with the clear page after it.
        #expect(viewport.retainedPageCount(afterLoading: .earlier, pageStarts: [0, 9_000, nil, 20_000]) == 3)
    }

    @Test func pagesNearTheViewportStayOnlyUpToTheRetentionLimit() {
        let viewport = TranscriptPagingViewport(document: CGRect(x: 0, y: 0, width: 780, height: 2_000),
                                               visible: CGRect(x: 0, y: 500, width: 780, height: 1_000))
        let pageStarts: [CGFloat?] = (0..<TranscriptPagingModel.maximumRetainedPageCount).map { CGFloat($0 * 200) }
        #expect(viewport.retainedPageCount(afterLoading: .earlier, pageStarts: pageStarts) == TranscriptPagingModel.maximumRetainedPageCount)
    }

    @Test func shortPagesFillOnlyToTheMemoryLimitInsteadOfCyclingBetweenEdges() {
        let viewport = TranscriptPagingViewport(document: CGRect(x: 0, y: 0, width: 780, height: 600),
                                               visible: CGRect(x: 0, y: 0, width: 780, height: 480))
        #expect(viewport.prefetchDirection(hasEarlier: true, hasLater: true, retainedPageCount: 1) == .earlier)
        #expect(viewport.prefetchDirection(hasEarlier: false, hasLater: true, retainedPageCount: 2) == .later)
        #expect(viewport.prefetchDirection(hasEarlier: true, hasLater: true, retainedPageCount: 3) == nil)
    }
}
