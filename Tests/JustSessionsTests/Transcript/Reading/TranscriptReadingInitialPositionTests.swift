import Testing
@testable import JustSessions

@MainActor
struct TranscriptReadingInitialPositionTests {
    @Test func initiallyPositionsATallMessageBeforeReadingWithinIt() async throws {
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let conversation = TranscriptScrollViewFixture.conversation("initial-tall-reader")
        let longMessage = (0..<100).map { "Line \($0) of a message taller than the window." }.joined(separator: "\n")
        let transcript = TranscriptContent(entries: TranscriptScrollViewFixture.transcript().entries.map { entry in
            guard entry.id == 40 else { return entry }
            return TranscriptEntry(id: entry.id, content: .assistantMessage(longMessage), timestamp: nil, startsTurn: true)
        }, omittedEntryCount: 0)
        fixture.positionStore.record(.entry(index: 40, offset: 0), for: conversation.id)
        let scrollView = try await fixture.show(conversation, transcript: transcript)
        #expect(fixture.visiblePosition(in: scrollView) == .entry(index: 40, offset: 0))
        try await fixture.scroll(scrollView, to: scrollView.contentView.bounds.minY + 743)
        #expect(fixture.visiblePosition(in: scrollView) == .entry(index: 40, offset: 743))
    }

}
