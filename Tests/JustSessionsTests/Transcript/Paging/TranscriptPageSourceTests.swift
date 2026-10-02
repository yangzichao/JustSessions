import Foundation
import Testing
@testable import JustSessions

struct TranscriptPageSourceTests {
    @Test func pagesCoverEveryMessageExactlyOnceInBothDirections() async throws {
        let fixture = try TranscriptPagingFixture(count: 503)
        defer { fixture.remove() }
        let source = TranscriptPageSource(file: fixture.file, provider: .codex)
        let latest = try await source.read(.latest)
        #expect(latest.entries.count == 80)
        #expect(latest.records == 423..<503)
        #expect(latest.decodedByteCount < 30_000)
        var pages = [latest]
        while pages.first!.hasEarlier { pages.insert(try await source.read(.before(pages.first!.records.lowerBound)), at: 0) }
        let entries = pages.flatMap(\.entries)
        #expect(entries.count == 503)
        #expect(Set(entries.map(\.id)).count == 503)
        #expect(entries.map(\.content) == (try CodexTranscriptReader().read(fixture.file)).entries.map(\.content))

        var forward = [try await source.read(.first)]
        while forward.last!.hasLater { forward.append(try await source.read(.after(forward.last!.records.upperBound))) }
        #expect(forward.flatMap(\.entries).map(\.id) == entries.map(\.id))
        let anchor = entries[237].id
        let restored = try await source.read(.around(anchor))
        #expect(restored.entries.first?.id == anchor)
    }

    @Test func indexHandlesChunkBoundariesBlankLinesUnicodeAndUnterminatedLastLine() throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        let records = ["你好 🐈\r\n", "\n", "second\n", "partial"]
        try Data(records.joined().utf8).write(to: fixture.file)
        let index = try TranscriptFileIndex.read(fixture.file, chunkSize: 3)
        #expect(index.lineStarts.count == records.count)
        let handle = try FileHandle(forReadingFrom: fixture.file)
        defer { try? handle.close() }
        for record in records.indices {
            let data = try #require(try index.readRecord(at: record, from: handle, maximumByteCount: 100))
            #expect(String(decoding: data, as: UTF8.self) == records[record])
        }
        #expect(try index.readRecord(at: 0, from: handle, maximumByteCount: 2) == nil)
    }

    @Test func refreshHandlesCompletedPartialLinesAppendsAndTruncation() async throws {
        let fixture = try TranscriptPagingFixture(count: 12)
        defer { fixture.remove() }
        let complete = TranscriptPagingFixture.data(count: 15)
        try Data(complete.dropLast(10)).write(to: fixture.file)
        let source = TranscriptPageSource(file: fixture.file, provider: .codex)
        let partial = try await source.read(.latest)
        #expect(partial.entries.count == 14)
        try complete.write(to: fixture.file)
        let completed = try await source.read(.latest, refreshIndex: true)
        #expect(completed.entries.count == 15)
        #expect(completed.entries.prefix(14).map(\.id) == partial.entries.map(\.id))
        try TranscriptPagingFixture.data(count: 2).write(to: fixture.file)
        let truncated = try await source.read(.around(completed.entries.last!.id), refreshIndex: true)
        #expect(truncated.entries.count == 1)
        #expect(truncated.entries.first?.id == completed.entries[1].id)
    }

    @Test func skipsOversizedToolOutputsWithoutAllocatingTheirJSON() async throws {
        let fixture = try TranscriptPagingFixture(count: 1)
        defer { fixture.remove() }
        let output = #"{"timestamp":"2026-10-02T12:00:00.000Z","type":"response_item","payload":{"type":"function_call_output","output":""#
            + String(repeating: "x", count: 200_000) + "\"}}\n"
        let handle = try FileHandle(forWritingTo: fixture.file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(output.utf8))
        try handle.close()
        var limits = TranscriptPageLimits()
        limits.maximumRecordByteCount = 1_024
        let page = try await TranscriptPageSource(file: fixture.file, provider: .codex, limits: limits).read(.latest)
        #expect(page.entries.count == 1)
        #expect(page.decodedByteCount < 1_024)
    }

    @Test func cancellationDoesNotReturnAnObsoletePage() async throws {
        let fixture = try TranscriptPagingFixture()
        defer { fixture.remove() }
        let source = TranscriptPageSource(file: fixture.file, provider: .codex)
        let task = Task {
            try Task.checkCancellation()
            return try await source.read(.latest)
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
