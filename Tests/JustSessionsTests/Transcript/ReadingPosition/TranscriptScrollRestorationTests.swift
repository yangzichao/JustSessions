import AppKit
import Testing
@testable import JustSessions

/// How a restoration puts the reader back in place: during layout when a page loads around the entry being read, and
/// handing over to scrolling, such as a mouse wheel that posts no live-scroll notification, once it has.
@MainActor
struct TranscriptScrollRestorationTests {
    private final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    /// A scroll view with one tall entry, 300 points high, starting 1,000 points down.
    @MainActor
    private struct Fixture {
        let controller: TranscriptScrollPositionController
        let clipView: NSClipView
        let window: NSWindow
        let marker: TranscriptEntryPositionMarkerView

        init() {
            controller = TranscriptScrollPositionController(
                conversationID: "conversation", positionStore: TranscriptReadingPositionStore(), initialPosition: .bottom
            )
            // A restoration stays pending while a test acts, however busy the machine.
            controller.settlingDuration = 60
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
            scrollView.documentView = FlippedView(frame: NSRect(x: 0, y: 0, width: 400, height: 5_000))
            window = NSWindow(contentRect: scrollView.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = scrollView
            clipView = scrollView.contentView
            marker = TranscriptEntryPositionMarkerView(entryIndex: 5, controller: controller)
            marker.frame = NSRect(x: 0, y: 1_000, width: 400, height: 300)
            scrollView.documentView?.addSubview(marker)
        }

        func scrollAway() {
            clipView.scroll(to: NSPoint(x: 0, y: 2_000))
            (clipView.superview as? NSScrollView)?.reflectScrolledClipView(clipView)
        }

        func close() {
            controller.stop()
            window.close()
        }
    }

    /// A page that loads above the entry moves it down; the restoration applies in the layout pass that moves it, so the
    /// window never draws the content in between.
    @Test func aRestorationAroundAnEntryOnScreenAppliesDuringTheNextLayout() async throws {
        let fixture = Fixture()
        defer { fixture.close() }

        fixture.controller.restore(.entry(index: 5, offset: 100), duringNextLayout: true)
        fixture.marker.frame.origin.y += 600
        fixture.window.contentView?.layoutSubtreeIfNeeded()

        #expect(fixture.clipView.bounds.minY == 1_700)
    }

    @Test func scrollingTakesOverOnceTheRestorationHasPutTheReaderInPlace() async throws {
        let fixture = Fixture()
        defer { fixture.close() }
        fixture.controller.restore(.entry(index: 5, offset: 100))
        try await expectEventually { fixture.clipView.bounds.minY == 1_100 }

        #expect(fixture.controller.isRestoring)
        fixture.controller.handOverToScrolling()
        fixture.scrollAway()
        try await Task.sleep(for: .milliseconds(150))

        #expect(fixture.clipView.bounds.minY == 2_000)
        #expect(!fixture.controller.isRestoring)
    }

    @Test func withoutScrollingInputTheRestorationHoldsItsPlace() async throws {
        let fixture = Fixture()
        defer { fixture.close() }
        fixture.controller.restore(.entry(index: 5, offset: 100))
        try await expectEventually { fixture.clipView.bounds.minY == 1_100 }

        fixture.scrollAway()

        try await expectEventually { fixture.clipView.bounds.minY == 1_100 }
        #expect(fixture.controller.isRestoring)
    }

    @Test func scrollingBeforeTheRestorationAppliesDoesNotCancelIt() async throws {
        let fixture = Fixture()
        defer { fixture.close() }
        fixture.controller.restore(.entry(index: 5, offset: 100))

        fixture.controller.handOverToScrolling()
        try await expectEventually { fixture.clipView.bounds.minY == 1_100 }
    }
}
