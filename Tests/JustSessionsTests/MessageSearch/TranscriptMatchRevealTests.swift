import AppKit
import Testing
@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TranscriptMatchRevealTests {
    private func shownEntry(in fixture: TranscriptScrollViewFixture) -> Int? {
        fixture.readerScrollView.flatMap { fixture.visiblePosition(in: $0)?.entryIndex }
    }

    @Test func theReaderOpensAtTheMatchWithFindShowingTheSearchedText() async throws {
        let files = try TranscriptPagingFixture(count: 500)
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let entryID = TranscriptPageIdentity.entryID(record: 300, part: 0)

        fixture.showReader(files.conversation, matchReveal: TranscriptMatchReveal(
            conversationID: files.conversation.id, entryID: entryID, query: "Message 300,"
        ))

        try await fixture.waitUntil { shownEntry(in: fixture) == entryID && fixture.textFieldValues.contains("Message 300,") }
        #expect(shownEntry(in: fixture) == entryID)
        #expect(fixture.textFieldValues.contains("Message 300,"))
    }

    @Test func anOpenReaderMovesToAnotherMatchOfTheSameSession() async throws {
        let files = try TranscriptPagingFixture(count: 500)
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        fixture.showReader(files.conversation)
        // Opened without a reveal, the reader shows the session's latest messages.
        try await fixture.waitUntil { fixture.readerScrollView.flatMap(fixture.visiblePosition(in:)) == .bottom }
        let entryID = TranscriptPageIdentity.entryID(record: 120, part: 0)

        fixture.showReader(files.conversation, matchReveal: TranscriptMatchReveal(
            conversationID: files.conversation.id, entryID: entryID, query: "Message 120,"
        ))

        try await fixture.waitUntil { shownEntry(in: fixture) == entryID && fixture.textFieldValues.contains("Message 120,") }
        #expect(shownEntry(in: fixture) == entryID)
        #expect(fixture.textFieldValues.contains("Message 120,"))
    }
}
