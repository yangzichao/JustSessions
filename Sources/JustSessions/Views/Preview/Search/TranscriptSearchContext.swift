import AppKit
import SwiftUI

struct TranscriptSearchContext {
    var query = ""
    var selectedMatch: TranscriptSearchMatch?
    var navigationRevision = 0
    var reveal: ((NSTextView, NSRange, Int) -> Bool)?
}

extension EnvironmentValues {
    @Entry var transcriptSearchContext = TranscriptSearchContext()
    @Entry var transcriptSearchEntryIndex = 0
}
