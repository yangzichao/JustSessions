import Foundation
import Testing
@testable import JustSessions

struct TranscriptIncrementalIndexTests {
    @Test func aMiddleRewriteAndAppendCannotReuseTheOldRecordBoundaries() throws {
        let fixture = try TranscriptPagingFixture(count: 100)
        defer { fixture.remove() }
        let original = try Data(contentsOf: fixture.file)
        let before = try TranscriptFileIndex.read(fixture.file)
        let text = String(decoding: original, as: UTF8.self)
            .replacingOccurrences(of: "Message 50,", with: "Message xx50,")
            .replacingOccurrences(of: "Message 51,", with: "Messa 51,")
        let rewritten = Data(text.utf8)
        #expect(rewritten.count == original.count)
        #expect(rewritten.prefix(256) == original.prefix(256))
        #expect(rewritten.suffix(256) == original.suffix(256))
        let handle = try FileHandle(forWritingTo: fixture.file)
        try handle.write(contentsOf: rewritten)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"extra\":true}\n".utf8))
        try handle.close()
        let updated = try TranscriptFileIndex.read(fixture.file, updating: before)
        let fresh = try TranscriptFileIndex.read(fixture.file)
        #expect(updated.fingerprint.identifiesSameFile(as: before.fingerprint))
        #expect(updated.lineStarts == fresh.lineStarts)
        #expect(updated.contentLineage != before.contentLineage)
        let reader = try FileHandle(forReadingFrom: fixture.file)
        defer { try? reader.close() }
        for record in [50, 51] {
            let data = try #require(try updated.readRecord(at: record, from: reader, maximumByteCount: 1 << 20))
            #expect((try JSONSerialization.jsonObject(with: data)) is [String: Any])
        }
    }

    @Test(arguments: ["", "first\n", "first\npartial", "你好\r\n\n"])
    func appendsOnlyNewBytesAndPreservesPartialRecords(initial: String) throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try Data(initial.utf8).write(to: file)
        let original = try TranscriptFileIndex.read(file, chunkSize: 3)
        let unchanged = try TranscriptFileIndex.read(file, updating: original)
        #expect(unchanged.scannedByteCount == 0)
        #expect(unchanged.validatedByteCount == 0)
        let appended = Data(" completed\nsecond\nlast".utf8)
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: appended)
        try handle.close()
        let updated = try TranscriptFileIndex.read(file, chunkSize: 3, updating: unchanged)
        let rebuilt = try TranscriptFileIndex.read(file)
        #expect(updated.lineStarts == rebuilt.lineStarts)
        #expect(updated.scannedByteCount == appended.count)
        #expect(updated.contentLineage == original.contentLineage)
        #expect(updated.validatedByteCount == original.byteCount)
    }

    @Test func linesAppendedDuringTheScanAreIndexedByTheNextRefresh() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try Data(String(repeating: "{\"type\":\"event\"}\n", count: 60_000).utf8).write(to: file)
        let appender = try ContinuousLogAppender(file: file)
        appender.start()
        // Small chunks stretch the scan over many reads, so the appender writes between its first and last.
        let scannedWhileAppending = try TranscriptFileIndex.read(file, chunkSize: 4096)
        appender.stop()
        #expect(appender.appendedLineCount > 1)
        let refreshed = try TranscriptFileIndex.read(file, updating: scannedWhileAppending)
        let rebuilt = try TranscriptFileIndex.read(file)
        #expect(refreshed.lineStarts == rebuilt.lineStarts)
        #expect(refreshed.scannedByteCount < rebuilt.scannedByteCount)
    }

    @Test func replacementSameSizeAndDateDoesNotReuseOldOffsets() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try Data("a\nbc".utf8).write(to: file, options: .atomic)
        let original = try TranscriptFileIndex.read(file)
        let date = try #require(FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date)
        try Data("ab\nc".utf8).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.path)
        let updated = try TranscriptFileIndex.read(file, updating: original)
        #expect(updated.lineStarts == [0, 3])
        #expect(updated.scannedByteCount == 4)
    }

    @Test func growingRewriteAndTruncationRebuildOffsets() throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        try Data("a\nbc".utf8).write(to: fixture.file)
        let original = try TranscriptFileIndex.read(fixture.file)
        try Data("abc\ndefgh\n".utf8).write(to: fixture.file)
        let grown = try TranscriptFileIndex.read(fixture.file, updating: original)
        #expect(grown.lineStarts == [0, 4])
        #expect(grown.scannedByteCount == 10)
        try Data("x".utf8).write(to: fixture.file)
        let truncated = try TranscriptFileIndex.read(fixture.file, updating: grown)
        #expect(truncated.lineStarts == [0])
        #expect(truncated.byteCount == 1)
    }
}
