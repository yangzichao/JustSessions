import AppKit
import Testing
@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TranscriptAutomaticPagingTests {
    @Test func scrollingInsideTheSameTallMessageTriggersEarlierLoading() async throws {
        let files = try TranscriptPagingFixture(lineCounts: [420: 120])
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let model = TranscriptPagingModel()
        model.refresh(files.conversation, position: nil)
        try await expectEventually { !model.isLoading }
        let firstBoundary = try #require(model.pages.first?.records.lowerBound)
        let anchor = TranscriptReadingPosition.entry(index: TranscriptPageIdentity.entryID(record: firstBoundary, part: 0), offset: 900)
        fixture.positionStore.record(anchor, for: files.conversation.id)
        let scrollView = try await fixture.show(files.conversation, transcript: try #require(model.transcript), paging: model)
        #expect(fixture.visiblePosition(in: scrollView) == anchor)
        #expect(model.pages.count == 1)
        try await fixture.scroll(scrollView, to: 100)
        try await expectEventually(timeout: .seconds(5)) { model.pages.first!.records.lowerBound < firstBoundary }
        try await fixture.settleLayout()
        #expect(fixture.positionStore.position(for: files.conversation.id)?.entryIndex == anchor.entryIndex)
    }

    @Test func closingFindResumesAutomaticLoadingAtTheCurrentBoundary() async throws {
        let files = try TranscriptPagingFixture(lineCount: 3)
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let model = TranscriptPagingModel()
        model.refresh(files.conversation, position: nil)
        try await expectEventually { !model.isLoading }
        model.first()
        try await expectEventually { !model.isLoading }
        let lastBoundary = try #require(model.pages.last?.records.upperBound)
        let anchor = TranscriptReadingPosition.entry(index: TranscriptPageIdentity.entryID(record: 73, part: 0), offset: 0)
        fixture.positionStore.record(anchor, for: files.conversation.id)
        let searchState = TranscriptSearchState()
        searchState.show()
        let scrollView = try await fixture.show(files.conversation, transcript: try #require(model.transcript), paging: model, searchState: searchState)
        #expect(model.pages.count == 1)
        searchState.close()
        try await expectEventually(timeout: .seconds(5)) { model.pages.last!.records.upperBound > lastBoundary }
        try await fixture.settleLayout()
        #expect(fixture.visiblePosition(in: scrollView) == anchor)
    }

    @Test func anInactiveReaderWaitsUntilItBecomesActiveToPrefetch() async throws {
        let files = try TranscriptPagingFixture(lineCount: 3)
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let model = TranscriptPagingModel()
        model.refresh(files.conversation, position: nil)
        try await expectEventually { !model.isLoading }
        let firstBoundary = try #require(model.pages.first?.records.lowerBound)
        let anchor = TranscriptReadingPosition.entry(index: TranscriptPageIdentity.entryID(record: firstBoundary, part: 0), offset: 0)
        fixture.positionStore.record(anchor, for: files.conversation.id)
        _ = try await fixture.show(files.conversation, transcript: try #require(model.transcript), paging: model, isActive: false)
        #expect(model.pages.count == 1)
        _ = try await fixture.show(files.conversation, transcript: try #require(model.transcript), paging: model)
        try await expectEventually(timeout: .seconds(5)) { model.pages.first!.records.lowerBound < firstBoundary }
    }
}
