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

    private final class InteractiveView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            bounds.contains(point) ? self : nil
        }
    }

    private final class HitTestContainer: NSView {
        override var isFlipped: Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            for subview in subviews.reversed() {
                if let target = subview.hitTest(subview.convert(point, from: self)) { return target }
            }
            return self
        }
    }

    /// A scroll view with one tall entry, 300 points high, starting 1,000 points down.
    @MainActor
    private struct Fixture {
        let controller: TranscriptScrollPositionController
        let clipView: NSClipView
        let window: NSWindow
        let geometryView: TranscriptEntryGeometryView

        init() {
            controller = TranscriptScrollPositionController(
                conversationID: "conversation", positionStore: TranscriptReadingPositionStore(), initialPosition: .bottom
            )
            // These tests exercise pending restoration and explicit handover, not elapsed-time settling.
            controller.settlingDuration = .infinity
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
            scrollView.documentView = FlippedView(frame: NSRect(x: 0, y: 0, width: 400, height: 5_000))
            window = NSWindow(contentRect: scrollView.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = scrollView
            clipView = scrollView.contentView
            geometryView = TranscriptEntryGeometryView(controller: controller)
            geometryView.frame = scrollView.documentView?.bounds ?? .zero
            scrollView.documentView?.addSubview(geometryView)
            controller.updateEntryGeometries([
                TranscriptEntryGeometry(entryIndex: 5, frame: NSRect(x: 0, y: 1_000, width: 400, height: 300))
            ])
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

    @Test func geometryObserverLeavesTheInteractiveHitTargetUnchanged() {
        _ = NSApplication.shared
        let container = HitTestContainer(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        let window = NSWindow(contentRect: container.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = container
        window.orderFrontRegardless()
        defer { window.close() }
        let interactiveView = InteractiveView(frame: NSRect(x: 20, y: 20, width: 120, height: 40))
        container.addSubview(interactiveView)
        let point = NSPoint(x: 80, y: 40)
        let targetBeforeObserver = container.hitTest(point)
        let controller = TranscriptScrollPositionController(
            conversationID: "hit-testing", positionStore: TranscriptReadingPositionStore(), initialPosition: .bottom
        )
        let observer = TranscriptEntryGeometryView(controller: controller)
        observer.frame = container.bounds
        container.addSubview(observer)

        #expect(targetBeforeObserver === interactiveView)
        #expect(container.hitTest(point) === targetBeforeObserver)
    }

    /// A page that loads above the entry moves it down; the restoration applies in the layout pass that moves it, so the
    /// window never draws the content in between.
    @Test func aRestorationAroundAnEntryOnScreenAppliesDuringTheNextLayout() async throws {
        let fixture = Fixture()
        defer { fixture.close() }

        fixture.controller.restore(.entry(index: 5, offset: 100), duringNextLayout: true)
        fixture.controller.updateEntryGeometries([
            TranscriptEntryGeometry(entryIndex: 5, frame: NSRect(x: 0, y: 1_600, width: 400, height: 300))
        ])
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
