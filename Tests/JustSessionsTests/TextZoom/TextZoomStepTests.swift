import Testing
@testable import JustSessions

struct TextZoomStepTests {
    @Test func zoomingMovesOnePointWithinTheRangeAndActualSizeReturnsToTheDefault() {
        let range = 10.0...24.0
        #expect(TextZoomStep.zoomIn.size(after: 13, in: range, defaultSize: 13) == 14)
        #expect(TextZoomStep.zoomOut.size(after: 13, in: range, defaultSize: 13) == 12)
        #expect(TextZoomStep.zoomIn.size(after: 24, in: range, defaultSize: 13) == 24)
        #expect(TextZoomStep.zoomOut.size(after: 10, in: range, defaultSize: 13) == 10)
        #expect(TextZoomStep.actualSize.size(after: 20, in: range, defaultSize: 13) == 13)
    }
}
