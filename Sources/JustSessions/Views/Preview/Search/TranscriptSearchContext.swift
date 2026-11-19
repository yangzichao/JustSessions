import AppKit
import SwiftUI

struct TranscriptSearchContext: Equatable {
    var query = ""
    var selectedMatch: TranscriptSearchMatch?
    var navigationRevision = 0
    var positionController: TranscriptScrollPositionController?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.query == rhs.query && lhs.selectedMatch == rhs.selectedMatch && lhs.navigationRevision == rhs.navigationRevision
            && lhs.positionController === rhs.positionController
    }
}

extension EnvironmentValues {
    @Entry var transcriptSearchContext = TranscriptSearchContext()
    @Entry var transcriptSearchEntryIndex = 0
}
