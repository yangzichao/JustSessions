import Foundation
import Testing
@testable import JustSessions

@MainActor
struct TranscriptSearchContextTests {
    private static func controller() -> TranscriptScrollPositionController {
        TranscriptScrollPositionController(conversationID: "search-context", positionStore: TranscriptReadingPositionStore(), initialPosition: .bottom)
    }

    /// The transcript sets a new context each time its view updates, as it does while you scroll. Only a context that
    /// differs in what text blocks read may compare unequal, or every block updates and is remeasured each time.
    @Test func comparesOnlyWhatTextBlocksRead() {
        let controller = Self.controller()
        let match = TranscriptSearchMatch(entryIndex: 2, segmentIndex: 0, range: NSRange(location: 1, length: 3))
        let context = TranscriptSearchContext(query: "needle", selectedMatch: match, navigationRevision: 4, positionController: controller)
        var otherQuery = context
        otherQuery.query = "thread"
        var noSelection = context
        noSelection.selectedMatch = nil
        var nextRevision = context
        nextRevision.navigationRevision = 5
        var otherController = context
        otherController.positionController = Self.controller()

        #expect(context == TranscriptSearchContext(query: "needle", selectedMatch: match, navigationRevision: 4, positionController: controller))
        #expect(context != otherQuery)
        #expect(context != noSelection)
        #expect(context != nextRevision)
        #expect(context != otherController)
    }
}
