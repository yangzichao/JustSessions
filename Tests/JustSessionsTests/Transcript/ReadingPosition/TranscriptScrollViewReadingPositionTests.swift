import AppKit
import Testing
@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TranscriptScrollViewReadingPositionTests {
    @Test func switchingSessionsRestoresTheOffsetWithinTheMessage() async throws {
        let fixture = TranscriptScrollViewFixture()
        defer { fixture.close() }
        let firstConversation = TranscriptScrollViewFixture.conversation("first")
        let secondConversation = TranscriptScrollViewFixture.conversation("second")
        let transcript = TranscriptScrollViewFixture.transcript()
        let firstScrollView = try await fixture.show(firstConversation, transcript: transcript)

        #expect(fixture.positionStore.position(for: firstConversation.id) == .bottom)
        try await fixture.scroll(firstScrollView, to: 8_173)
        try await fixture.scroll(firstScrollView, to: firstScrollView.contentView.bounds.minY + 137)
        let savedPosition = try #require(fixture.positionStore.position(for: firstConversation.id))
        guard case .entry(let savedIndex, let savedOffset) = savedPosition else {
            Issue.record("Scrolling to the middle should record a message and its offset")
            return
        }
        #expect(savedOffset > 0)

        let secondScrollView = try await fixture.show(secondConversation, transcript: transcript)
        #expect(fixture.positionStore.position(for: secondConversation.id) == .bottom)
        try await fixture.scroll(secondScrollView, to: 3_249)
        let secondPosition = fixture.positionStore.position(for: secondConversation.id)
        let restoredScrollView = try await fixture.show(firstConversation, transcript: transcript)

        guard case .entry(let restoredIndex, let restoredOffset) = fixture.positionStore.position(for: firstConversation.id) else {
            Issue.record("Returning to a session should restore its saved reading position")
            return
        }
        #expect(restoredIndex == savedIndex)
        #expect(abs(restoredOffset - savedOffset) < 1)
        #expect(fixture.visiblePosition(in: restoredScrollView) == savedPosition)
        #expect(fixture.positionStore.position(for: secondConversation.id) == secondPosition)
    }

    @Test func appendedMessagesDoNotPullAMidConversationReaderToTheBottom() async throws {
        let fixture = TranscriptScrollViewFixture()
        defer { fixture.close() }
        let conversation = TranscriptScrollViewFixture.conversation("updating")
        let scrollView = try await fixture.show(conversation, transcript: TranscriptScrollViewFixture.transcript())
        try await fixture.scroll(scrollView, to: 7_129)
        try await fixture.scroll(scrollView, to: scrollView.contentView.bounds.minY + 91)
        let savedPosition = fixture.positionStore.position(for: conversation.id)

        let updatedScrollView = try await fixture.show(conversation, transcript: TranscriptScrollViewFixture.transcript(count: 125))

        #expect(fixture.positionStore.position(for: conversation.id) == savedPosition)
        #expect(fixture.visiblePosition(in: updatedScrollView) == savedPosition)
    }

    @Test func returningToTheBottomShowsTheLatestMessages() async throws {
        let fixture = TranscriptScrollViewFixture()
        defer { fixture.close() }
        let conversation = TranscriptScrollViewFixture.conversation("latest")
        _ = try await fixture.show(conversation, transcript: TranscriptScrollViewFixture.transcript())
        _ = try await fixture.show(TranscriptScrollViewFixture.conversation("other"), transcript: TranscriptScrollViewFixture.transcript())
        let restoredScrollView = try await fixture.show(conversation, transcript: TranscriptScrollViewFixture.transcript(count: 125))

        #expect(fixture.positionStore.position(for: conversation.id) == .bottom)
        #expect(abs(restoredScrollView.contentView.documentRect.maxY - restoredScrollView.contentView.bounds.maxY) < 2)
    }

    @Test func returningToTheBeginningPreservesTheTopPadding() async throws {
        let fixture = TranscriptScrollViewFixture()
        defer { fixture.close() }
        let conversation = TranscriptScrollViewFixture.conversation("beginning")
        let transcript = TranscriptScrollViewFixture.transcript()
        let scrollView = try await fixture.show(conversation, transcript: transcript)
        try await fixture.scroll(scrollView, to: 0)
        let savedPosition = fixture.visiblePosition(in: scrollView)
        _ = try await fixture.show(TranscriptScrollViewFixture.conversation("other"), transcript: transcript)

        let restoredScrollView = try await fixture.show(conversation, transcript: transcript)

        #expect(fixture.visiblePosition(in: restoredScrollView) == savedPosition)
        #expect(restoredScrollView.contentView.bounds.minY == 0)
    }

    @Test func omittingEarlierMessagesRestoresTheSameRetainedMessage() async throws {
        let fixture = TranscriptScrollViewFixture()
        defer { fixture.close() }
        let conversation = TranscriptScrollViewFixture.conversation("retained")
        let scrollView = try await fixture.show(conversation, transcript: TranscriptScrollViewFixture.transcript())
        try await fixture.scroll(scrollView, to: 8_173)
        try await fixture.scroll(scrollView, to: scrollView.contentView.bounds.minY + 137)
        let savedPosition = fixture.visiblePosition(in: scrollView)
        _ = try await fixture.show(TranscriptScrollViewFixture.conversation("other"), transcript: TranscriptScrollViewFixture.transcript())

        let restoredScrollView = try await fixture.show(conversation, transcript: TranscriptScrollViewFixture.transcript(count: 115, omittedEntryCount: 10))

        #expect(fixture.visiblePosition(in: restoredScrollView) == savedPosition)
    }
}
