import AppKit
import Testing
@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TranscriptPagingTraversalTests {
    @Test func scrollingBothWaysEvictsDistantPagesWithoutMovingTheVisibleMessage() async throws {
        let files = try TranscriptPagingFixture(lineCount: 12)
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let model = TranscriptPagingModel()
        model.refresh(files.conversation, position: nil)
        try await expectEventually { !model.isLoading }
        let scrollView = try await fixture.show(files.conversation, transcript: try #require(model.transcript), paging: model)

        for earlier in [true, true, true, true, true, false, false, false] {
            let revision = model.revision
            let firstBoundary = model.pages.first!.records.lowerBound
            let lastBoundary = model.pages.last!.records.upperBound
            let clipView = scrollView.contentView
            let offset = earlier ? 100 : clipView.documentRect.maxY - clipView.bounds.height - 100
            try await fixture.scroll(scrollView, to: offset)
            try await expectEventually(timeout: .seconds(5)) { model.revision > revision }
            try await fixture.settleLayout()
            #expect(model.pages.count <= TranscriptPagingModel.maximumPageCount)
            #expect(model.transcript!.entries.count <= 240)
            #expect(fixture.visiblePosition(in: scrollView) == model.restorationPosition)
            let visibleRecord = TranscriptPageIdentity.record(for: try #require(model.restorationPosition.entryIndex))
            if earlier {
                #expect((firstBoundary...firstBoundary + 1).contains(visibleRecord))
            } else {
                #expect((lastBoundary - 3..<lastBoundary).contains(visibleRecord))
            }
        }
        #expect(!model.hasLater)
    }

    @Test func failedPrefetchStopsUntilAnExplicitRetry() async throws {
        let files = try TranscriptPagingFixture(lineCount: 12)
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let model = TranscriptPagingModel()
        model.refresh(files.conversation, position: nil)
        try await expectEventually { !model.isLoading }
        let scrollView = try await fixture.show(files.conversation, transcript: try #require(model.transcript), paging: model)
        try FileManager.default.removeItem(at: files.file)
        try await fixture.scroll(scrollView, to: 100)
        try await expectEventually { model.errorMessage != nil && !model.isLoading }
        let revision = model.revision
        try TranscriptPagingFixture.data(count: 500, lineCount: 12).write(to: files.file)
        try await fixture.scroll(scrollView, to: 110)
        #expect(model.revision == revision)
        #expect(model.errorMessage != nil)
        model.earlier(preserving: fixture.positionStore.position(for: files.conversation.id) ?? .bottom)
        try await expectEventually { model.revision > revision }
        #expect(model.errorMessage == nil)
    }
}
