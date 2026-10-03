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

    @Test func shortPagesFillOnlyToTheMemoryLimitInsteadOfCyclingBetweenEdges() {
        let viewport = TranscriptPagingViewport(document: CGRect(x: 0, y: 0, width: 780, height: 600),
                                               visible: CGRect(x: 0, y: 0, width: 780, height: 480))
        #expect(viewport.prefetchDirection(hasEarlier: true, hasLater: true, retainedPageCount: 1) == .earlier)
        #expect(viewport.prefetchDirection(hasEarlier: false, hasLater: true, retainedPageCount: 2) == .later)
        #expect(viewport.prefetchDirection(hasEarlier: true, hasLater: true, retainedPageCount: 3) == nil)
    }
}
