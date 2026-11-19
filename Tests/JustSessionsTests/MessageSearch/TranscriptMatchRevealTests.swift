import AppKit
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TranscriptMatchRevealTests {
    private func shownEntry(in fixture: TranscriptScrollViewFixture) -> Int? {
        fixture.readerScrollView.flatMap { fixture.visiblePosition(in: $0)?.entryIndex }
    }

    private func waitForTheMatch(_ entryID: Int, query: String, in fixture: TranscriptScrollViewFixture) async throws {
        try await fixture.waitUntil { fixture.readerScrollView != nil && fixture.textFieldValues.contains(query) }
        try await fixture.waitUntil { shownEntry(in: fixture) == entryID && fixture.textFieldValues.contains(query) }
    }

    @Test func theReaderOpensAtTheMatchWithFindShowingTheSearchedText() async throws {
        let files = try TranscriptPagingFixture(count: 500)
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let entryID = TranscriptPageIdentity.entryID(record: 300, part: 0)

        fixture.showReader(
            files.conversation,
            matchReveal: TranscriptMatchReveal(
                conversationID: files.conversation.id, entryID: entryID, query: "Message 300,"
            ))

        try await waitForTheMatch(entryID, query: "Message 300,", in: fixture)
        #expect(shownEntry(in: fixture) == entryID)
        #expect(fixture.textFieldValues.contains("Message 300,"))
    }

    @Test func aRevealWithNoQueryOpensAtTheMessageWithoutFind() async throws {
        let files = try TranscriptPagingFixture(count: 500)
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let entryID = TranscriptPageIdentity.entryID(record: 300, part: 0)
        func showsAtTop() -> Bool {
            guard let scrollView = fixture.readerScrollView, let controller = fixture.positionController, !controller.isRestoring,
                let frame = controller.entryFrameInClipView(at: entryID)
            else { return false }
            return abs(frame.minY - TranscriptScrollPositionController.readableBounds(of: scrollView.contentView).minY - 6) < 1
        }

        fixture.showReader(
            files.conversation,
            matchReveal: TranscriptMatchReveal(
                conversationID: files.conversation.id, entryID: entryID, query: ""
            ))

        try await fixture.waitUntil { showsAtTop() }
        #expect(showsAtTop())
        #expect(fixture.textFieldValues.isEmpty)
    }

    @Test func anOpenReaderMovesToAnotherMatchOfTheSameSession() async throws {
        let files = try TranscriptPagingFixture(count: 500)
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let conversation = files.conversation
        fixture.showReader(conversation)
        try await fixture.waitUntil { fixture.readerScrollView.flatMap(fixture.visiblePosition(in:)) == .bottom }
        let entryID = TranscriptPageIdentity.entryID(record: 120, part: 0)

        fixture.showReader(
            conversation,
            matchReveal: TranscriptMatchReveal(
                conversationID: conversation.id, entryID: entryID, query: "Message 120,"
            ))

        try await waitForTheMatch(entryID, query: "Message 120,", in: fixture)
        #expect(shownEntry(in: fixture) == entryID)
        #expect(fixture.textFieldValues.contains("Message 120,"))
    }

    @Test func aSessionUpdatedWhileItsMatchLoadsStillOpensAtTheMatch() async throws {
        let files = try TranscriptPagingFixture(count: 500)
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        func conversation(updatedAt seconds: TimeInterval) -> Conversation {
            .fixture(provider: .codex, sessionID: files.sessionID, updatedAt: Date(timeIntervalSince1970: seconds), sourceFile: files.file)
        }
        fixture.showReader(conversation(updatedAt: 1))
        try await fixture.waitUntil { fixture.readerScrollView.flatMap(fixture.visiblePosition(in:)) == .bottom }
        let entryID = TranscriptPageIdentity.entryID(record: 120, part: 0)
        let reveal = TranscriptMatchReveal(conversationID: conversation(updatedAt: 1).id, entryID: entryID, query: "Message 120,")

        fixture.showReader(conversation(updatedAt: 1), matchReveal: reveal)
        fixture.hostingView.layoutSubtreeIfNeeded()
        fixture.positionStore.record(.bottom, for: reveal.conversationID)
        fixture.showReader(conversation(updatedAt: 2), matchReveal: reveal)

        try await waitForTheMatch(entryID, query: "Message 120,", in: fixture)
        #expect(shownEntry(in: fixture) == entryID)
        #expect(fixture.textFieldValues.contains("Message 120,"))
    }
}
