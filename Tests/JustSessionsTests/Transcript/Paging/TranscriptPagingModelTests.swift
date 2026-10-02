import Testing
@testable import JustSessions

@MainActor
struct TranscriptPagingModelTests {
    @Test func evictsDistantPagesAndCanReadThemAgain() async throws {
        let fixture = try TranscriptPagingFixture(count: 600)
        defer { fixture.remove() }
        let model = TranscriptPagingModel()
        model.refresh(fixture.conversation, position: nil)
        try await expectEventually { !model.isLoading }
        let latestID = try #require(model.transcript?.entries.last?.id)
        while model.hasEarlier {
            let anchor = try #require(model.transcript?.entries.first?.id)
            model.earlier(preserving: .entry(index: anchor, offset: 47))
            try await expectEventually { !model.isLoading }
            #expect(model.pages.count <= 3)
            #expect(model.transcript!.entries.count <= 240)
            #expect(model.restorationPosition == .entry(index: anchor, offset: 47))
        }
        #expect(model.transcript?.entries.last?.id != latestID)
        #expect(model.hasLater)
        while model.hasLater {
            let anchor = try #require(model.transcript?.entries.last?.id)
            model.later(preserving: .entry(index: anchor, offset: 20))
            try await expectEventually { !model.isLoading }
            #expect(model.pages.count <= 3)
            #expect(model.restorationPosition == .entry(index: anchor, offset: 20))
        }
        #expect(model.transcript?.entries.last?.id == latestID)
    }

    @Test func firstLatestAndRefreshingKeepTheRequestedPosition() async throws {
        let fixture = try TranscriptPagingFixture(count: 500)
        defer { fixture.remove() }
        let model = TranscriptPagingModel()
        model.refresh(fixture.conversation, position: .entry(index: TranscriptPageIdentity.entryID(record: 175, part: 0), offset: 91))
        try await expectEventually { !model.isLoading }
        #expect(model.restorationPosition == .entry(index: TranscriptPageIdentity.entryID(record: 175, part: 0), offset: 91))
        model.first()
        try await expectEventually { !model.isLoading }
        #expect(!model.hasEarlier)
        #expect(model.hasLater)
        #expect(model.restorationPosition == .entry(index: 0, offset: -6))
        model.latest()
        try await expectEventually { !model.isLoading }
        #expect(!model.hasLater)
        #expect(model.restorationPosition == .bottom)
        #expect(model.pages.count == 1)
    }

    @Test func searchUsesStableIDsForTheLoadedWindow() async throws {
        let fixture = try TranscriptPagingFixture(count: 500)
        defer { fixture.remove() }
        let page = try await TranscriptPageSource(file: fixture.file, provider: .codex).read(.latest)
        let transcript = TranscriptPageAssembler.transcript(pages: [page])
        let matches = try TranscriptSearchIndex(transcript: transcript).matches(for: "Message 450,")
        #expect(matches.count == 1)
        #expect(matches.first?.entryIndex == TranscriptPageIdentity.entryID(record: 450, part: 0))
        #expect(try TranscriptSearchIndex(transcript: transcript).matches(for: "Message 10,").isEmpty)
    }
}
