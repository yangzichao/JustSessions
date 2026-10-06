import AppKit
import Testing
@testable import JustSessions

@MainActor
struct TranscriptSearchTextViewTests {
    /// AppKit's `init(frame:)` calls `init(frame:textContainer:)` on the subclass; without an override of it, creating
    /// the view that highlights a match stopped the app.
    @Test func setsUpItsTextSystem() {
        let view = TranscriptSearchTextView()
        view.textStorage?.setAttributedString(NSAttributedString(string: "Find me"))

        #expect(view.string == "Find me")
        #expect(!view.isEditable)
        #expect(view.measuredSize(width: 200).height > 0)
    }
}
