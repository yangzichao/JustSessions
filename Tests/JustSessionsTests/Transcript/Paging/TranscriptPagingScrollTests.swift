import AppKit
import Testing
@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TranscriptPagingScrollTests {
    @Test func restoringNearTheBottomLoadsTheNextPageWithoutAnotherScroll() async throws {
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
        let scrollView = try await fixture.show(files.conversation, transcript: try #require(model.transcript), paging: model)
        try await expectEventually(timeout: .seconds(5)) { model.pages.last!.records.upperBound > lastBoundary }
        try await fixture.settleLayout()
        #expect(fixture.visiblePosition(in: scrollView) == anchor)
    }

    @Test func aTallViewportLoadsLaterMessagesBeforeItsFirstVisibleRowReachesTheLastFive() async throws {
        let files = try TranscriptPagingFixture()
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture(height: 1_200)
        defer { fixture.close() }
        let model = TranscriptPagingModel()
        model.refresh(files.conversation, position: nil)
        try await expectEventually { !model.isLoading }
        model.first()
        try await expectEventually { !model.isLoading }
        let lastBoundary = try #require(model.pages.last?.records.upperBound)
        fixture.positionStore.record(model.restorationPosition, for: files.conversation.id)
        let scrollView = try await fixture.show(files.conversation, transcript: try #require(model.transcript), paging: model)
        try await fixture.scroll(scrollView, to: scrollView.contentView.documentRect.maxY - scrollView.contentView.bounds.height - 100)
        try await expectEventually(timeout: .seconds(5)) { model.pages.last!.records.upperBound > lastBoundary }
        #expect(model.pages.count <= TranscriptPagingModel.maximumPageCount)
    }

    @Test func appendingToTheFileKeepsTheReaderInsideTheSameHistoricalMessage() async throws {
        let files = try TranscriptPagingFixture(count: 500, lineCount: 18)
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let model = TranscriptPagingModel()
        let anchor = TranscriptReadingPosition.entry(index: TranscriptPageIdentity.entryID(record: 200, part: 0), offset: 123)
        model.refresh(files.conversation, position: anchor)
        try await expectEventually { !model.isLoading }
        fixture.positionStore.record(anchor, for: files.conversation.id)
        let scrollView = try await fixture.show(files.conversation, transcript: try #require(model.transcript), paging: model)
        #expect(fixture.visiblePosition(in: scrollView) == anchor)
        try TranscriptPagingFixture.data(count: 520, lineCount: 18).write(to: files.file)
        model.refresh(files.conversation, position: fixture.positionStore.position(for: files.conversation.id))
        try await expectEventually { !model.isLoading }
        try await fixture.settleLayout()
        #expect(fixture.visiblePosition(in: scrollView) == anchor)
        #expect(model.pages.last?.totalRecordCount == 520)
    }

    @Test func prependingHistoryPreservesTheOffsetInsideTheVisibleMessage() async throws {
        let files = try TranscriptPagingFixture(count: 500, lineCount: 18)
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let model = TranscriptPagingModel()
        let anchor = TranscriptReadingPosition.entry(index: TranscriptPageIdentity.entryID(record: 430, part: 0), offset: 73)
        model.refresh(files.conversation, position: nil)
        try await expectEventually { !model.isLoading }
        fixture.positionStore.record(anchor, for: files.conversation.id)
        let scrollView = try await fixture.show(files.conversation, transcript: try #require(model.transcript), paging: model)
        #expect(fixture.visiblePosition(in: scrollView) == anchor)
        model.earlier(preserving: anchor)
        try await expectEventually { !model.isLoading }
        try await fixture.settleLayout()
        #expect(fixture.visiblePosition(in: scrollView) == anchor)
        #expect(fixture.positionStore.position(for: files.conversation.id) == anchor)
    }

    @Test func scrollingNearTheTopLoadsEarlierMessagesAutomatically() async throws {
        let files = try TranscriptPagingFixture(count: 500, lineCount: 12)
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let model = TranscriptPagingModel()
        model.refresh(files.conversation, position: nil)
        try await expectEventually { !model.isLoading }
        let firstBoundary = try #require(model.pages.first?.records.lowerBound)
        let scrollView = try await fixture.show(files.conversation, transcript: try #require(model.transcript), paging: model)
        try await fixture.scroll(scrollView, to: 80)
        try await expectEventually(timeout: .seconds(5)) { model.pages.first!.records.lowerBound < firstBoundary }
        try await fixture.settleLayout()
        #expect(model.pages.count <= 3)
        guard case .entry(let identifier, _) = fixture.visiblePosition(in: scrollView) else {
            Issue.record("Loading older content must keep an entry anchor")
            return
        }
        #expect(TranscriptPageIdentity.record(for: identifier) >= firstBoundary)
    }
}
