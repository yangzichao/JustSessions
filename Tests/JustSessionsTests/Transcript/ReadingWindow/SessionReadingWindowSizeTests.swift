import AppKit
import Testing

@testable import JustSessions

@MainActor
struct SessionReadingWindowSizeTests {
    /// A 14-inch MacBook Pro at its default resolution, menu bar and Dock taken off the visible area.
    @Test func onALaptopItIsAThousandPointsWideAndNearlyAsTallAsTheScreen() {
        let visible = CGRect(x: 0, y: 70, width: 1512, height: 846)

        let frame = SessionReadingWindowController.initialFrame(in: visible)

        #expect(frame.size == CGSize(width: 1000, height: 806))
        #expect(frame.origin == CGPoint(x: 256, y: 90))
    }

    @Test func onALargeDisplayItKeepsItsWidthAndTakesTheHeight() {
        let visible = CGRect(x: 1512, y: -400, width: 2560, height: 1385)

        let frame = SessionReadingWindowController.initialFrame(in: visible)

        #expect(frame.size == CGSize(width: 1000, height: 1345))
        #expect(visible.contains(frame))
        #expect(abs(frame.midX - visible.midX) <= 0.5)
    }

    @Test func onASmallScreenItFitsInsideAndNeverGoesBelowTheMinimum() {
        let small = SessionReadingWindowController.initialFrame(in: CGRect(x: 0, y: 0, width: 900, height: 600))
        let tiny = SessionReadingWindowController.initialFrame(in: CGRect(x: 0, y: 0, width: 300, height: 300))

        #expect(small.size == CGSize(width: 860, height: 560))
        #expect(tiny.size == SessionReadingWindowController.minimumSize)
    }

    @Test func theLastWindowsSizeComesBackWithinTheScreen() {
        let laptop = CGRect(x: 0, y: 70, width: 1512, height: 846)

        let saved = SessionReadingWindowController.initialFrame(in: laptop, savedSize: CGSize(width: 1200, height: 700))
        let tooLarge = SessionReadingWindowController.initialFrame(in: laptop, savedSize: CGSize(width: 2400, height: 1300))

        #expect(saved.size == CGSize(width: 1200, height: 700))
        #expect(abs(saved.midY - laptop.midY) <= 0.5)
        #expect(tooLarge.size == CGSize(width: 1472, height: 806))
    }

    @Test func aReadingWindowLeavesItsSizeForTheNextOneAndAFullScreenOneDoesNot() throws {
        let settings = try IsolatedUserDefaults()
        let store = ConversationStore(adapters: [], startsBackgroundPolling: false)
        let conversation = TranscriptScrollViewFixture.conversation("reading-window-size")
        let first = SessionReadingWindowController(
            conversation: conversation, store: store, initialPosition: nil,
            userDefaults: settings.userDefaults
        ) {}
        first.readingWindow.setFrame(NSRect(x: 100, y: 100, width: 1111, height: 666), display: false)

        first.windowWillClose(Notification(name: NSWindow.willCloseNotification))

        #expect(SessionReadingWindowController.savedSize(in: settings.userDefaults) == CGSize(width: 1111, height: 666))
        let second = SessionReadingWindowController(
            conversation: conversation, store: store, initialPosition: nil,
            userDefaults: settings.userDefaults
        ) {}
        #expect(
            second.readingWindow.frame.size == CGSize(width: 1111, height: 666)
                || NSScreen.main.map { $0.visibleFrame.width < 1151 || $0.visibleFrame.height < 706 } == true)
        settings.userDefaults.set("{10, 10}", forKey: SessionReadingWindowController.savedSizeKey)
        #expect(SessionReadingWindowController.savedSize(in: settings.userDefaults) == nil)
        first.close()
        second.close()
    }
}
