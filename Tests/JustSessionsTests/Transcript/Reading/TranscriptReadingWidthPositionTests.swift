import AppKit
import Testing
@testable import JustSessions

@MainActor
struct TranscriptReadingWidthPositionTests {
    @Test func switchingWidthKeepsTheReaderWithinTheSameMessage() async throws {
        let fixture = try TranscriptScrollViewFixture(width: 1600)
        defer { fixture.close() }
        let conversation = TranscriptScrollViewFixture.conversation("width-switch")
        // Every line wraps in the readable column but not across the full width, so each switch resizes every entry.
        let longLine = String(repeating: "A long line that wraps differently at each reading width. ", count: 4)
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
        let readableHeight = try #require(fixture.visibleEntryFrames(in: scrollView).first).height

        try await switchWidth(to: .full, in: fixture)
        #expect(fixture.visiblePosition(in: scrollView) == readingPosition)
        let fullHeight = try #require(fixture.visibleEntryFrames(in: scrollView).first).height
        #expect(fullHeight < readableHeight)

        try await switchWidth(to: .readable, in: fixture)
        #expect(fixture.visiblePosition(in: scrollView) == readingPosition)
    }

    private func switchWidth(to width: TranscriptReadingWidth, in fixture: TranscriptScrollViewFixture) async throws {
        fixture.settings.userDefaults.set(width.rawValue, forKey: TranscriptReadingWidth.userDefaultsKey)
        try await fixture.settleLayout()
    }
}
