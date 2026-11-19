import AppKit
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TranscriptSeekTargetTests {
    private func id(_ record: Int) -> Int { TranscriptPageIdentity.entryID(record: record, part: 0) }

    private func unhostedController() -> TranscriptScrollPositionController {
        TranscriptScrollPositionController(
            conversationID: "conversation", positionStore: TranscriptReadingPositionStore(),
            initialPosition: .bottom)
    }

    private var messages: [TranscriptEntry.Content] {
        (0..<60).map { index in
            .assistantMessage(
                (0..<(12 + index % 5)).map { "Message \(index), line \($0): keep this reading position." }.joined(separator: "\n"))
        }
    }

    private func showAfterSeekingToRecord20(in fixture: TranscriptScrollViewFixture) async throws
        -> (NSScrollView, TranscriptScrollPositionController)
    {
        let scrollView = try await fixture.show(
            TranscriptScrollViewFixture.conversation("seek"),
            transcript: TranscriptScrollViewFixture.pagedTranscript(messages))
        let controller = try #require(fixture.positionController)
        controller.seek(toEntryAt: id(20))
        try await fixture.waitUntil {
            guard !controller.isRestoring, let frame = controller.entryFrameInClipView(at: id(20)) else { return false }
            return abs(frame.minY - TranscriptScrollPositionController.readableBounds(of: scrollView.contentView).minY - 6) < 1
        }
        return (scrollView, controller)
    }

    @Test func aWheelScrollForgetsTheSeekTarget() {
        let controller = unhostedController()
        controller.setSeekTarget(5)
        #expect(controller.seekTarget == 5)

        controller.handOverToScrolling()

        #expect(controller.seekTarget == nil)
    }

    @Test func stoppingForgetsTheSeekTarget() {
        let controller = unhostedController()
        controller.setSeekTarget(5)

        controller.stop()

        #expect(controller.seekTarget == nil)
    }

    @Test func aSeekTargetScrolledOutOfViewIsForgotten() async throws {
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let (scrollView, controller) = try await showAfterSeekingToRecord20(in: fixture)
        #expect(controller.seekTarget == id(20))

        scrollView.contentView.scroll(to: NSPoint(x: 0, y: scrollView.contentView.documentRect.maxY - scrollView.contentView.bounds.height))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        try await fixture.settleLayout()

        #expect(controller.seekTarget == nil)
    }

    @Test func aSeekTargetScrolledOutOfViewStaysForgottenWhenItComesBack() async throws {
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let (scrollView, controller) = try await showAfterSeekingToRecord20(in: fixture)
        let clipView = scrollView.contentView
        let jumpedTo = clipView.bounds.origin

        clipView.scroll(to: NSPoint(x: 0, y: clipView.documentRect.maxY - clipView.bounds.height))
        scrollView.reflectScrolledClipView(clipView)
        try await fixture.settleLayout()
        clipView.scroll(to: jumpedTo)
        scrollView.reflectScrolledClipView(clipView)
        try await fixture.settleLayout()

        #expect(controller.entryFrameInClipView(at: id(20)).map { $0.intersects(clipView.bounds) } == true)
        #expect(controller.seekTarget == nil)
    }

    @Test func aSeekTargetNotLaidOutHoldsAfterTheRestoration() async throws {
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let (_, controller) = try await showAfterSeekingToRecord20(in: fixture)
        let missing = id(45) + 1

        controller.setSeekTarget(missing)
        try await fixture.settleLayout()

        #expect(!controller.isRestoring)
        #expect(controller.entryFrameInClipView(at: missing) == nil)
        #expect(controller.seekTarget == missing)
    }

    @Test func visibleEntryIDsLeaveOutARowWithLessThanTheMinimumOnScreen() async throws {
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let (_, controller) = try await showAfterSeekingToRecord20(in: fixture)

        #expect(controller.visibleEntryIDs(minimumVisibleHeight: 0).first == id(19))
        #expect(controller.visibleEntryIDs(minimumVisibleHeight: MessageBookmarkNavigation.minimumVisibleHeight).first == id(20))
    }
}
