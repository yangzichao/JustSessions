import AppKit
import SwiftUI

/// What every text block in the transcript reads to highlight Find's matches. Equal contexts leave those blocks alone:
/// the transcript sets a new one each time its view updates, as it does while you scroll, and a context that compared
/// unequal each time, as a closure made it, updated and remeasured every entry on every one of those updates.
struct TranscriptSearchContext: Equatable {
    var query = ""
    var selectedMatch: TranscriptSearchMatch?
    var navigationRevision = 0
    /// Scrolls the transcript to a match; it stays the same for as long as the transcript is shown.
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
