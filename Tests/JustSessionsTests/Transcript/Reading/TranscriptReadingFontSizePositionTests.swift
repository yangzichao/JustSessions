import AppKit
import Testing
@testable import JustSessions

@MainActor
struct TranscriptReadingFontSizePositionTests {
    @Test func changingTextSizeKeepsTheReaderWithinTheSameMessage() async throws {
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let conversation = TranscriptScrollViewFixture.conversation("text-size-change")
        let longLine = String(repeating: "A long line that wraps in the readable column. ", count: 4)
        let transcript = TranscriptContent(entries: (0..<60).map { index in
            let lineCount = index == 40 ? 60 : 6
            let text = (0..<lineCount).map { "Message \(index), line \($0): \(longLine)" }.joined(separator: "\n")
            return TranscriptEntry(id: index, content: .assistantMessage(text), timestamp: nil, startsTurn: true)
        }, omittedEntryCount: 0)
        fixture.positionStore.record(.entry(index: 40, offset: 0), for: conversation.id)
        let scrollView = try await fixture.show(conversation, transcript: transcript)
        try await fixture.scroll(scrollView, to: scrollView.contentView.bounds.minY + 300)
        let readingPosition = TranscriptReadingPosition.entry(index: 40, offset: 300)
        #expect(fixture.visiblePosition(in: scrollView) == readingPosition)
        let defaultHeight = try #require(fixture.visibleEntryFrames(in: scrollView).first).height

        // A− comes first: the system font has the same line height at the default 15 points as at 16, so A+ from the
        // default can leave the message's height unchanged, while 14 points is shorter.
        try await fixture.pressButton(labeled: "Smaller reading text")
        #expect(fixture.visiblePosition(in: scrollView) == readingPosition)
        let smallerHeight = try #require(fixture.visibleEntryFrames(in: scrollView).first).height
        #expect(smallerHeight < defaultHeight)

        try await fixture.pressButton(labeled: "Larger reading text")
        #expect(fixture.visiblePosition(in: scrollView) == readingPosition)
        let largerHeight = try #require(fixture.visibleEntryFrames(in: scrollView).first).height
        #expect(largerHeight > smallerHeight)
    }
}
