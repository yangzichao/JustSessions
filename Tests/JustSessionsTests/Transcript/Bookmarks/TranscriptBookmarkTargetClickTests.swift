import AppKit
import Testing

@testable import JustSessions

/// The mark beside the message ⌘D would bookmark (RDR-48): its slot takes clicks and right-clicks, with a letter or
/// without; the pointer's moves pass through it, so a labelled letter under it still shows its card, and the rest of the
/// gutter lets clicks through. Points are in the marks view's parent's coordinates, as AppKit passes them down the tree.
@MainActor
struct TranscriptBookmarkTargetClickTests {
    private static func marks(letters: [MessageBookmark]) -> (container: NSView, marks: TranscriptBookmarkTargetMarksView) {
        let container = FlippedView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
        let marks = TranscriptBookmarkTargetMarksView()
        marks.frame = NSRect(x: 0, y: 0, width: TranscriptBookmarkTargetMarks.gutterWidth, height: 600)
        container.addSubview(marks)
        marks.style = TranscriptBookmarkTargetMarkView.Style(
            color: .secondaryLabelColor, letters: TranscriptBookmarkLetters(letters), side: 16)
        marks.show(TranscriptBookmarkTarget.Shown(entryID: 4, frame: CGRect(x: 0, y: 100, width: 300, height: 120), topPadding: 12))
        return (container, marks)
    }

    private final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    /// The slot is 16 points square at x 4 (24 - 16 - 4), from the message's first line at y 112.
    @Test func theSlotTakesClicksAndRightClicksButNotThePointersMoves() {
        let (_, marks) = Self.marks(letters: [])
        let slot = NSPoint(x: 12, y: 118)

        let hit = marks.clickTarget(at: slot, for: .leftMouseDown)

        #expect(hit is TranscriptBookmarkTargetMarkView)
        #expect(hit?.isAccessibilityElement() == true)
        #expect(hit?.accessibilityRole() == .button)
        #expect(hit?.accessibilityLabel() == "Add bookmark")
        #expect(marks.clickTarget(at: slot, for: .rightMouseDown) === hit)
        #expect(marks.clickTarget(at: slot, for: .mouseMoved) == nil)
        #expect(marks.clickTarget(at: slot, for: nil) == nil)
        #expect(marks.clickTarget(at: NSPoint(x: 12, y: 160), for: .leftMouseDown) == nil)  // the line down the message
        #expect(marks.clickTarget(at: NSPoint(x: 12, y: 60), for: .leftMouseDown) == nil)
    }

    /// A click there again removes the bookmark; the pointer still reaches the letter for its card.
    @Test func aMessageWithALetterTakesTheClickToRemoveIt() {
        let bookmark = MessageBookmark(letter: "a", entryID: 4, kind: .assistant, snippet: "")
        let (_, marks) = Self.marks(letters: [bookmark])
        let slot = NSPoint(x: 12, y: 118)

        let hit = marks.clickTarget(at: slot, for: .leftMouseUp)

        #expect(hit is TranscriptBookmarkTargetMarkView)
        #expect(hit?.accessibilityLabel() == "Remove bookmark a")
        #expect(hit?.accessibilityCustomActions()?.map(\.name) == ["Edit bookmark a…"])
        #expect(hit?.toolTip == nil)
        #expect(marks.clickTarget(at: slot, for: .mouseMoved) == nil)
    }

    @Test func noTargetTakesNothing() {
        let (_, marks) = Self.marks(letters: [])
        marks.show(nil)

        #expect(marks.clickTarget(at: NSPoint(x: 12, y: 118), for: .leftMouseDown) == nil)
    }
}
